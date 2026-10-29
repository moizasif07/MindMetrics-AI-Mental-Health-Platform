  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:intl/intl.dart';

  class NotificationsScreen extends StatelessWidget {
    const NotificationsScreen({super.key});

    // REAL DATABASE LOGIC: Mark all notifications as read
    Future<void> _markAllAsRead(String uid) async {
      final batch = FirebaseFirestore.instance.batch();
      
      // Fetch all unread notifications for this user
      final unreadDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      
      // Update them all at once
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    }

    @override
    Widget build(BuildContext context) {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        return const Scaffold(body: Center(child: Text('Please log in')));
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Notifications', 
            style: TextStyle(color: Colors.indigo, fontSize: 22, fontWeight: FontWeight.bold)
          ),
          actions: [
            TextButton(
              onPressed: () => _markAllAsRead(currentUser.uid),
              child: const Text('Mark all as read', style: TextStyle(color: Colors.indigo, fontSize: 13)),
            ),
          ],
        ),
        // LIVE DATABASE STREAM
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.indigo));
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error loading notifications.', style: TextStyle(color: Colors.grey)));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    const Text('No new notifications.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            final notifications = snapshot.data!.docs;

            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0F4F8)),
              itemBuilder: (context, index) {
                final data = notifications[index].data() as Map<String, dynamic>;
                
                final String title = data['title'] ?? 'Alert';
                final String body = data['body'] ?? '';
                final bool isRead = data['isRead'] ?? false;
                final String type = data['type'] ?? 'system'; 
                
                // Format the timestamp nicely
                String timeString = "Just now";
                if (data['timestamp'] != null) {
                  DateTime time = (data['timestamp'] as Timestamp).toDate();
                  timeString = DateFormat('MMM d, h:mm a').format(time); 
                }

                // Dynamic Icons based on notification type
                IconData iconData = Icons.notifications;
                Color iconColor = Colors.grey;
                Color bgColor = Colors.grey.shade200;

                if (type == 'reminder') {
                  iconData = Icons.sentiment_satisfied_alt;
                  iconColor = Colors.indigo;
                  bgColor = Colors.indigo.shade50;
                } else if (type == 'message') {
                  iconData = Icons.chat_bubble;
                  iconColor = Colors.green;
                  bgColor = Colors.green.shade50;
                } else if (type == 'exercise') {
                  iconData = Icons.self_improvement;
                  iconColor = Colors.orange;
                  bgColor = Colors.orange.shade50;
                }

                return Container(
                  // Unread notifications get a white background, read ones blend into the grey scaffold
                  color: isRead ? Colors.transparent : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: bgColor,
                          child: Icon(iconData, color: iconColor, size: 24),
                        ),
                        // The red unread dot
                        if (!isRead)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          )
                      ],
                    ),
                    title: Text(
                      title, 
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold, 
                        color: const Color(0xFF2D3748),
                        fontSize: 15,
                      )
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(body, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                        const SizedBox(height: 8),
                        Text(timeString, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }
  }
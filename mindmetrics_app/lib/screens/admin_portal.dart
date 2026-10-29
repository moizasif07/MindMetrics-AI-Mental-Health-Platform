import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPortal extends StatefulWidget {
  const AdminPortal({super.key});

  @override
  State<AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  
  // REAL DATABASE LOGIC: Function to securely update a user's role
  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role securely updated to $newRole'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role. Check permissions.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey.shade900,
        title: const Text('MindMetrics Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Quick logout for testing convenience
              Navigator.of(context).pop(); 
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 5),
            const Text('Live database feed of all registered accounts. Adjust roles below.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // Live Firestore StreamBuilder
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: StreamBuilder<QuerySnapshot>(
                  // Querying the users collection and sorting by newest first
                  stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    
                    // 1. Loading State
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.blueGrey));
                    }

                    // 2. Error or Empty State
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No users found in database.', style: TextStyle(color: Colors.grey)));
                    }

                    final users = snapshot.data!.docs;

                    // 3. Success State: Build the list
                    return ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final userDoc = users[index];
                        final data = userDoc.data() as Map<String, dynamic>;
                        
                        final email = data['email'] ?? 'Unknown Email';
                        final currentRole = data['role'] ?? 'patient';
                        final userId = userDoc.id;

                        // Color coordinate avatars based on role
                        Color avatarColor = Colors.blueGrey;
                        IconData roleIcon = Icons.person;
                        if (currentRole == 'admin') {
                          avatarColor = Colors.red;
                          roleIcon = Icons.security;
                        } else if (currentRole == 'therapist') {
                          avatarColor = Colors.teal;
                          roleIcon = Icons.medical_services;
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: avatarColor.withOpacity(0.1),
                            child: Icon(roleIcon, color: avatarColor, size: 20),
                          ),
                          title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('ID: ${userId.substring(0, 8)}...', style: const TextStyle(fontSize: 12)),
                          
                          // The Interactive Dropdown to change roles!
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButton<String>(
                              value: currentRole,
                              underline: const SizedBox(), // Hide the default ugly line
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.blueGrey),
                              style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'patient', child: Text('Patient')),
                                DropdownMenuItem(value: 'therapist', child: Text('Therapist')),
                                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                              ],
                              onChanged: (newRole) {
                                if (newRole != null && newRole != currentRole) {
                                  _updateUserRole(userId, newRole);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
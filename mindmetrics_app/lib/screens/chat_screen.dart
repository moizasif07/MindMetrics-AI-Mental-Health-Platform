import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 

class ChatScreen extends StatefulWidget {
  final String? receiverEmail; // Passed by Therapist. Patient leaves this null.
  
  const ChatScreen({super.key, this.receiverEmail});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  String _chatTitle = "Connecting...";
  String? _activeChatRoomId;
  String? _targetEmail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChatRouting();
  }

  // Unified Unique shared room ID generator
  String _getChatRoomId(String a, String b) {
    List<String> users = [a.toLowerCase(), b.toLowerCase()];
    users.sort(); // Sorts alphabetically so both users generate the exact same string
    return users.join("_");
  }

  Future<void> _initializeChatRouting() async {
    if (currentUser == null || currentUser!.email == null) return;

    if (widget.receiverEmail != null) {
      // SCENARIO A: Therapist opened this screen looking at a patient
      setState(() {
        _chatTitle = widget.receiverEmail!;
        _targetEmail = widget.receiverEmail!;
        _activeChatRoomId = _getChatRoomId(currentUser!.email!, _targetEmail!);
        _isLoading = false;
      });
    } else {
      // SCENARIO B: Patient opened this screen. Fetch their assigned therapist's email.
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data()!.containsKey('assigned_therapist_email')) {
        final tEmail = doc.data()!['assigned_therapist_email'];
        final tName = doc.data()!['assigned_therapist_name'] ?? 'Therapist';
        
        setState(() {
          _chatTitle = tName;
          _targetEmail = tEmail;
          _activeChatRoomId = _getChatRoomId(currentUser!.email!, _targetEmail!);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUser == null || _activeChatRoomId == null) return;

    String text = _messageController.text.trim();
    _messageController.clear();

    // BOTH users now write to the exact same shared room
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_activeChatRoomId)
        .collection('messages')
        .add({
      'sender': currentUser!.email,
      'receiver': _targetEmail,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.indigo)));
    }

    if (_activeChatRoomId == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.indigo)),
        body: const Center(child: Text("Chat routing error. Please try connecting again.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.indigo),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                _chatTitle.isNotEmpty ? _chatTitle[0].toUpperCase() : '?',
                style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chatTitle, 
                    style: const TextStyle(color: Color(0xFF2D3748), fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text('Secure Clinical Connection', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // BOTH users now read from the exact same shared room
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_activeChatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.indigo));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Your secure session is open. Send a message.', style: TextStyle(color: Colors.grey)),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    
                    final String text = data['text'] ?? '';
                    final bool isMe = data['sender'] == currentUser?.email;
                    
                    String timeString = "Just now";
                    if (data['timestamp'] != null) {
                      DateTime time = (data['timestamp'] as Timestamp).toDate();
                      timeString = DateFormat('h:mm a').format(time); 
                    }

                    return _buildMessageBubble(text, timeString, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, String time, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(fontSize: 15, height: 1.4, color: isMe ? Colors.white : const Color(0xFF2D3748)),
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: TextStyle(fontSize: 11, color: isMe ? Colors.indigo.shade200 : Colors.grey.shade500),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            )
          ],
        ),
      ),
    );
  }
}
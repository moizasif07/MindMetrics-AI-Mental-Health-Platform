import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class PatientInbox extends StatelessWidget {
  const PatientInbox({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Messages', style: TextStyle(color: Colors.indigo, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('Your Care Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
          ),
          Expanded(
            // Stream ONLY the current patient's document to find their dynamically assigned therapist
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.indigo));
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Error loading profile.'));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final therapistName = userData?['assigned_therapist_name'];
                final therapistEmail = userData?['assigned_therapist_email'];

                // If the Load Balancer hasn't assigned anyone yet:
                if (therapistName == null || therapistEmail == null || therapistEmail.toString().isEmpty) {
                  return const Center(
                    child: Text(
                      'No therapist assigned yet.\nKeep logging your daily check-ins for AI triage!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 16),
                    ),
                  );
                }

                // If they HAVE been assigned a therapist, display their specific doctor:
                return ListView(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      tileColor: Colors.white,
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        child: Icon(Icons.health_and_safety, color: Colors.teal.shade400),
                      ),
                      title: Text(therapistName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                      subtitle: const Text('Clinical Therapist • Secure Connection', style: TextStyle(color: Colors.green, fontSize: 12)),
                      trailing: const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
                      onTap: () {
                        // THE FIX: Launch ChatScreen WITHOUT arguments so it opens in "Patient Mode"
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatScreen()),
                        );
                      },
                    )
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
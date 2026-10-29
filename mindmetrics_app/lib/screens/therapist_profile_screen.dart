import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TherapistProfileScreen extends StatefulWidget {
  const TherapistProfileScreen({super.key});

  @override
  State<TherapistProfileScreen> createState() => _TherapistProfileScreenState();
}

class _TherapistProfileScreenState extends State<TherapistProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- UPDATE NAME IN FIRESTORE ---
  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'name': _nameController.text.trim()});
          
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile name updated successfully!'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating name: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- SEND PASSWORD RESET EMAIL ---
  Future<void> _sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No email address found.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email!'), 
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error sending password reset email.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // --- NAME EDIT DIALOG ---
  void _showNameDialog(String currentName) {
    _nameController.text = currentName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile Name'),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: _updateName,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.indigo),
        title: const Text(
          'Provider Settings',
          style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.bold),
        ),
      ),
      // REAL-TIME FIRESTORE CONNECTION
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Error loading profile data.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String currentName = userData['name'] ?? 'Provider';
          final String currentEmail = userData['email'] ?? currentUser?.email ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.indigo.shade50,
                        child: const Icon(Icons.medical_services, size: 50, color: Colors.indigo),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        currentName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentEmail,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                const Text(
                  'Account Security',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                ),
                const SizedBox(height: 15),

                // Settings Cards
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.person_outline, color: Colors.indigo),
                        ),
                        title: const Text('Edit Profile Name', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _showNameDialog(currentName),
                      ),
                      const Divider(height: 1, indent: 60),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.lock_outline, color: Colors.teal),
                        ),
                        title: const Text('Send Password Reset Link', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () {
                          // Show a quick confirmation dialog before sending the email
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Reset Password?'),
                              content: Text('We will send a password reset link to $currentEmail.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context), 
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey))
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _sendPasswordResetEmail(currentEmail);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                  child: const Text('Send Link'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
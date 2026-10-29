import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'chat_screen.dart'; 

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final TextEditingController _notesController = TextEditingController();
  
  // Interactive Mood State
  String _selectedMood = 'Neutral'; 
  bool _isLoading = false;

  // Visual Mood Options
  final List<Map<String, String>> _moods = [
    {'label': 'Awful', 'emoji': '😫'},
    {'label': 'Bad', 'emoji': '🙁'},
    {'label': 'Neutral', 'emoji': '😐'},
    {'label': 'Good', 'emoji': '🙂'},
    {'label': 'Great', 'emoji': '😄'},
  ];

void _submitData() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a few words first.'), backgroundColor: Colors.indigo)
      );
      return;
    }

    FocusScope.of(context).unfocus(); 
    setState(() => _isLoading = true);

    final journalText = _notesController.text;
    
    // 1. Grab the current user's unique ID
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous_user';

    // 2. Pass the userId to your API
    final result = await ApiService.analyzeMood(
      userId, // <--- NEW: Send the UID to the backend
      _selectedMood,
      journalText, 
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result != null && result['status'] == 'success') {
        _notesController.clear(); 
        _showResultPopup(result['ai_analysis']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result?['message']}'), backgroundColor: Colors.red)
        );
      }
    }
  }
  void _showResultPopup(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces user to click the close button
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(20),
          child: _buildResultCard(data, dialogContext),
        );
      },
    );
  }

Future<void> _connectToTherapist(BuildContext dialogContext) async {
    // 1. Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final firestore = FirebaseFirestore.instance;

        // --- EXISTING THERAPIST CHECK ---
        final userDoc = await firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        
        // If they already have an assigned therapist, skip the load balancer
        if (userData != null && 
            userData.containsKey('assigned_therapist_id') && 
            userData['assigned_therapist_id'] != null &&
            userData['assigned_therapist_id'].toString().isNotEmpty) {
          
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Close spinner
            Navigator.of(context, rootNavigator: true).pop(); // Close AI popup
            
            // Route directly to their existing chat session
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          }
          return; // Stop the function here so the load balancer doesn't run!
        }

        // 2. RUN LOAD BALANCER: Only happens if this is their first time
        final availableTherapistsQuery = await firestore
            .collection('users')
            .where('role', isEqualTo: 'therapist') // Match your exact database spelling
            .get();

        if (availableTherapistsQuery.docs.isNotEmpty) {
          // Convert to list and sort manually in Dart
          var therapistsList = availableTherapistsQuery.docs.toList();
          
          therapistsList.sort((a, b) {
            int countA = (a.data()['patient_count'] ?? 0) as int;
            int countB = (b.data()['patient_count'] ?? 0) as int;
            return countA.compareTo(countB);
          });

          // Pick the one with the lowest count
          final selectedTherapist = therapistsList.first;
          final therapistId = selectedTherapist.id;
          
          final therapistName = selectedTherapist.data()['name'] ?? 
                                selectedTherapist.data()['email'] ?? 
                                'Clinical Therapist';
                                
          // --- THE CRITICAL FIX FOR CHAT SYNCING ---
          final therapistEmail = selectedTherapist.data()['email'] ?? ''; 

         // 3. Assign therapist to the user's document
          await firestore.collection('users').doc(user.uid).set({
            'therapist_unlocked': true,
            'assigned_therapist_id': therapistId,
            'assigned_therapist_name': therapistName,
            'assigned_therapist_email': therapistEmail, 
          }, SetOptions(merge: true));

          // 4. Increment the chosen therapist's workload count
          await firestore.collection('users').doc(therapistId).update({
            'patient_count': FieldValue.increment(1),
          });
          // This tells FastAPI to officially link them in your SQLite database
          await ApiService.assignPatient(therapistId, user.uid);

          // 5. Navigate cleanly
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Close spinner
            Navigator.of(context, rootNavigator: true).pop(); // Close AI popup
            
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Close spinner
            Navigator.of(context, rootNavigator: true).pop(); // Close AI popup

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No therapists are currently available.'), 
                backgroundColor: Colors.orange
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close spinner
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Routing Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Soft, therapeutic off-white
      appBar: AppBar(
        title: const Text('Daily Check-In', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. The Interactive Mood Selector
            const Text(
              'How are you feeling today?', 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2D3748)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood['label'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = mood['label']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.indigo.withOpacity(0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.indigo : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                      ] : [],
                    ),
                    child: Column(
                      children: [
                        Text(mood['emoji']!, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 8),
                        Text(
                          mood['label']!, 
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.indigo : Colors.grey.shade600
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // 2. The Journal Area
            const Text(
              'Journal your thoughts', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ]
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'What is on your mind? (Your AI will analyze this...)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 3. The Submit Button
            SizedBox(
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 5,
                  shadowColor: Colors.indigo.withOpacity(0.5),
                ),
                onPressed: _isLoading ? null : _submitData,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Get AI Insights', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The Beautiful AI Response Card (Now structured for a Dialog)
  Widget _buildResultCard(Map<String, dynamic> data, BuildContext dialogContext) {
    int score = data['wellness_score'] ?? 0;
    Color scoreColor = score < 50 ? Colors.orange.shade600 : Colors.teal;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: Colors.indigo.shade100),
      ),
      padding: const EdgeInsets.all(25),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures the dialog only takes as much height as needed
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AI Insight', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(dialogContext),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 15),
            
            // Score Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Score: $score/100', 
                style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(height: 1),
            ),
            
            Text(
              data['empathetic_response'] ?? '', 
              style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF2D3748))
            ),
            
            if (data['cbt_exercise'] != null) ...[
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.self_improvement, color: Colors.teal.shade600),
                        const SizedBox(width: 10),
                        Text('Recommended Exercise', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(data['cbt_exercise'], style: const TextStyle(height: 1.5)),
                  ],
                ),
              )
            ],
            
            if (data['professional_referral'] == true) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.shade300)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.health_and_safety, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Clinical Support Recommended', 
                            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your wellness score indicates you might benefit from professional support. Would you like us to securely connect you with an available therapist right now?',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 15),
                    
                    // OPT-IN CONSENT BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Not Right Now', style: TextStyle(color: Colors.orange.shade700)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _connectToTherapist(dialogContext),
                          child: const Text('Connect Me'),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}
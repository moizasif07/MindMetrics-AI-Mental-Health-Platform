import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart'; 
import 'chat_screen.dart';
import 'therapist_profile_screen.dart';
import 'therapist_notes.dart';
import 'login_screen.dart';
import 'patient_report_screen.dart';


class TherapistDashboard extends StatefulWidget {
  const TherapistDashboard({super.key});

  @override
  State<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  late Future<List<Map<String, dynamic>>> _assignedPatientsFuture;

  @override
  void initState() {
    super.initState();
    _loadAssignedPatients();
  }

  // Fetch the secure assignments and AI alerts from your FastAPI backend
  void _loadAssignedPatients() {
    final user = FirebaseAuth.instance.currentUser;
    final therapistId = user?.uid ?? 'unknown_therapist';
    setState(() {
      _assignedPatientsFuture = ApiService.fetchAssignedPatients(therapistId);
    });
  }

  Future<void> _handleRefresh() async {
    _loadAssignedPatients();
    await _assignedPatientsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provider Portal',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              'MindMetrics Clinical',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [

           IconButton(
            icon: const Icon(Icons.person, color: Colors.teal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TherapistProfileScreen()),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout, color: Colors.indigo),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analytics Header
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Active Patients',
                    'Live',
                    Icons.people_outline,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildStatCard(
                    'System Status',
                    'Online',
                    Icons.check_circle_outline,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            const Text(
              'Assigned Patients',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 10),

            // LIVE DATABASE STREAM MERGED WITH FASTAPI AI ALERTS
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _assignedPatientsFuture,
                builder: (context, apiSnapshot) {
                  if (apiSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.indigo),
                    );
                  }

                  // 1. Get the FastAPI data (Alerts & Privacy Status)
                  final apiPatients = apiSnapshot.data ?? [];

                  // Map them by patient_id for fast lookup
                  final apiPatientMap = {
                    for (var p in apiPatients) p['patient_id']: p,
                  };

                  return StreamBuilder<QuerySnapshot>(
                    // 2. Get the Firestore data (Names & Emails for Chat)
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'patient')
                        .snapshots(),
                    builder: (context, firestoreSnapshot) {
                      if (firestoreSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.indigo,
                          ),
                        );
                      }

                      if (firestoreSnapshot.hasError ||
                          !firestoreSnapshot.hasData) {
                        return const Center(
                          child: Text('Error loading patient directory.'),
                        );
                      }

                      // 3. Filter Firestore users: Only show patients assigned to THIS therapist
                      final allPatients = firestoreSnapshot.data!.docs;
                      final assignedDocs = allPatients.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final uid = doc.id;
                        return apiPatientMap.containsKey(uid);
                      }).toList();

                      if (assignedDocs.isEmpty) {
                        return Center(
                          child: Text(
                            'No active patients assigned to you yet.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: Colors.indigo,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: assignedDocs.length,
                          itemBuilder: (context, index) {
                            final doc = assignedDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final uid = doc.id;

                            // Grab the AI Analytics for this specific patient
                            final aiData = apiPatientMap[uid]!;

                            final String displayName =
                                data['name'] ??
                                data['email'] ??
                                'Unknown Patient';
                            final String actualEmail = data['email'] ?? '';
                            final String initial = displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?';

                            // REPLACE MOCKS WITH REAL BACKEND DATA
                            final bool isPrivate =
                                aiData['status'] ==
                                'Private (User Disabled Sharing)';
                            final int alerts = aiData['high_risk_alerts'] ?? 0;
                            final bool isCritical = alerts > 0;
                            final String latestMood =
                                aiData['latest_mood'] ?? 'No recent logs';

                            return _buildPatientCard(
                              uid: uid,
                              name: displayName,
                              email: actualEmail,
                              initial: initial,
                              alerts: alerts,
                              latestMood: latestMood,
                              isCritical: isCritical,
                              isPrivate: isPrivate,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard({
    required String uid,
    required String name,
    required String email,
    required String initial,
    required int alerts,
    required String latestMood,
    required bool isCritical,
    required bool isPrivate,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isCritical && !isPrivate)
              ? Colors.red.shade200
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: isPrivate
                    ? Colors.grey.shade200
                    : (isCritical ? Colors.red.shade50 : Colors.indigo.shade50),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: isPrivate
                        ? Colors.grey
                        : (isCritical ? Colors.red : Colors.indigo),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPrivate
                          ? 'Data sharing disabled'
                          : 'Latest: $latestMood',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // ALERTS / PRIVACY BADGE
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isPrivate
                      ? Colors.grey.shade100
                      : (isCritical ? Colors.red.shade50 : Colors.teal.shade50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isPrivate
                    ? const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                        size: 24,
                      )
                    : Column(
                        children: [
                          Text(
                            '$alerts',
                            style: TextStyle(
                              color: isCritical
                                  ? Colors.red.shade700
                                  : Colors.teal.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Alerts',
                            style: TextStyle(
                              color: isCritical
                                  ? Colors.red.shade700
                                  : Colors.teal.shade700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),

          // ACTION BUTTONS (Features perfectly retained)
          // ACTION BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Report Button (NEW)
              if (!isPrivate) // Only show if they have access
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientReportScreen(
                          // Pass the real Firebase UID and Name
                          patientId: uid, // If 'email' is the variable you used for routing, make sure to pass the actual UID here!
                          patientName: name, 
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined, size: 20),
                  label: const Text('Report'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                ),
                
              // 2. Message Button
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatScreen(receiverEmail: email)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                label: const Text('Message'),
                style: TextButton.styleFrom(foregroundColor: Colors.indigo),
              ),
              
              // 3. Notes Button
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TherapistNotes(patientEmail: email)),
                  );
                },
                icon: const Icon(Icons.edit_note, size: 20),
                label: const Text('Notes'),
                style: TextButton.styleFrom(foregroundColor: Colors.teal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

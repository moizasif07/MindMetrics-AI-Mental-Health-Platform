import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class PatientReportScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientReportScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientReportScreen> createState() => _PatientReportScreenState();
}

class _PatientReportScreenState extends State<PatientReportScreen> {
  late Future<Map<String, dynamic>?> _reportFuture;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _loadReports() {
    final user = FirebaseAuth.instance.currentUser;
    final therapistId = user?.uid ?? 'unknown';
    
    setState(() {
      _reportFuture = ApiService.fetchPatientReports(therapistId, widget.patientId);
    });
  }

  Future<void> _handleRefresh() async {
    _loadReports();
    await _reportFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.indigo),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical Report',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              widget.patientName,
              style: const TextStyle(
                color: Color(0xFF2D3748),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.indigo,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.indigo));
            }

            // If the API returns null, it means the patient revoked access (403 Forbidden)
            if (snapshot.hasError || snapshot.data == null) {
              return Stack(
                children: [
                  ListView(), // Required for pull-to-refresh
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 60, color: Colors.grey),
                        const SizedBox(height: 15),
                        const Text(
                          'Access Restricted',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'This patient has disabled data sharing.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final history = List<Map<String, dynamic>>.from(data['history'] ?? []);

            if (history.isEmpty) {
              return Stack(
                children: [
                  ListView(), 
                  const Center(child: Text('No journal entries logged yet.', style: TextStyle(color: Colors.grey))),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final log = history[index];
                final int aiScore = log['ai_score'] ?? 0;
                final bool isCritical = aiScore < 50;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isCritical ? Colors.red.shade200 : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER: Date and Score
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              log['date'] ?? 'Unknown Date',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCritical ? Colors.red.shade50 : Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCritical ? Icons.warning_amber_rounded : Icons.analytics_outlined,
                                    size: 14,
                                    color: isCritical ? Colors.red : Colors.teal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Score: $aiScore',
                                    style: TextStyle(
                                      color: isCritical ? Colors.red : Colors.teal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // MOOD LABEL
                        Row(
                          children: [
                            const Text('Mood: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              log['mood'] ?? 'Not specified',
                              style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),

                        // JOURNAL ENTRY
                        const Text('Patient Journal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(
                          log['journal'] ?? 'No text provided.',
                          style: const TextStyle(
                            height: 1.5,
                            color: Color(0xFF4A5568),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
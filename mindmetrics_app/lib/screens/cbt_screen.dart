import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CBTScreen extends StatefulWidget {
  const CBTScreen({super.key});

  @override
  State<CBTScreen> createState() => _CBTScreenState();
}

class _CBTScreenState extends State<CBTScreen> {
  late Future<List<Map<String, dynamic>>> _cbtFuture;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  // 1. Centralized function to load or refresh data
  void _loadExercises() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown_user';
    
    setState(() {
      _cbtFuture = ApiService.fetchCBTExercises(userId);
    });
  }

  // 2. The Pull-to-Refresh trigger
  Future<void> _handleRefresh() async {
    _loadExercises();
    await _cbtFuture; // Keeps the loading spinner active until data arrives
  }

  // Toggles completion state locally for the UI based on the fetched list
  void _toggleCompletion(List<Map<String, dynamic>> exercises, int index) {
    setState(() {
      exercises[index]['completed'] = !exercises[index]['completed'];
    });
  }

  // Dynamically assign icons based on the AI's "focus" field
  IconData _getIconForFocus(String focus) {
    final f = focus.toLowerCase();
    if (f.contains('anxiety') || f.contains('worry') || f.contains('overthinking')) return Icons.psychology_alt;
    if (f.contains('depression') || f.contains('energy')) return Icons.directions_run;
    return Icons.self_improvement;
  }

  // Dynamically assign colors based on the AI's "focus" field
  Color _getColorForFocus(String focus) {
    final f = focus.toLowerCase();
    if (f.contains('anxiety') || f.contains('worry') || f.contains('overthinking')) return Colors.indigo;
    if (f.contains('depression') || f.contains('energy')) return Colors.teal;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'CBT Exercises',
          style: TextStyle(color: Colors.indigo, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      // 3. Wrap body in RefreshIndicator
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.indigo,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _cbtFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.indigo));
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Stack(
                children: [
                  ListView(), // Required for RefreshIndicator to work even when empty
                  const Center(
                    child: Text(
                      'No CBT exercises available right now.\nPull down to refresh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            final exercises = snapshot.data!;
            int completedCount = exercises.where((e) => e['completed'] == true).length;
            double progress = exercises.isEmpty ? 0 : completedCount / exercises.length;

            // 4. Converted to SingleChildScrollView so the whole screen is swipe-able
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROGRESS TRACKER
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey.shade200,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Text('$completedCount/${exercises.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Personalized by AI based on your recent journal entries.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.only(left: 24, top: 20, bottom: 10),
                    child: Text('Suggested Interventions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                  ),

                  // DYNAMIC EXERCISE LIST
                  ListView.builder(
                    shrinkWrap: true, // 5. Added so it fits inside SingleChildScrollView
                    physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      final dynamicColor = _getColorForFocus(exercise['focus'] ?? '');
                      final dynamicIcon = _getIconForFocus(exercise['focus'] ?? '');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: dynamicColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(dynamicIcon, color: dynamicColor),
                            ),
                            title: Text(exercise['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('${exercise['focus']} • ${exercise['duration']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                exercise['completed'] ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: exercise['completed'] ? Colors.green : Colors.grey.shade400,
                                size: 28,
                              ),
                              onPressed: () => _toggleCompletion(exercises, index),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(exercise['description'], style: const TextStyle(height: 1.5, color: Color(0xFF4A5568))),
                                    const SizedBox(height: 15),
                                    ElevatedButton(
                                      onPressed: () {
                                        // Future feature: Open detailed interactive exercise
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: dynamicColor.withOpacity(0.1),
                                        foregroundColor: dynamicColor,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Start Exercise'),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
}
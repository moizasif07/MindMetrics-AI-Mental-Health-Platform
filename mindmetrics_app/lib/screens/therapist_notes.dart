import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TherapistNotes extends StatefulWidget {
  final String patientEmail;
  const TherapistNotes({super.key, required this.patientEmail});

  @override
  State<TherapistNotes> createState() => _TherapistNotesState();
}

class _TherapistNotesState extends State<TherapistNotes> {
  final TextEditingController _noteController = TextEditingController();

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('therapy_notes').add({
      'patient': widget.patientEmail,
      'note': _noteController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.teal),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clinical Notes', style: TextStyle(color: Color(0xFF2D3748), fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.patientEmail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          // LIVE NOTES STREAM
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('therapy_notes')
                  .where('patient', isEqualTo: widget.patientEmail)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.teal));
                
                final notes = snapshot.data!.docs;
                if (notes.isEmpty) return const Center(child: Text('No clinical notes yet.', style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final data = notes[index].data() as Map<String, dynamic>;
                    DateTime? time = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
                    String timeStr = time != null ? DateFormat('MMM d, yyyy - h:mm a').format(time) : 'Just now';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade100),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                          const Divider(),
                          Text(data['note'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF2D3748), height: 1.5)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // INPUT AREA
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter session observations or treatment plan...',
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _saveNote,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save Note'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace this with your laptop's actual IPv4 address
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>> analyzeMood(String userId, String mood, String notes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze-mood'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId, 
          'mood': mood,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to connect: $e'
      };
    }
  }

  // Fetch settings when the screen loads
  static Future<Map<String, dynamic>> fetchSettings(String userId) async {
    try {
      // Added userId as a query parameter
      final response = await http.get(Uri.parse('$baseUrl/settings?user_id=$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'share_with_therapist': false, 'push_notifications': true};
    } catch (e) {
      return {'share_with_therapist': false, 'push_notifications': true};
    }
  }

  // Save settings when the user flips a toggle
  static Future<void> updateSettings(String userId, bool share, bool push) async {
    try {
      // Added userId as a query parameter
      await http.post(
        Uri.parse('$baseUrl/settings?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'share_with_therapist': share,
          'push_notifications': push,
        }),
      );
    } catch (e) {
      print("Failed to save settings: $e");
    }
  }

  // Fetch historical data for the Analytics chart
  static Future<List<Map<String, dynamic>>> fetchMoodHistory(String userId) async {
    try {
      // Added userId as a query parameter
      final response = await http.get(Uri.parse('$baseUrl/mood-logs?user_id=$userId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['history']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCBTExercises(String userId) async {
    try {
      // Added userId as a query parameter
      final response = await http.get(Uri.parse('$baseUrl/cbt-exercises?user_id=$userId'));
      
      if (response.statusCode == 200) {
        // Successfully fetched and decoded the AI JSON data from FastAPI
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        print('Server error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print("Error fetching CBT exercises: $e");
      return [];
    }
  }


  // Fetch Therapist Profile
  static Future<Map<String, dynamic>> fetchTherapistProfile(String therapistId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/therapist/profile?user_id=$therapistId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print("Error fetching profile: $e");
      return {};
    }
  }

  // Update Therapist Profile
  static Future<void> updateTherapistProfile(String therapistId, Map<String, dynamic> profileData) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/therapist/profile?user_id=$therapistId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profileData),
      );
    } catch (e) {
      print("Failed to update profile: $e");
    }
  }

  // Fetch Assigned Patients Dashboard
  static Future<List<Map<String, dynamic>>> fetchAssignedPatients(String therapistId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/therapist/patients?therapist_id=$therapistId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['assigned_patients']);
      }
      return [];
    } catch (e) {
      print("Error fetching patients: $e");
      return [];
    }
  }

  // Fetch Detailed Patient Reports
  static Future<Map<String, dynamic>?> fetchPatientReports(String therapistId, String patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/therapist/patients/$patientId/reports?therapist_id=$therapistId')
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // This hits if the patient revoked access (403 Forbidden)
        print("Access denied or error: ${response.statusCode}");
        return null; 
      }
    } catch (e) {
      print("Error fetching reports: $e");
      return null;
    }
  }


  static Future<bool> assignPatient(String therapistId, String patientId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/therapist/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'therapist_id': therapistId,
          'patient_id': patientId,
        }),
      );
      
      if (response.statusCode == 200) {
        print("Successfully synced assignment to AI Database.");
        return true;
      } else {
        print("Failed to sync: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error syncing patient assignment: $e");
      return false;
    }
  }
}
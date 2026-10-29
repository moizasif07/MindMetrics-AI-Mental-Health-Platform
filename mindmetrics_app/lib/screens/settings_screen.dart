import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Real-time backend state for the toggles
  bool _shareData = false;
  bool _pushNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsFromBackend();
  }

  // Fetch real data from FastAPI/SQLite
  Future<void> _loadSettingsFromBackend() async {
    // 1. Grab the current user
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown_user';

    // 2. Pass the ID into the updated function
    final settings = await ApiService.fetchSettings(userId);
    if (mounted) {
      setState(() {
        _shareData = settings['share_with_therapist'] ?? false;
        _pushNotifications = settings['push_notifications'] ?? true;
        _isLoading = false;
      });
    }
  }

  // Handle toggles and instantly save to backend
  void _onShareToggled(bool value) {
    setState(() => _shareData = value);
    
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown_user';
    
    ApiService.updateSettings(userId, _shareData, _pushNotifications);
  }

  void _onPushToggled(bool value) {
    setState(() => _pushNotifications = value);
    
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'unknown_user';
    
    ApiService.updateSettings(userId, _shareData, _pushNotifications);
  }

  // Handle actual Firebase Logout
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // Handle secure password reset via Firebase
  Future<void> _handleChangePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Password reset link sent to your email!'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Failed to send reset email. Please try again.',
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F9),
        body: Center(child: CircularProgressIndicator(color: Colors.indigo)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings & Privacy',
          style: TextStyle(
            color: Colors.indigo,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. REAL-TIME PROFILE HEADER (Firebase)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.indigo.shade50,
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          String displayName = 'Loading...';
                          String displayEmail =
                              currentUser?.email ?? 'No email';

                          if (snapshot.hasData && snapshot.data!.exists) {
                            var data =
                                snapshot.data!.data() as Map<String, dynamic>;
                            displayName = data['name'] ?? 'MindMetrics User';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayEmail,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.indigo,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 2. DATA & PRIVACY SETTINGS (FastAPI / SQLite)
              _buildSectionHeader('DATA & PRIVACY'),
              _buildSettingsGroup([
                _buildToggleTile(
                  Icons.health_and_safety_outlined,
                  'Share Data with Therapist',
                  'Allow assigned clinical staff to view trends.',
                  _shareData,
                  _onShareToggled,
                ),
              ]),
              const SizedBox(height: 25),

              // 3. ACCOUNT & SECURITY SETTINGS (FastAPI / SQLite)
              _buildSectionHeader('ACCOUNT & SECURITY'),
              _buildSettingsGroup([
                _buildNavigationTile(
                  Icons.lock_outline,
                  'Change Password',
                  _handleChangePassword,
                ),
                const Divider(height: 1, indent: 50),
                _buildToggleTile(
                  Icons.notifications_active_outlined,
                  'Push Notifications',
                  'Daily reminders and alerts.',
                  _pushNotifications,
                  _onPushToggled,
                ),
              ]),
              const SizedBox(height: 25),

              // 4. SUPPORT
              _buildSectionHeader('SUPPORT'),
              _buildSettingsGroup([
                _buildNavigationTile(
                  Icons.help_outline,
                  'Help Center & FAQ',
                  () {},
                ),
                const Divider(height: 1, indent: 50),
                _buildNavigationTile(
                  Icons.description_outlined,
                  'Terms of Service',
                  () {},
                ),
              ]),
              const SizedBox(height: 35),

              // 5. LOGOUT BUTTON (Firebase Auth)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _handleLogout,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Color(0xFF2D3748),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.indigo, size: 20),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.indigo,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildNavigationTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.grey.shade700, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF2D3748),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}

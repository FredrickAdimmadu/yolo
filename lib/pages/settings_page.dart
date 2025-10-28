import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // Function to show the About dialog
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'About',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          content: const Text(
            'Created by Fredrick Adimmadu',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CLOSE', style: TextStyle(color: Colors.blueGrey)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      appBar: AppBar(
        // Disabling back button ensures navigation is only via BottomNav
        automaticallyImplyLeading: false,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.blueGrey.shade900,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Padding from the bottom of the AppBar/Header
              SizedBox(height: mq.size.height * 0.02),

              // Settings Group Container
              Container(
                margin: EdgeInsets.symmetric(horizontal: mq.size.width * 0.04),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    // Adjusted shadow for a softer, more professional look
                    BoxShadow(
                      color: Colors.black.withValues(),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(context, Icons.person_outline, 'PROFILE', 'Manage display name and avatar.'),
                    _buildSettingsTile(context, Icons.vpn_key_outlined, 'ACCOUNT', 'Security, permissions, and device linking.'),
                    _buildSettingsTile(context, Icons.support_agent_outlined, 'CONTACT', 'Get help and technical support.'),
                    _buildSettingsTile(context, Icons.policy_outlined, 'POLICIES', 'Review privacy and terms of service.'),

                    // ABOUT tile
                    _buildSettingsTile(
                      context,
                      Icons.info_outline,
                      'ABOUT',
                      'View application version and credits.',
                      onTap: () => _showAboutDialog(context),
                    ),

                    // Logout item is visually distinct
                    _buildSettingsTile(context, Icons.logout_rounded, 'LOGOUT', 'Sign out from this device.', isDestructive: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
      BuildContext context,
      IconData icon,
      String title,
      String subtitle, {
        bool isDestructive = false,
        VoidCallback? onTap, // callback
      }) {
    final color = isDestructive ? Colors.red.shade700 : Colors.blueGrey.shade800;

    Widget tile = Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          leading: Icon(icon, color: color, size: 28),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: color,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDestructive ? Colors.red.shade400 : Colors.blueGrey.shade500,
            ),
          ),
          trailing: isDestructive
              ? null // No arrow for logout
              : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueGrey.shade300),
          // Use the provided onTap callback, or an empty function if none is provided
          onTap: onTap ?? () {
            // Placeholder for default action
          },
        ),
        // LOGOUT.
        if (!isDestructive && title != 'LOGOUT')
          const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFE0E0E0)),
      ],
    );

    return tile;
  }
}

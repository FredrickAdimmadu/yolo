import 'package:flutter/material.dart';


class HomePage extends StatelessWidget {

  // Callback to switch to the Detected Page tab
  final VoidCallback onNavigateToDetection;

  const HomePage({
    super.key,

    required this.onNavigateToDetection,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // Scaffold for the individual page content
    return Scaffold(
      appBar: AppBar(
        // Disabling back button ensures navigation is only via BottomNav
        automaticallyImplyLeading: false,
        title: const Text('System Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.blueGrey.shade900,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: mq.size.width * 0.04, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Removed _buildStatusHeader call
              const SizedBox(height: 25),

              // ------------------------------------
              // First Row: MODELS & ANALYTICS
              // ------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'MODELS',
                      subtitle: 'View specs & change configuration',
                      icon: Icons.psychology_alt_rounded,
                      color: Colors.deepPurple,
                      onTap: onNavigateToDetection, // Navigate to Detection on tap
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'ANALYTICS',
                      subtitle: 'Review inference performance',
                      icon: Icons.analytics_rounded,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ------------------------------------
              // Second Row: UPDATES & DATABASE
              // ------------------------------------
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'UPDATES',
                      subtitle: 'Check for new updates',
                      icon: Icons.update_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildDashboardCard(
                      title: 'DATABASE',
                      subtitle: 'Access logged detection data',
                      icon: Icons.storage_rounded,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          height: 150, // Fixed height for two-box fit
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

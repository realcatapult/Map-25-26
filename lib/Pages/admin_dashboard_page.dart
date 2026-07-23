import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:login_ui/Pages/admin_activity_page.dart';
import 'package:login_ui/Pages/club_activity_check_page.dart';
import 'package:login_ui/services/auth_service.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:login_ui/theme/app_theme.dart';

class AdminDashboardPage extends StatelessWidget {
  AdminDashboardPage({super.key});

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  Future<void> _signOut(BuildContext context) async {
    await _authService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        actions: const [
          Icon(Icons.admin_panel_settings, color: Colors.white),
          SizedBox(width: 16),
        ],
      ),
      body: NeonBackground(
        child: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getAllGroupsForAdmin(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final pending = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['publicRequestStatus'] as String? ?? 'none') == 'pending';
          }).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome, Admin',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage club governance, public approvals, and activity checks from here.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _AdminActionCard(
                title: 'Club Approval Requests',
                subtitle: pending > 0
                    ? '$pending club requests are waiting right now.'
                    : 'No pending requests right now. Demo requests are shown on the next page.',
                icon: Icons.approval_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminActivityPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _AdminActionCard(
                title: 'Club Activity Check',
                subtitle: 'Review club engagement health and current visibility states.',
                icon: Icons.analytics_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ClubActivityCheckPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Sign Out Admin',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

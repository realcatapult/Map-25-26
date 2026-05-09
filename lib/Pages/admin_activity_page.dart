import 'package:flutter/material.dart';

enum _ClubStatus { active, atRisk, ghost }

class _ClubActivity {
  final String name;
  final IconData icon;
  final Color color;
  final _ClubStatus status;
  final int messagesThisMonth;
  final int daysSinceLastMeeting;
  final int memberCount;
  final int activeMembers;
  final String lastActive;
  final List<int> weeklyMessages; // 8 weeks, newest last

  const _ClubActivity({
    required this.name,
    required this.icon,
    required this.color,
    required this.status,
    required this.messagesThisMonth,
    required this.daysSinceLastMeeting,
    required this.memberCount,
    required this.activeMembers,
    required this.lastActive,
    required this.weeklyMessages,
  });

  double get engagementRate => activeMembers / memberCount;
}

const List<_ClubActivity> _clubs = [
  _ClubActivity(
    name: 'App Development Club',
    icon: Icons.code,
    color: Color(0xFF1A237E),
    status: _ClubStatus.active,
    messagesThisMonth: 214,
    daysSinceLastMeeting: 4,
    memberCount: 5,
    activeMembers: 5,
    lastActive: 'Today',
    weeklyMessages: [28, 35, 41, 30, 38, 44, 50, 48],
  ),
  _ClubActivity(
    name: 'Photography Club',
    icon: Icons.camera_alt,
    color: Color(0xFF1565C0),
    status: _ClubStatus.active,
    messagesThisMonth: 187,
    daysSinceLastMeeting: 7,
    memberCount: 124,
    activeMembers: 98,
    lastActive: '2 days ago',
    weeklyMessages: [20, 24, 19, 30, 27, 35, 29, 33],
  ),
  _ClubActivity(
    name: 'Coding Club',
    icon: Icons.terminal,
    color: Color(0xFF2E7D32),
    status: _ClubStatus.active,
    messagesThisMonth: 143,
    daysSinceLastMeeting: 10,
    memberCount: 89,
    activeMembers: 62,
    lastActive: '3 days ago',
    weeklyMessages: [15, 18, 22, 17, 20, 21, 19, 24],
  ),
  _ClubActivity(
    name: 'Chess Club',
    icon: Icons.extension,
    color: Color(0xFF6A1B9A),
    status: _ClubStatus.atRisk,
    messagesThisMonth: 34,
    daysSinceLastMeeting: 28,
    memberCount: 57,
    activeMembers: 12,
    lastActive: '18 days ago',
    weeklyMessages: [12, 9, 7, 5, 4, 3, 2, 2],
  ),
  _ClubActivity(
    name: 'Hiking & Outdoors',
    icon: Icons.terrain,
    color: Color(0xFFE65100),
    status: _ClubStatus.active,
    messagesThisMonth: 96,
    daysSinceLastMeeting: 14,
    memberCount: 203,
    activeMembers: 154,
    lastActive: '1 day ago',
    weeklyMessages: [10, 14, 16, 12, 15, 13, 17, 11],
  ),
  _ClubActivity(
    name: 'Art & Design Club',
    icon: Icons.palette,
    color: Color(0xFFC62828),
    status: _ClubStatus.atRisk,
    messagesThisMonth: 21,
    daysSinceLastMeeting: 35,
    memberCount: 76,
    activeMembers: 8,
    lastActive: '22 days ago',
    weeklyMessages: [9, 6, 5, 3, 2, 2, 2, 1],
  ),
  _ClubActivity(
    name: 'Environmental Club',
    icon: Icons.eco,
    color: Color(0xFF388E3C),
    status: _ClubStatus.ghost,
    messagesThisMonth: 0,
    daysSinceLastMeeting: 94,
    memberCount: 41,
    activeMembers: 1,
    lastActive: '94 days ago',
    weeklyMessages: [1, 0, 0, 0, 0, 0, 0, 0],
  ),
  _ClubActivity(
    name: 'Model UN',
    icon: Icons.public,
    color: Color(0xFF0277BD),
    status: _ClubStatus.ghost,
    messagesThisMonth: 2,
    daysSinceLastMeeting: 78,
    memberCount: 33,
    activeMembers: 2,
    lastActive: '61 days ago',
    weeklyMessages: [3, 1, 0, 0, 0, 0, 1, 0],
  ),
  _ClubActivity(
    name: 'Finance & Investing Club',
    icon: Icons.trending_up,
    color: Color(0xFF00695C),
    status: _ClubStatus.ghost,
    messagesThisMonth: 0,
    daysSinceLastMeeting: 112,
    memberCount: 28,
    activeMembers: 0,
    lastActive: '112 days ago',
    weeklyMessages: [0, 0, 0, 0, 0, 0, 0, 0],
  ),
];

class AdminActivityPage extends StatefulWidget {
  const AdminActivityPage({super.key});

  @override
  State<AdminActivityPage> createState() => _AdminActivityPageState();
}

class _AdminActivityPageState extends State<AdminActivityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _ClubStatus? _filter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _filter = null;
            break;
          case 1:
            _filter = _ClubStatus.active;
            break;
          case 2:
            _filter = _ClubStatus.atRisk;
            break;
          case 3:
            _filter = _ClubStatus.ghost;
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_ClubActivity> get _filtered =>
      _filter == null ? _clubs : _clubs.where((c) => c.status == _filter).toList();

  int get _activeCount =>
      _clubs.where((c) => c.status == _ClubStatus.active).length;
  int get _atRiskCount =>
      _clubs.where((c) => c.status == _ClubStatus.atRisk).length;
  int get _ghostCount =>
      _clubs.where((c) => c.status == _ClubStatus.ghost).length;

  Color _statusColor(_ClubStatus s) {
    switch (s) {
      case _ClubStatus.active:
        return const Color(0xFF2E7D32);
      case _ClubStatus.atRisk:
        return const Color(0xFFF57F17);
      case _ClubStatus.ghost:
        return const Color(0xFFC62828);
    }
  }

  String _statusLabel(_ClubStatus s) {
    switch (s) {
      case _ClubStatus.active:
        return 'Active';
      case _ClubStatus.atRisk:
        return 'Low Activity';
      case _ClubStatus.ghost:
        return 'Inactive';
    }
  }

  IconData _statusIcon(_ClubStatus s) {
    switch (s) {
      case _ClubStatus.active:
        return Icons.check_circle;
      case _ClubStatus.atRisk:
        return Icons.warning_amber_rounded;
      case _ClubStatus.ghost:
        return Icons.do_not_disturb_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Club Activity Monitor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'All (${_clubs.length})'),
            Tab(text: 'Active ($_activeCount)'),
            Tab(text: 'Low Activity ($_atRiskCount)'),
            Tab(text: 'Inactive ($_ghostCount)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _SummaryCard(
                  label: 'Active',
                  count: _activeCount,
                  color: const Color(0xFF2E7D32),
                  icon: Icons.check_circle,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'At Risk',
                  count: _atRiskCount,
                  color: const Color(0xFFF57F17),
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  label: 'Ghost',
                  count: _ghostCount,
                  color: const Color(0xFFC62828),
                  icon: Icons.do_not_disturb_on,
                ),
              ],
            ),
          ),

          // Ghost club callout
          if (_filter == null || _filter == _ClubStatus.ghost)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF57F17), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFF57F17), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ghost clubs are flagged when there is no meeting or chat activity for 60+ days. '
                        'At Risk clubs have declining engagement over the past 30 days.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Club list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final club = _filtered[index];
                return _ClubCard(
                  club: club,
                  statusColor: _statusColor(club.status),
                  statusLabel: _statusLabel(club.status),
                  statusIcon: _statusIcon(club.status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final _ClubActivity club;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;

  const _ClubCard({
    required this.club,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: club.color.withOpacity(0.15),
                  child: Icon(club.icon, color: club.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${club.memberCount} members · Last active ${club.lastActive}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: Colors.grey[200]),

          // Stats row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.chat_bubble_outline,
                  label: '${club.messagesThisMonth} msgs/mo',
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.event_available,
                  label: '${club.daysSinceLastMeeting}d since meeting',
                  color: club.daysSinceLastMeeting > 60
                      ? const Color(0xFFC62828)
                      : club.daysSinceLastMeeting > 21
                          ? const Color(0xFFF57F17)
                          : const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.people_outline,
                  label:
                      '${(club.engagementRate * 100).round()}% engaged',
                  color: club.engagementRate < 0.2
                      ? const Color(0xFFC62828)
                      : club.engagementRate < 0.5
                          ? const Color(0xFFF57F17)
                          : const Color(0xFF2E7D32),
                ),
              ],
            ),
          ),

          // Mini activity graph
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly message activity (8 wks)',
                  style: TextStyle(fontSize: 10, color: Colors.black38),
                ),
                const SizedBox(height: 6),
                _MiniBarChart(values: club.weeklyMessages, color: club.color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<int> values;
  final Color color;

  const _MiniBarChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1 : maxVal;

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final ratio = v / effectiveMax;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: ratio == 0 ? 0.04 : ratio,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ratio == 0
                              ? Colors.grey[300]
                              : color.withOpacity(0.4 + ratio * 0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:login_ui/services/chat_service.dart';

class ClubActivityCheckPage extends StatefulWidget {
  const ClubActivityCheckPage({super.key});

  @override
  State<ClubActivityCheckPage> createState() => _ClubActivityCheckPageState();
}

class _ClubActivityCheckPageState extends State<ClubActivityCheckPage> {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<_ClubAuditSnapshot> _buildClubAuditSnapshot(
    String groupId,
    int memberCount,
  ) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));
    final upcomingWindow = now.add(const Duration(days: 30));

    final messageDocs = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(300)
        .get();

    var messages7d = 0;
    var messages30d = 0;
    DateTime? lastMessageAt;
    final uniqueSenders30d = <String>{};
    final senderCounts30d = <String, int>{};

    for (final doc in messageDocs.docs) {
      final data = doc.data();
      final sender = (data['senderEmail'] as String?)?.trim() ?? '';
      final ts = data['timestamp'] as Timestamp?;
      final when = ts?.toDate();

      if (lastMessageAt == null && when != null) {
        lastMessageAt = when;
      }

      if (when == null || when.isBefore(thirtyDaysAgo)) {
        continue;
      }

      messages30d += 1;
      if (sender.isNotEmpty) {
        uniqueSenders30d.add(sender);
        senderCounts30d[sender] = (senderCounts30d[sender] ?? 0) + 1;
      }
      if (!when.isBefore(sevenDaysAgo)) {
        messages7d += 1;
      }
    }

    final events = await _chatService.getGroupEvents(groupId);
    var events90d = 0;
    var upcomingEvents30d = 0;
    DateTime? lastEventAt;

    for (final event in events) {
      final raw = event['date'];
      final eventDate = raw is Timestamp
          ? raw.toDate()
          : (raw is DateTime ? raw : null);
      if (eventDate == null) continue;

      if (lastEventAt == null || eventDate.isAfter(lastEventAt)) {
        lastEventAt = eventDate;
      }

      if (!eventDate.isBefore(ninetyDaysAgo) && !eventDate.isAfter(now)) {
        events90d += 1;
      }
      if (!eventDate.isBefore(now) && !eventDate.isAfter(upcomingWindow)) {
        upcomingEvents30d += 1;
      }
    }

    final participationRatio = memberCount <= 0
        ? 0.0
        : uniqueSenders30d.length / memberCount;

    final volumeScore = (messages30d * 1.5).clamp(0.0, 35.0);
    final participationScore = (participationRatio * 35).clamp(0.0, 35.0);
    final eventScore = (events90d * 7).clamp(0.0, 20.0);

    final daysSinceLastMessage = lastMessageAt == null
        ? 999
        : now.difference(lastMessageAt).inDays;
    final freshnessScore = daysSinceLastMessage <= 1
        ? 10.0
        : daysSinceLastMessage <= 3
            ? 8.0
            : daysSinceLastMessage <= 7
                ? 5.0
                : daysSinceLastMessage <= 14
                    ? 2.0
                    : 0.0;

    final activityScore = (volumeScore + participationScore + eventScore + freshnessScore)
        .round()
        .clamp(0, 100);

    final sortedContributors = senderCounts30d.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topContributors = sortedContributors.take(3).toList();

    final highestSenderCount = topContributors.isEmpty ? 0 : topContributors.first.value;
    final highestSenderShare = messages30d == 0 ? 0.0 : highestSenderCount / messages30d;

    final riskFlags = <String>[];
    if (memberCount >= 10 && messages30d < 8) {
      riskFlags.add('Low message activity relative to membership');
    }
    if (messages30d >= 20 && uniqueSenders30d.length <= 2) {
      riskFlags.add('Conversation concentrated among very few members');
    }
    if (highestSenderShare >= 0.75 && messages30d >= 20) {
      riskFlags.add('One sender dominates most recent communication');
    }
    if (events90d == 0) {
      riskFlags.add('No events recorded in the last 90 days');
    }
    if (upcomingEvents30d == 0) {
      riskFlags.add('No upcoming events scheduled in next 30 days');
    }
    if (daysSinceLastMessage > 14) {
      riskFlags.add('No recent communication in over two weeks');
    }

    return _ClubAuditSnapshot(
      activityScore: activityScore,
      messages7d: messages7d,
      messages30d: messages30d,
      uniqueSenders30d: uniqueSenders30d.length,
      participationRatio: participationRatio,
      events90d: events90d,
      upcomingEvents30d: upcomingEvents30d,
      lastMessageAt: lastMessageAt,
      lastEventAt: lastEventAt,
      topContributors: topContributors,
      riskFlags: riskFlags,
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _displayNameFromEmail(String email) {
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  void _openClubAuditDetails(
    BuildContext context, {
    required String clubName,
    required String createdBy,
    required int memberCount,
    required String visibilityStatus,
    required String postingPolicy,
    required _ClubAuditSnapshot audit,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ClubAuditDetailPage(
          clubName: clubName,
          createdBy: createdBy,
          memberCount: memberCount,
          visibilityStatus: visibilityStatus,
          postingPolicy: postingPolicy,
          audit: audit,
          displayNameFromEmail: _displayNameFromEmail,
          formatDate: _formatDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        title: Text(
          'Club Activity Check',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getAllGroupsForAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final groups = snapshot.data?.docs ?? [];
          if (groups.isEmpty) {
            return const Center(
              child: Text('No clubs found yet.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Use this page to quickly detect inactive or suspicious clubs. Tap any club card to open full in-depth activity tracking.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              ...groups.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final groupId = doc.id;
                final name = (data['name'] as String?) ?? 'Unnamed Club';
                final members = List<String>.from(data['members'] ?? const <String>[]);
                final isPublic = data['isPublic'] as bool? ?? false;
                final requestStatus = (data['publicRequestStatus'] as String?) ?? 'none';
                final whoCanPost = (data['whoCanPost'] as String?) ?? 'all';
                final createdBy = (data['createdBy'] as String?) ?? 'Unknown';

                Color statusColor;
                String statusLabel;
                if (requestStatus == 'pending') {
                  statusColor = const Color(0xFFF57F17);
                  statusLabel = 'Pending Approval';
                } else if (isPublic) {
                  statusColor = const Color(0xFF2E7D32);
                  statusLabel = 'Public';
                } else {
                  statusColor = const Color(0xFF546E7A);
                  statusLabel = 'Private';
                }

                return FutureBuilder<_ClubAuditSnapshot>(
                  future: _buildClubAuditSnapshot(groupId, members.length),
                  builder: (context, auditSnapshot) {
                    final loading = auditSnapshot.connectionState == ConnectionState.waiting;
                    final audit = auditSnapshot.data;

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: audit == null
                          ? null
                          : () => _openClubAuditDetails(
                                context,
                                clubName: name,
                                createdBy: createdBy,
                                memberCount: members.length,
                                visibilityStatus: statusLabel,
                                postingPolicy: whoCanPost == 'admins'
                                    ? 'Admins only'
                                    : 'All members',
                                audit: audit,
                              ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Created by: $createdBy'),
                            const SizedBox(height: 2),
                            Text('Members: ${members.length}'),
                            const SizedBox(height: 2),
                            Text('Posting policy: ${whoCanPost == 'admins' ? 'Admins only' : 'All members'}'),
                            const SizedBox(height: 10),
                            if (loading)
                              const LinearProgressIndicator()
                            else if (audit != null) ...[
                              Row(
                                children: [
                                  Text(
                                    'Activity Score: ${audit.activityScore}/100',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 10),
                                  if (audit.riskFlags.isNotEmpty)
                                    Text(
                                      '${audit.riskFlags.length} risk flag(s)',
                                      style: const TextStyle(
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: audit.activityScore / 100,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  _MetricChip(label: 'Msgs 7d', value: '${audit.messages7d}'),
                                  _MetricChip(label: 'Msgs 30d', value: '${audit.messages30d}'),
                                  _MetricChip(label: 'Active Senders', value: '${audit.uniqueSenders30d}'),
                                  _MetricChip(label: 'Events 90d', value: '${audit.events90d}'),
                                  _MetricChip(label: 'Upcoming 30d', value: '${audit.upcomingEvents30d}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap this club card to view in-depth activity tracking.',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ] else
                              const Text('Unable to compute activity snapshot.'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final String label;
  final String value;

  const _AuditRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ClubAuditSnapshot {
  final int activityScore;
  final int messages7d;
  final int messages30d;
  final int uniqueSenders30d;
  final double participationRatio;
  final int events90d;
  final int upcomingEvents30d;
  final DateTime? lastMessageAt;
  final DateTime? lastEventAt;
  final List<MapEntry<String, int>> topContributors;
  final List<String> riskFlags;

  const _ClubAuditSnapshot({
    required this.activityScore,
    required this.messages7d,
    required this.messages30d,
    required this.uniqueSenders30d,
    required this.participationRatio,
    required this.events90d,
    required this.upcomingEvents30d,
    required this.lastMessageAt,
    required this.lastEventAt,
    required this.topContributors,
    required this.riskFlags,
  });
}

class _ClubAuditDetailPage extends StatelessWidget {
  final String clubName;
  final String createdBy;
  final int memberCount;
  final String visibilityStatus;
  final String postingPolicy;
  final _ClubAuditSnapshot audit;
  final String Function(String) displayNameFromEmail;
  final String Function(DateTime?) formatDate;

  const _ClubAuditDetailPage({
    required this.clubName,
    required this.createdBy,
    required this.memberCount,
    required this.visibilityStatus,
    required this.postingPolicy,
    required this.audit,
    required this.displayNameFromEmail,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        title: Text(
          '$clubName Audit',
          style: TextStyle(color: colorScheme.onPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Score: ${audit.activityScore}/100',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: audit.activityScore / 100,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 12),
                _AuditRow(label: 'Created by', value: createdBy),
                _AuditRow(label: 'Members', value: '$memberCount'),
                _AuditRow(label: 'Visibility', value: visibilityStatus),
                _AuditRow(label: 'Posting policy', value: postingPolicy),
                _AuditRow(label: 'Participation ratio (30d)', value: '${(audit.participationRatio * 100).toStringAsFixed(1)}%'),
                _AuditRow(label: 'Last message', value: formatDate(audit.lastMessageAt)),
                _AuditRow(label: 'Last event', value: formatDate(audit.lastEventAt)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Communication and Event Metrics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _MetricChip(label: 'Msgs 7d', value: '${audit.messages7d}'),
                    _MetricChip(label: 'Msgs 30d', value: '${audit.messages30d}'),
                    _MetricChip(label: 'Active Senders', value: '${audit.uniqueSenders30d}'),
                    _MetricChip(label: 'Events 90d', value: '${audit.events90d}'),
                    _MetricChip(label: 'Upcoming 30d', value: '${audit.upcomingEvents30d}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top Contributors (30d)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (audit.topContributors.isEmpty)
                  Text(
                    'No contributors in the last 30 days.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  )
                else
                  ...audit.topContributors.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${displayNameFromEmail(entry.key)}: ${entry.value} messages'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Risk Flags',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 8),
                if (audit.riskFlags.isEmpty)
                  const Text('No suspicious activity signals detected from current records.')
                else
                  ...audit.riskFlags.map(
                    (flag) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $flag', style: const TextStyle(color: Color(0xFFC62828))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

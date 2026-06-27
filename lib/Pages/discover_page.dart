import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:login_ui/Pages/chat_room_page.dart';

// ── Placeholder demo data ──────────────────────────────────────────────────
class _DemoClub {
  final String name;
  final String description;
  final IconData logoIcon;
  final Color logoColor;
  final List<Color> bannerGradient;
  final int memberCount;
  final String? bannerImage;

  const _DemoClub({
    required this.name,
    required this.description,
    required this.logoIcon,
    required this.logoColor,
    required this.bannerGradient,
    required this.memberCount,
    this.bannerImage,
  });
}

const List<_DemoClub> _demoClubs = [
  _DemoClub(
    name: 'Photography Club',
    description:
        'Capture moments and explore the art of photography with fellow enthusiasts. Weekly photo walks, editing workshops, and gallery showcases.',
    logoIcon: Icons.camera_alt,
    logoColor: Color(0xFF1565C0),
    bannerGradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    memberCount: 124,
    bannerImage: 'lib/images/PhotoBanner.jpeg',
  ),
  _DemoClub(
    name: 'Coding Club',
    description:
        'Build projects, learn new technologies, and collaborate with passionate developers. Hackathons, code reviews, and mentorship sessions every week.',
    logoIcon: Icons.code,
    logoColor: Color(0xFF2E7D32),
    bannerGradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    memberCount: 89,
    bannerImage: 'lib/images/codingclub.jpeg',
  ),
  _DemoClub(
    name: 'Chess Club',
    description:
        'Sharpen your strategic thinking and compete in weekly tournaments. All skill levels welcome — beginners receive free coaching from experienced players.',
    logoIcon: Icons.extension,
    logoColor: Color(0xFF6A1B9A),
    bannerGradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    memberCount: 57,
    bannerImage: 'lib/images/chess.jpeg',
  ),
  _DemoClub(
    name: 'Hiking & Outdoors',
    description:
        'Explore scenic trails and connect with nature lovers. Weekend hikes, camping trips, and survival skill workshops held throughout the year.',
    logoIcon: Icons.terrain,
    logoColor: Color(0xFFE65100),
    bannerGradient: [Color(0xFFE65100), Color(0xFFFF8A65)],
    memberCount: 203,
  ),
  _DemoClub(
    name: 'Art & Design Club',
    description:
        'Express your creativity through painting, sketching, and digital design. Monthly exhibitions, live critique sessions, and collaborative murals.',
    logoIcon: Icons.palette,
    logoColor: Color(0xFFC62828),
    bannerGradient: [Color(0xFFC62828), Color(0xFFEF9A9A)],
    memberCount: 76,
  ),
];
// ──────────────────────────────────────────────────────────────────────────

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Discover Clubs', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatService.getPublicGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Demo / placeholder clubs ──
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Featured Clubs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ..._demoClubs.map((club) => DemoClubCard(club: club)),

              // ── Live clubs from Firestore ──
              if (docs.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 10),
                  child: Text(
                    'All Clubs',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ClubCard(
                    groupId: doc.id,
                    data: data,
                    chatService: chatService,
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Demo Club Card ─────────────────────────────────────────────────────────
class DemoClubCard extends StatefulWidget {
  final _DemoClub club;
  const DemoClubCard({super.key, required this.club});

  @override
  State<DemoClubCard> createState() => _DemoClubCardState();
}

class _DemoClubCardState extends State<DemoClubCard> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner with logo overlaid at bottom-left
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: club.bannerImage != null
                    ? Image.asset(
                        club.bannerImage!,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: club.bannerGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
              // Club logo badge
              Positioned(
                bottom: -24,
                left: 16,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(club.logoIcon, color: club.logoColor, size: 32),
                  ),
                ),
              ),
            ],
          ),
          // Club details
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 32, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        club.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _requested
                        ? OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                            ),
                            child: const Text(
                              'Requested',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              setState(() => _requested = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Request sent to join ${club.name}!'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                            ),
                            child: const Text(
                              'Request to Join',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  club.description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${club.memberCount} members',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.lock_open, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Public',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ──────────────────────────────────────────────────────────────────────────

/// Reusable club card widget used in both DiscoverPage and SearchPage.
class ClubCard extends StatelessWidget {
  final String groupId;
  final Map<String, dynamic> data;
  final ChatService chatService;

  const ClubCard({
    super.key,
    required this.groupId,
    required this.data,
    required this.chatService,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Club') as String;
    final overview = (data['overview'] ?? '') as String;
    final bannerUrl = data['bannerUrl'] as String?;
    final members = List<String>.from(data['members'] ?? []);
    final memberCount = members.length;
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final isMember = members.contains(currentEmail);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: bannerUrl != null
                ? Image.network(
                    bannerUrl,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholderBanner(),
                  )
                : _placeholderBanner(),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    isMember
                        ? OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomPage(
                                    groupId: groupId,
                                    groupName: name,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black),
                            ),
                            child: const Text(
                              'Open',
                              style: TextStyle(color: Colors.black),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              try {
                                await chatService.joinGroupById(groupId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('You joined $name!'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                            ),
                            child: const Text(
                              'Join',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ],
                ),
                if (overview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    overview,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount member${memberCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.lock_open, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Public',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBanner() {
    return Container(
      width: double.infinity,
      height: 120,
      color: Colors.grey[800],
      child: const Icon(Icons.group, size: 48, color: Colors.white54),
    );
  }
}

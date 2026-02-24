// Chat list page
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:login_ui/Pages/chat_room_page.dart';
import 'package:login_ui/Pages/direct_message_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _membersController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  bool _isCreating = false;
  bool _isPublic = true;
  String _whoCanPost = 'all';
  int _themeColor = Colors.black.value;
  String _themeIcon = 'group';

  IconData _iconFromName(String name) {
    switch (name) {
      case 'sports':
        return Icons.sports_basketball;
      case 'school':
        return Icons.school;
      case 'chat':
        return Icons.chat_bubble;
      case 'star':
        return Icons.star;
      default:
        return Icons.group;
    }
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Group Chat'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g., Team Practice',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _membersController,
                  decoration: const InputDecoration(
                    labelText: 'Member Emails',
                    hintText: 'email1@example.com, email2@example.com',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Separate emails with commas',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public Group'),
                  subtitle: const Text('Anyone with the code can join'),
                  value: _isPublic,
                  onChanged: (value) {
                    setDialogState(() {
                      _isPublic = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _whoCanPost,
                  decoration: const InputDecoration(labelText: 'Who can post'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All members')),
                    DropdownMenuItem(
                      value: 'admins',
                      child: Text('Admins only'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      _whoCanPost = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Theme color',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      [
                        Colors.black,
                        Colors.blue,
                        Colors.green,
                        Colors.grey,
                        Colors.orange,
                      ].map((color) {
                        final isSelected = _themeColor == color.value;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              _themeColor = color.value;
                            });
                          },
                          child: CircleAvatar(
                            radius: isSelected ? 16 : 14,
                            backgroundColor: color,
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Theme icon',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['group', 'sports', 'school', 'chat', 'star'].map((
                    name,
                  ) {
                    final isSelected = _themeIcon == name;
                    return ChoiceChip(
                      label: Icon(_iconFromName(name)),
                      selected: isSelected,
                      onSelected: (_) {
                        setDialogState(() {
                          _themeIcon = name;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isCreating
                  ? null
                  : () async {
                      if (_groupNameController.text.isNotEmpty) {
                        setDialogState(() {
                          _isCreating = true;
                        });

                        final members = _membersController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();

                        try {
                          await _chatService.createGroupChat(
                            _groupNameController.text,
                            members,
                            _isPublic,
                            _whoCanPost,
                            _themeColor,
                            _themeIcon,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            _groupNameController.clear();
                            _membersController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Group created!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          setDialogState(() {
                            _isCreating = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _joinCodeController,
              decoration: const InputDecoration(
                labelText: 'Join Code',
                hintText: 'Enter 6-character code',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the group join code',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_joinCodeController.text.length == 6) {
                try {
                  await _chatService.joinGroupWithCode(
                    _joinCodeController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _joinCodeController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Joined group!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Messages', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getDirectMessageThreads(),
        builder: (context, dmSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: _chatService.getUserGroups(),
            builder: (context, groupSnapshot) {
              if (dmSnapshot.connectionState == ConnectionState.waiting ||
                  groupSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (dmSnapshot.hasError) {
                return Center(child: Text('Error: ${dmSnapshot.error}'));
              }

              if (groupSnapshot.hasError) {
                return Center(child: Text('Error: ${groupSnapshot.error}'));
              }

              final dmDocs = dmSnapshot.data?.docs ?? [];
              final groupDocs = groupSnapshot.data?.docs ?? [];

              if (dmDocs.isEmpty && groupDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a group or message someone!',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (dmDocs.isNotEmpty) ...[
                    Text(
                      'Direct Messages',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...dmDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final participants = List<String>.from(
                        data['participants'] ?? [],
                      );
                      final currentEmail =
                          FirebaseAuth.instance.currentUser?.email ?? '';
                      final other = participants.firstWhere(
                        (email) => email != currentEmail,
                        orElse: () => 'Unknown',
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.black,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            other,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DirectMessagePage(
                                  threadId: doc.id,
                                  otherEmail: other,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                  if (groupDocs.isNotEmpty) ...[
                    Text(
                      'Group Chats',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...groupDocs.map((group) {
                      final groupData = group.data() as Map<String, dynamic>;
                      final groupName = groupData['name'] ?? 'Unnamed Group';
                      final members = List<String>.from(
                        groupData['members'] ?? [],
                      );
                      final themeColorValue =
                          groupData['themeColor'] ?? Colors.grey[800]!.value;
                      final themeIconName = groupData['themeIcon'] ?? 'group';
                      final themeColor = Color(themeColorValue);
                      final icon = _iconFromName(themeIconName);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: themeColor,
                            child: Icon(icon, color: Colors.white),
                          ),
                          title: Text(
                            groupName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${members.length} members',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomPage(
                                  groupId: group.id,
                                  groupName: groupName,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'join',
            onPressed: _showJoinGroupDialog,
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.login, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'create',
            onPressed: _showCreateGroupDialog,
            backgroundColor: Colors.black,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _membersController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }
}

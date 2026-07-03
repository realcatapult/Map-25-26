// Chat list page
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:login_ui/Pages/chat_room_page.dart';
import 'package:login_ui/Pages/direct_message_page.dart';
import 'package:login_ui/Pages/demo_group_chat_page.dart';
import 'package:login_ui/Pages/admin_activity_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  final TextEditingController _overviewController = TextEditingController();
  bool _isCreating = false;
  bool _isPublic = true;
  String _whoCanPost = 'all';
  int _themeColor = Colors.black.toARGB32();
  String _themeIcon = 'group';
  XFile? _bannerImageFile;

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
    _bannerImageFile = null;
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
                  controller: _overviewController,
                  decoration: const InputDecoration(
                    labelText: 'Club Overview',
                    hintText: 'Brief description of your club...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Banner image picker
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        _bannerImageFile = picked;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: _bannerImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_bannerImageFile!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 32, color: Colors.grey[600]),
                              const SizedBox(height: 4),
                              Text(
                                'Add Banner Image',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
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
                        final isSelected = _themeColor == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              _themeColor = color.toARGB32();
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
                          final groupId = await _chatService.createGroupChat(
                            _groupNameController.text,
                            members,
                            _isPublic,
                            _whoCanPost,
                            _themeColor,
                            _themeIcon,
                          );

                          // Upload banner if selected
                          String? bannerUrl;
                          if (_bannerImageFile != null) {
                            bannerUrl = await _chatService.uploadGroupBanner(
                              File(_bannerImageFile!.path),
                              groupId,
                            );
                          }

                          // Save overview and banner URL
                          final overview = _overviewController.text.trim();
                          if (overview.isNotEmpty || bannerUrl != null) {
                            await _chatService.updateGroupSettings(
                              groupId,
                              overview: overview.isNotEmpty ? overview : null,
                              bannerUrl: bannerUrl,
                            );
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                            _groupNameController.clear();
                            _membersController.clear();
                            _overviewController.clear();
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text('Messages', style: TextStyle(color: colorScheme.onPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.admin_panel_settings, color: colorScheme.onPrimary),
            tooltip: 'Admin: Club Activity',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminActivityPage(),
                ),
              );
            },
          ),
        ],
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

              // Always show list (demo group ensures it's never empty)

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (dmDocs.isNotEmpty) ...[
                    Text(
                      'Direct Messages',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
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
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            child: Icon(Icons.person, color: colorScheme.onPrimary),
                          ),
                          title: Text(
                            other,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
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
                  // Always show Group Chats section (demo + real groups)
                  ...[
                    Text(
                      'Group Chats',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Demo: App Development Club
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHigh
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF1A237E),
                          child: Icon(Icons.code, color: Colors.white),
                        ),
                        title: Text(
                          'App Development Club',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '5 members',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DemoGroupChatPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    ...groupDocs.map((group) {
                      final groupData = group.data() as Map<String, dynamic>;
                      final groupName = groupData['name'] ?? 'Unnamed Group';
                      final members = List<String>.from(
                        groupData['members'] ?? [],
                      );
                      final themeColorValue =
                          groupData['themeColor'] ?? Colors.grey[800]!.toARGB32();
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '${members.length} members',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
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
            backgroundColor: colorScheme.secondary,
            child: Icon(Icons.login, color: colorScheme.onSecondary),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'create',
            onPressed: _showCreateGroupDialog,
            backgroundColor: colorScheme.primary,
            child: Icon(Icons.add, color: colorScheme.onPrimary),
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
    _overviewController.dispose();
    super.dispose();
  }
}

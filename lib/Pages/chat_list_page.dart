import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:login_ui/Pages/chat_room_page.dart';

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

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group Chat'),
        content: Column(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          StatefulBuilder(
            builder: (context, setDialogState) {
              return ElevatedButton(
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
                    : const Text(
                        'Create',
                        style: TextStyle(color: Colors.white),
                      ),
              );
            },
          ),
        ],
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
        title: const Text('Group Chats', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getUserGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                    'No group chats yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create one to get started!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final group = snapshot.data!.docs[index];
              final groupData = group.data() as Map<String, dynamic>;
              final groupName = groupData['name'] ?? 'Unnamed Group';
              final members = List<String>.from(groupData['members'] ?? []);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.group, color: Colors.white),
                  ),
                  title: Text(
                    groupName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${members.length} members',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

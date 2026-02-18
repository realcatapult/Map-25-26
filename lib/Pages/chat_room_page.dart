import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class ChatRoomPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatRoomPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSending = false;
  final Map<String, String?> _profilePictureCache = {};

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

  Future<void> _showGroupSettingsDialog(
    Map<String, dynamic> groupData,
    bool isAdmin,
  ) async {
    if (!isAdmin) return;

    bool isPublic = groupData['isPublic'] ?? true;
    String whoCanPost = groupData['whoCanPost'] ?? 'all';
    int themeColor = groupData['themeColor'] ?? Colors.grey[900]!.value;
    String themeIcon = groupData['themeIcon'] ?? 'group';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Group Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public Group'),
                  subtitle: const Text('Anyone with the code can join'),
                  value: isPublic,
                  onChanged: (value) {
                    setDialogState(() {
                      isPublic = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: whoCanPost,
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
                      whoCanPost = value;
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
                        final isSelected = themeColor == color.value;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              themeColor = color.value;
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
                    final isSelected = themeIcon == name;
                    return ChoiceChip(
                      label: Icon(_iconFromName(name)),
                      selected: isSelected,
                      onSelected: (_) {
                        setDialogState(() {
                          themeIcon = name;
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
              onPressed: () async {
                await _chatService.updateGroupSettings(
                  widget.groupId,
                  isPublic: isPublic,
                  whoCanPost: whoCanPost,
                  themeColor: themeColor,
                  themeIcon: themeIcon,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getProfilePicture(String email) async {
    if (_profilePictureCache.containsKey(email)) {
      return _profilePictureCache[email];
    }

    final url = await _chatService.getProfilePicture(email);
    _profilePictureCache[email] = url;
    return url;
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await _chatService.sendMessage(
        widget.groupId,
        _messageController.text.trim(),
      );
      _messageController.clear();
      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  void _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _isSending = true;
      });

      final imageUrl = await _chatService.uploadImage(
        File(image.path),
        widget.groupId,
      );
      await _chatService.sendMessage(widget.groupId, '', imageUrl: imageUrl);

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending image: $e')));
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'Are you sure you want to leave this group? You will need a join code to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _chatService.leaveGroup(widget.groupId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Left group')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error leaving group: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    final currentUserEmailSafe = currentUserEmail ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: _chatService.watchGroup(widget.groupId),
      builder: (context, groupSnapshot) {
        final groupData = groupSnapshot.data?.data() as Map<String, dynamic>?;
        final members = List<String>.from(groupData?['members'] ?? []);
        final admins = List<String>.from(groupData?['admins'] ?? []);
        final createdBy = groupData?['createdBy'] ?? '';
        final whoCanPost = groupData?['whoCanPost'] ?? 'all';
        final themeColorValue =
            groupData?['themeColor'] ?? Colors.grey[900]!.value;
        final themeIconName = groupData?['themeIcon'] ?? 'group';
        final themeColor = Color(themeColorValue);
        final effectiveAdmins = admins.isNotEmpty
            ? admins
            : (createdBy.isNotEmpty ? [createdBy] : <String>[]);
        final isAdmin = effectiveAdmins.contains(currentUserEmailSafe);
        final canSend = whoCanPost == 'all' || isAdmin;
        final brightness = ThemeData.estimateBrightnessForColor(themeColor);
        final onThemeColor = brightness == Brightness.dark
            ? Colors.white
            : Colors.black;

        return Scaffold(
          backgroundColor: Colors.grey[300],
          appBar: AppBar(
            backgroundColor: themeColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: onThemeColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _iconFromName(themeIconName),
                      color: onThemeColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.groupName,
                      style: TextStyle(color: onThemeColor, fontSize: 18),
                    ),
                  ],
                ),
                Text(
                  '${members.length} members',
                  style: TextStyle(
                    color: onThemeColor.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            iconTheme: IconThemeData(color: onThemeColor),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Group settings',
                  onPressed: () =>
                      _showGroupSettingsDialog(groupData ?? {}, isAdmin),
                ),
              IconButton(
                icon: const Icon(Icons.home),
                tooltip: 'Back to home',
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Leave group',
                onPressed: _leaveGroup,
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () async {
                  final joinCode = groupData?['joinCode'] ?? 'N/A';

                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Group Info'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Code:',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  joinCode,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: joinCode),
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Join code copied!'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Share this code with others to let them join the group.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          if (isAdmin)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showGroupSettingsDialog(
                                  groupData ?? {},
                                  isAdmin,
                                );
                              },
                              child: const Text('Manage Group'),
                            ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _leaveGroup();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Leave Group'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Messages list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessages(widget.groupId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message =
                            messages[index].data() as Map<String, dynamic>;
                        final text = message['text'] ?? '';
                        final imageUrl = message['imageUrl'] as String?;
                        final senderEmail = message['senderEmail'] ?? '';
                        final isMe = senderEmail == currentUserEmail;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                FutureBuilder<String?>(
                                  future: _getProfilePicture(senderEmail),
                                  builder: (context, snapshot) {
                                    return CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey[400],
                                      backgroundImage:
                                          snapshot.hasData &&
                                              snapshot.data != null
                                          ? CachedNetworkImageProvider(
                                              snapshot.data!,
                                            )
                                          : null,
                                      child:
                                          snapshot.hasData &&
                                              snapshot.data != null
                                          ? null
                                          : Text(
                                              senderEmail[0].toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? themeColor : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        senderEmail.split('@')[0],
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (!isMe) const SizedBox(height: 4),
                                    if (imageUrl != null)
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              child: InteractiveViewer(
                                                child: Image.network(imageUrl),
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            width: 200,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 600,
                                            placeholder: (context, url) =>
                                                const SizedBox(
                                                  width: 200,
                                                  height: 200,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    if (text.isNotEmpty) ...[
                                      if (imageUrl != null)
                                        const SizedBox(height: 8),
                                      Text(
                                        text,
                                        style: TextStyle(
                                          color: isMe
                                              ? onThemeColor
                                              : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                FutureBuilder<String?>(
                                  future: _getProfilePicture(senderEmail),
                                  builder: (context, snapshot) {
                                    return CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage:
                                          snapshot.hasData &&
                                              snapshot.data != null
                                          ? CachedNetworkImageProvider(
                                              snapshot.data!,
                                            )
                                          : null,
                                      child:
                                          snapshot.hasData &&
                                              snapshot.data != null
                                          ? null
                                          : Text(
                                              senderEmail[0].toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Message input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.grey),
                      onPressed: _isSending || !canSend
                          ? null
                          : _showImageSourceDialog,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: canSend
                              ? 'Type a message...'
                              : 'Only admins can send messages',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_isSending && canSend,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: themeColor,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: canSend ? _sendMessage : null,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

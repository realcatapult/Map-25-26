import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:login_ui/Pages/direct_message_page.dart';
import 'package:login_ui/data/interests_catalog.dart';
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

  Future<void> _showAddEventDialog(String groupName) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event title',
                    hintText: 'e.g., Practice',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(
                    '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Time'),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTime = picked;
                      });
                    }
                  },
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
              onPressed: isSaving
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter an event title'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      final eventDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      try {
                        await _chatService.addGroupEvent(
                          widget.groupId,
                          groupName,
                          title,
                          descriptionController.text.trim(),
                          eventDateTime,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Event added to calendar'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error adding event: $e')),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() {
                            isSaving = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }

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
    List<String> members,
    List<String> admins,
    String createdBy,
    bool isAdmin,
  ) async {
    if (!isAdmin) return;

    bool isPublic = groupData['isPublic'] ?? true;
    String whoCanPost = groupData['whoCanPost'] ?? 'all';
    int themeColor = groupData['themeColor'] ?? Colors.grey[900]!.toARGB32();
    String themeIcon = groupData['themeIcon'] ?? 'group';
    final keywordsController = TextEditingController(
      text: List<String>.from(groupData['keywords'] ?? const <String>[]).join(', '),
    );
    final adminSet = {...admins};
    if (createdBy.isNotEmpty) {
      adminSet.add(createdBy);
    }

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
                  initialValue: whoCanPost,
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
                        final isSelected = themeColor == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              themeColor = color.toARGB32();
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
                const SizedBox(height: 16),
                TextField(
                  controller: keywordsController,
                  decoration: const InputDecoration(
                    labelText: 'Club keywords',
                    hintText: 'Math, Chemistry, STEM, Law...',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: InterestsCatalog.all.take(18).map((keyword) {
                    return ActionChip(
                      label: Text(keyword),
                      onPressed: () {
                        final existing = keywordsController.text
                            .split(',')
                            .map((value) => value.trim())
                            .where((value) => value.isNotEmpty)
                            .toList();
                        if (existing.any(
                          (value) => value.toLowerCase() == keyword.toLowerCase(),
                        )) {
                          return;
                        }
                        setDialogState(() {
                          existing.add(keyword);
                          keywordsController.text = existing.join(', ');
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Admins',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                ...members.map((member) {
                  final isCreator = member == createdBy;
                  final isSelected = adminSet.contains(member);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(member),
                    value: isSelected,
                    onChanged: isCreator
                        ? null
                        : (value) {
                            setDialogState(() {
                              if (value == true) {
                                adminSet.add(member);
                              } else {
                                adminSet.remove(member);
                              }
                            });
                          },
                    subtitle: isCreator
                        ? const Text('Group creator')
                        : const Text(''),
                  );
                }),
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
                final keywords = InterestsCatalog.normalize(
                  keywordsController.text
                      .split(',')
                      .map((value) => value.trim())
                      .toList(),
                );

                await _chatService.updateGroupSettings(
                  widget.groupId,
                  isPublic: isPublic,
                  whoCanPost: whoCanPost,
                  themeColor: themeColor,
                  themeIcon: themeIcon,
                  keywords: keywords,
                );
                await _chatService.updateGroupAdmins(
                  widget.groupId,
                  adminSet.toList(),
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

    keywordsController.dispose();
  }

  Future<void> _openDirectMessage(String otherEmail) async {
    try {
      final threadId = await _chatService.getOrCreateDirectMessage(otherEmail);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DirectMessagePage(threadId: threadId, otherEmail: otherEmail),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening DM: $e')));
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: _chatService.watchGroup(widget.groupId),
      builder: (context, groupSnapshot) {
        final groupData = groupSnapshot.data?.data() as Map<String, dynamic>?;
        final members = List<String>.from(groupData?['members'] ?? []);
        final admins = List<String>.from(groupData?['admins'] ?? []);
        final createdBy = groupData?['createdBy'] ?? '';
        final whoCanPost = groupData?['whoCanPost'] ?? 'all';
        final themeColorValue =
            groupData?['themeColor'] ?? Colors.grey[900]!.toARGB32();
        final themeIconName = groupData?['themeIcon'] ?? 'group';
        final themeColor = Color(themeColorValue);
        final effectiveAdmins = admins.isNotEmpty
            ? admins
            : (createdBy.isNotEmpty ? <String>[createdBy] : <String>[]);
        final isAdmin = effectiveAdmins.contains(currentUserEmailSafe);
        final isOwner = createdBy == currentUserEmailSafe;
        final canSend = whoCanPost == 'all' || isAdmin;
        final brightness = ThemeData.estimateBrightnessForColor(themeColor);
        final onThemeColor = brightness == Brightness.dark
            ? Colors.white
            : Colors.black;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFromName(themeIconName),
                      color: onThemeColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.groupName,
                        style: TextStyle(color: onThemeColor, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${members.length} members',
                  style: TextStyle(
                    color: onThemeColor.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            iconTheme: IconThemeData(color: onThemeColor),
            actions: [
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.event_note),
                  tooltip: 'Manage calendar',
                  onPressed: () => _showAddEventDialog(widget.groupName),
                ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Group settings',
                  onPressed: () => _showGroupSettingsDialog(
                    groupData ?? {},
                    members,
                    effectiveAdmins,
                    createdBy,
                    isAdmin,
                  ),
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
                            const SizedBox(height: 16),
                            Text(
                              'Members',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...members.map((member) {
                              final isSelf = member == (currentUserEmail ?? '');
                              return Row(
                                children: [
                                  Expanded(child: Text(member)),
                                  if (!isSelf)
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _openDirectMessage(member);
                                      },
                                      child: const Text('Message'),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                        actions: [
                          if (isOwner)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showAddEventDialog(widget.groupName);
                              },
                              child: const Text('Manage Calendar'),
                            ),
                          if (isAdmin)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showGroupSettingsDialog(
                                  groupData ?? {},
                                  members,
                                  effectiveAdmins,
                                  createdBy,
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
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                        final timestamp =
                            (message['timestamp'] as Timestamp?)?.toDate();

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
                                      backgroundColor: isDark
                                          ? colorScheme.surfaceContainerHigh
                                          : colorScheme.surfaceContainerHighest,
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
                                  color: isMe
                                      ? themeColor
                                      : (isDark
                                          ? colorScheme.surfaceContainerHigh
                                          : colorScheme.surface),
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
                                          color: colorScheme.onSurfaceVariant,
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
                                              : colorScheme.onSurface,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                    if (timestamp != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(timestamp),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isMe
                                              ? onThemeColor.withValues(
                                                  alpha: 0.7,
                                                )
                                              : colorScheme.onSurfaceVariant,
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
                                      backgroundColor: colorScheme.primary,
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
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHigh
                      : colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.image,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? colorScheme.surfaceContainerHigh
                              : colorScheme.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(color: colorScheme.onSurface),
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

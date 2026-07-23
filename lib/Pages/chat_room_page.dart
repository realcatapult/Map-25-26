import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:login_ui/Pages/direct_message_page.dart';
import 'package:login_ui/components/jarvis_avatar.dart';
import 'package:login_ui/data/interests_catalog.dart';
import 'package:login_ui/services/ai_service.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:login_ui/theme/app_theme.dart';
import 'package:login_ui/components/unity_logo.dart';

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
  final AiService _aiService = AiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, String?> _profilePictureCache = {};

  bool _isSending = false;
  bool _jarvisThinking = false;
  bool _isGeneratingSummary = false;
  Map<String, dynamic>? _replyContext;
  String? _activeThreadRootId;

  static const List<String> _quickReactions = <String>['👍', '🔥', '🎉'];

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

  String _displayName(String email) {
    if (Jarvis.isJarvis(email)) return Jarvis.displayName;
    if (!email.contains('@')) return email;
    return email.split('@').first;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<String?> _getProfilePicture(String email) async {
    if (_profilePictureCache.containsKey(email)) {
      return _profilePictureCache[email];
    }
    final url = await _chatService.getProfilePicture(email);
    _profilePictureCache[email] = url;
    return url;
  }

  List<QueryDocumentSnapshot> _filteredMessages(List<QueryDocumentSnapshot> docs) {
    if (_activeThreadRootId == null) return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return doc.id == _activeThreadRootId ||
          data['threadRootId'] == _activeThreadRootId;
    }).toList();
  }

  int _replyCountForMessage(String messageId, List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['threadRootId'] == messageId;
    }).length;
  }

  Map<String, int> _reactionCounts(List<String> reactionKeys) {
    final counts = <String, int>{};
    for (final key in reactionKeys) {
      final emoji = key.split('::').first;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  bool _userHasReaction(List<String> reactionKeys, String emoji, String email) {
    return reactionKeys.contains('$emoji::$email');
  }

  void _setReplyContext(String messageId, Map<String, dynamic> message) {
    final preview = ((message['text'] as String?) ?? '').trim();
    final sender = (message['senderEmail'] as String?) ?? '';
    setState(() {
      _replyContext = {
        'id': messageId,
        'threadRootId': (message['threadRootId'] as String?) ?? messageId,
        'preview': preview.isEmpty ? 'Attachment' : preview,
        'sender': sender,
      };
    });
  }

  void _clearReplyContext() {
    setState(() {
      _replyContext = null;
    });
  }

  void _openThread(String rootMessageId) {
    setState(() {
      _activeThreadRootId = rootMessageId;
    });
  }

  void _closeThread() {
    setState(() {
      _activeThreadRootId = null;
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
                  decoration: const InputDecoration(labelText: 'Event title'),
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
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
                      if (title.isEmpty) return;
                      setDialogState(() => isSaving = true);
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
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event added to calendar')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding event: $e')),
                        );
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showGroupSettingsDialog(
    Map<String, dynamic> groupData,
    List<String> members,
    List<String> admins,
    String createdBy,
    bool isAdmin,
  ) async {
    if (!isAdmin) return;

    String whoCanPost = groupData['whoCanPost'] ?? 'all';
    int themeColor = groupData['themeColor'] ?? Colors.grey[900]!.toARGB32();
    String themeIcon = groupData['themeIcon'] ?? 'group';
    final bool isPublic = groupData['isPublic'] as bool? ?? false;
    final String publicRequestStatus =
        (groupData['publicRequestStatus'] as String?) ?? 'none';
    final keywordsController = TextEditingController(
      text: List<String>.from(groupData['keywords'] ?? const <String>[]).join(', '),
    );
    final adminSet = {...admins};
    if (createdBy.isNotEmpty) adminSet.add(createdBy);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Group Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Club visibility'),
                  subtitle: Text(
                    isPublic
                        ? 'This club is public and joinable from discovery.'
                        : publicRequestStatus == 'pending'
                            ? 'Public listing request is waiting for school admin approval.'
                            : publicRequestStatus == 'rejected'
                                ? 'A school admin rejected the last public listing request.'
                                : 'This club is private and hidden from discovery.',
                  ),
                  trailing: _buildVisibilityActionChip(
                    context,
                    isPublic: isPublic,
                    publicRequestStatus: publicRequestStatus,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: whoCanPost,
                  decoration: const InputDecoration(labelText: 'Who can post'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All members')),
                    DropdownMenuItem(value: 'admins', child: Text('Admins only')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => whoCanPost = value);
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
                  children: [
                    AppColors.navy,
                    AppColors.brass,
                    Colors.blue,
                    Colors.green,
                    Colors.orange,
                  ].map((color) {
                    final isSelected = themeColor == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setDialogState(() => themeColor = color.toARGB32()),
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
                  children: ['group', 'sports', 'school', 'chat', 'star'].map((name) {
                    return ChoiceChip(
                      label: Icon(_iconFromName(name)),
                      selected: themeIcon == name,
                      onSelected: (_) => setDialogState(() => themeIcon = name),
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
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(member),
                    subtitle: isCreator ? const Text('Group creator') : null,
                    value: adminSet.contains(member),
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
                  whoCanPost: whoCanPost,
                  themeColor: themeColor,
                  themeIcon: themeIcon,
                  keywords: keywords,
                );
                await _chatService.updateGroupAdmins(widget.groupId, adminSet.toList());
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    keywordsController.dispose();
  }

  Widget _buildVisibilityActionChip(
    BuildContext context, {
    required bool isPublic,
    required String publicRequestStatus,
  }) {
    if (isPublic) {
      return ActionChip(
        label: const Text('Make private'),
        onPressed: () async {
          await _chatService.setGroupPrivate(widget.groupId);
          if (!context.mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Club removed from discovery.')),
          );
        },
      );
    }

    if (publicRequestStatus == 'pending') {
      return ActionChip(
        label: const Text('Cancel request'),
        onPressed: () async {
          await _chatService.cancelPublicApprovalRequest(widget.groupId);
          if (!context.mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Public listing request cancelled.')),
          );
        },
      );
    }

    return ActionChip(
      label: const Text('Request approval'),
      onPressed: () async {
        await _chatService.requestPublicApproval(widget.groupId);
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School admin approval requested for public listing.'),
          ),
        );
      },
    );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening DM: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _chatService.sendMessage(
        widget.groupId,
        text,
        replyToMessageId: _replyContext?['id'] as String?,
        replyToText: _replyContext?['preview'] as String?,
        replyToSender: _replyContext?['sender'] as String?,
        threadRootId: (_replyContext?['threadRootId'] as String?) ?? _activeThreadRootId,
      );
      _messageController.clear();
      _clearReplyContext();
      _scrollToBottom();

      final question = Jarvis.extractQuestion(text);
      if (question != null) {
        _handleJarvis(question);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _handleJarvis(String question) async {
    setState(() => _jarvisThinking = true);
    _scrollToBottom();

    try {
      final chatContext = await _chatService.getRecentGroupMessages(
        widget.groupId,
        limit: 10,
      );
      final reply = question.isEmpty
          ? 'Hi! Ask me anything after "@jarvis".'
          : await _aiService.askJarvis(question, recentMessages: chatContext);
      await _chatService.postJarvisMessage(widget.groupId, reply);
    } catch (_) {
      await _chatService.postJarvisMessage(
        widget.groupId,
        'Sorry, I could not answer that right now. Please try again.',
      );
    } finally {
      if (!mounted) return;
      setState(() => _jarvisThinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      setState(() => _isSending = true);

      final imageUrl = await _chatService.uploadImage(File(image.path), widget.groupId);
      await _chatService.sendMessage(
        widget.groupId,
        '',
        imageUrl: imageUrl,
        type: 'image',
        replyToMessageId: _replyContext?['id'] as String?,
        replyToText: _replyContext?['preview'] as String?,
        replyToSender: _replyContext?['sender'] as String?,
        threadRootId: (_replyContext?['threadRootId'] as String?) ?? _activeThreadRootId,
      );
      _clearReplyContext();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.single;
      if (pickedFile.path == null) return;

      setState(() => _isSending = true);
      final uploaded = await _chatService.uploadGroupFile(
        File(pickedFile.path!),
        widget.groupId,
        pickedFile.name,
      );
      await _chatService.sendMessage(
        widget.groupId,
        '',
        type: 'file',
        file: uploaded,
        replyToMessageId: _replyContext?['id'] as String?,
        replyToText: _replyContext?['preview'] as String?,
        replyToSender: _replyContext?['sender'] as String?,
        threadRootId: (_replyContext?['threadRootId'] as String?) ?? _activeThreadRootId,
      );
      _clearReplyContext();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
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

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showImageSourceDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined),
              title: const Text('Poll'),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (!mounted) return;
                // Open poll composer on next frame after sheet has fully closed.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showPollComposer();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPollComposer() async {
    final pageContext = context;
    final questionController = TextEditingController();
    final optionsController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: pageContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogStateContext, setDialogState) => AlertDialog(
          title: const Text('Create Poll'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: optionsController,
                decoration: const InputDecoration(
                  labelText: 'Options',
                  hintText: 'One option per line',
                ),
                minLines: 3,
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final question = questionController.text.trim();
                      final options = optionsController.text
                          .split('\n')
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList();
                      if (question.isEmpty || options.length < 2) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await _chatService.sendPoll(
                          widget.groupId,
                          question: question,
                          options: options,
                        );
                        if (!mounted || !dialogStateContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _scrollToBottom();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(pageContext).showSnackBar(
                          SnackBar(content: Text('Error creating poll: $e')),
                        );
                        if (dialogStateContext.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              child: const Text('Post poll'),
            ),
          ],
        ),
      ),
    );

    questionController.dispose();
    optionsController.dispose();
  }

  Future<void> _showMessageActions({
    required String messageId,
    required Map<String, dynamic> message,
    required int replyCount,
    required bool isAdmin,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _setReplyContext(messageId, message);
              },
            ),
            if (replyCount > 0 || message['threadRootId'] != null)
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('View thread'),
                onTap: () {
                  Navigator.pop(context);
                  _openThread((message['threadRootId'] as String?) ?? messageId);
                },
              ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin message'),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatService.pinMessage(widget.groupId, messageId, message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _summarizeRecentActivity() async {
    if (_isGeneratingSummary) return;
    setState(() => _isGeneratingSummary = true);
    try {
      final recentMessages = await _chatService.getRecentGroupMessages(
        widget.groupId,
        limit: 25,
      );
      final reply = await _aiService.askJarvis(
        'Summarize the missed activity in this group in 3 to 5 short bullets.',
        recentMessages: recentMessages,
      );
      await _chatService.postJarvisMessage(widget.groupId, reply);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted a catch-up summary from Jarvis.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating summary: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
      }
    }
  }

  Future<void> _leaveGroup() async {
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
    if (confirm != true) return;

    try {
      await _chatService.leaveGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left group')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving group: $e')),
      );
    }
  }

  Widget _buildReplyPreview(
    Map<String, dynamic> message,
    Color textColor,
    Color mutedColor,
  ) {
    final replyText = (message['replyToText'] as String?) ?? '';
    final replySender = (message['replyToSender'] as String?) ?? '';
    if (replyText.isEmpty && replySender.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayName(replySender),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: mutedColor),
          ),
          const SizedBox(height: 2),
          Text(
            replyText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachment(
    BuildContext context,
    Map<String, dynamic> fileData,
    Color textColor,
    Color mutedColor,
  ) {
    final fileName = (fileData['name'] as String?) ?? 'Attachment';
    final fileUrl = (fileData['url'] as String?) ?? '';
    final fileSize = _formatFileSize(fileData['sizeBytes'] as int?);
    final extension = (fileData['extension'] as String?) ?? '';

    return InkWell(
      onTap: fileUrl.isEmpty
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: fileUrl));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attachment link copied.')),
              );
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  if (fileSize.isNotEmpty || extension.isNotEmpty)
                    Text(
                      [if (extension.isNotEmpty) extension.toUpperCase(), if (fileSize.isNotEmpty) fileSize].join(' • '),
                      style: TextStyle(fontSize: 11, color: mutedColor),
                    ),
                ],
              ),
            ),
            Icon(Icons.copy, size: 16, color: mutedColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPollCard(
    String messageId,
    Map<String, dynamic> poll,
    String currentUserEmail,
    Color accentColor,
    Color textColor,
    Color mutedColor,
  ) {
    final question = (poll['question'] as String?) ?? 'Poll';
    final options = List<Map<String, dynamic>>.from(
      (poll['options'] as List? ?? const <dynamic>[]).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final votes = Map<String, dynamic>.from(poll['votes'] ?? const {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...options.map((option) {
          final optionId = option['id'] as String? ?? '';
          final label = option['label'] as String? ?? 'Option';
          final voters = List<String>.from(votes[optionId] ?? const <String>[]);
          final isSelected = voters.contains(currentUserEmail);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _chatService.togglePollVote(widget.groupId, messageId, optionId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: TextStyle(color: textColor))),
                    Text(
                      '${voters.length}',
                      style: TextStyle(color: isSelected ? accentColor : mutedColor, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReactionBar({
    required String messageId,
    required List<String> reactionKeys,
    required String currentUserEmail,
    required Color textColor,
    required Color accentColor,
  }) {
    final counts = _reactionCounts(reactionKeys);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _quickReactions.map((emoji) {
        final count = counts[emoji] ?? 0;
        final isSelected = _userHasReaction(reactionKeys, emoji, currentUserEmail);
        return InkWell(
          onTap: () => _chatService.toggleMessageReaction(widget.groupId, messageId, emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count > 0 ? '$emoji $count' : emoji,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? accentColor : textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvatar(String email, bool isDark, ColorScheme colorScheme) {
    if (Jarvis.isJarvis(email)) {
      return const JarvisAvatar(radius: 16);
    }

    return FutureBuilder<String?>(
      future: _getProfilePicture(email),
      builder: (context, snapshot) {
        return CircleAvatar(
          radius: 16,
          backgroundColor: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainerHighest,
          backgroundImage: snapshot.hasData && snapshot.data != null
              ? CachedNetworkImageProvider(snapshot.data!)
              : null,
          child: snapshot.hasData && snapshot.data != null
              ? null
              : Text(
                  email.isNotEmpty ? email[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
        );
      },
    );
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
        final themeColorValue = groupData?['themeColor'] ?? Colors.grey[900]!.toARGB32();
        final themeIconName = groupData?['themeIcon'] ?? 'group';
        final themeColor = Color(themeColorValue);
        final effectiveAdmins = admins.isNotEmpty
            ? admins
            : (createdBy.isNotEmpty ? <String>[createdBy] : <String>[]);
        final isAdmin = effectiveAdmins.contains(currentUserEmailSafe);
        final isOwner = createdBy == currentUserEmailSafe;
        final canSend = whoCanPost == 'all' || isAdmin;
        final brightness = ThemeData.estimateBrightnessForColor(themeColor);
        final onThemeColor = brightness == Brightness.dark ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: themeColor,
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, Color.lerp(themeColor, AppColors.deepBlue, 0.5) ?? themeColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
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
                    Icon(_iconFromName(themeIconName), color: onThemeColor, size: 18),
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
                  style: TextStyle(color: onThemeColor.withValues(alpha: 0.8), fontSize: 12),
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
              IconButton(
                icon: _isGeneratingSummary
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: onThemeColor),
                      )
                    : const Icon(Icons.summarize_outlined),
                tooltip: 'Summarize missed activity',
                onPressed: _isGeneratingSummary ? null : _summarizeRecentActivity,
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
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Leave group',
                onPressed: _leaveGroup,
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  final joinCode = groupData?['joinCode'] ?? 'N/A';
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Group Info'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join Code:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                joinCode,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: joinCode));
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Join code copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Share this code with others to let them join the group.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          Text('Members', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          ...members.map((member) {
                            final isSelf = member == currentUserEmailSafe;
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
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Leave Group'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: NeonBackground(
            child: Column(
              children: [
                if ((groupData?['pinnedMessageId'] as String?) != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: themeColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.push_pin, size: 18, color: themeColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pinned message',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (groupData?['pinnedMessageText'] as String?) ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openThread((groupData?['pinnedMessageId'] as String?)!),
                          child: const Text('Open'),
                        ),
                        if (isAdmin)
                          IconButton(
                            onPressed: () => _chatService.clearPinnedMessage(widget.groupId),
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessages(widget.groupId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const UnityLoadingIndicator();
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final allMessages = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
                      final messages = _filteredMessages(allMessages);
                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            _activeThreadRootId == null
                                ? 'No messages yet. Start the conversation!'
                                : 'No replies in this thread yet.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length + (_jarvisThinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_jarvisThinking && index == messages.length) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const JarvisAvatar(radius: 16),
                                  const SizedBox(width: 8),
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Jarvis is thinking...',
                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final messageDoc = messages[index];
                          final message = messageDoc.data() as Map<String, dynamic>;
                          final messageId = messageDoc.id;
                          final text = (message['text'] as String?) ?? '';
                          final imageUrl = message['imageUrl'] as String?;
                          final senderEmail = (message['senderEmail'] as String?) ?? '';
                          final isMe = senderEmail == currentUserEmail;
                          final timestamp = (message['timestamp'] as Timestamp?)?.toDate();
                          final fileData = message['file'] == null
                              ? null
                              : Map<String, dynamic>.from(message['file'] as Map);
                          final pollData = message['poll'] == null
                              ? null
                              : Map<String, dynamic>.from(message['poll'] as Map);
                          final reactionKeys = List<String>.from(message['reactions'] ?? const <String>[]);
                          final replyCount = _replyCountForMessage(messageId, allMessages);
                          final bubbleTextColor = isMe ? onThemeColor : colorScheme.onSurface;
                          final bubbleMutedColor = isMe
                              ? onThemeColor.withValues(alpha: 0.72)
                              : colorScheme.onSurfaceVariant;

                          return AnimatedEntrance(
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    _buildAvatar(senderEmail, isDark, colorScheme),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: GestureDetector(
                                      onLongPress: () => _showMessageActions(
                                        messageId: messageId,
                                        message: message,
                                        replyCount: replyCount,
                                        isAdmin: isAdmin,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context).size.width * 0.74,
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
                                                    _displayName(senderEmail),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Jarvis.isJarvis(senderEmail)
                                                          ? AppColors.brass
                                                          : colorScheme.onSurfaceVariant,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                if (!isMe) const SizedBox(height: 4),
                                                _buildReplyPreview(message, bubbleTextColor, bubbleMutedColor),
                                                if (pollData != null)
                                                  _buildPollCard(
                                                    messageId,
                                                    pollData,
                                                    currentUserEmailSafe,
                                                    themeColor,
                                                    bubbleTextColor,
                                                    bubbleMutedColor,
                                                  ),
                                                if (fileData != null) ...[
                                                  _buildFileAttachment(
                                                    context,
                                                    fileData,
                                                    bubbleTextColor,
                                                    bubbleMutedColor,
                                                  ),
                                                  if (text.isNotEmpty) const SizedBox(height: 8),
                                                ],
                                                if (imageUrl != null) ...[
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
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: CachedNetworkImage(
                                                        imageUrl: imageUrl,
                                                        width: 200,
                                                        fit: BoxFit.cover,
                                                        memCacheWidth: 600,
                                                        placeholder: (context, url) => const SizedBox(
                                                          width: 200,
                                                          height: 200,
                                                          child: Center(
                                                            child: CircularProgressIndicator(),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (text.isNotEmpty) const SizedBox(height: 8),
                                                ],
                                                if (text.isNotEmpty && pollData == null)
                                                  Text(
                                                    text,
                                                    style: TextStyle(color: bubbleTextColor, fontSize: 14),
                                                  ),
                                                if (timestamp != null) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatTime(timestamp),
                                                    style: TextStyle(fontSize: 9, color: bubbleMutedColor),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (replyCount > 0 && _activeThreadRootId == null)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                                              child: InkWell(
                                                onTap: () => _openThread(messageId),
                                                child: Text(
                                                  '$replyCount repl${replyCount == 1 ? 'y' : 'ies'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: themeColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          _buildReactionBar(
                                            messageId: messageId,
                                            reactionKeys: reactionKeys,
                                            currentUserEmail: currentUserEmailSafe,
                                            textColor: colorScheme.onSurfaceVariant,
                                            accentColor: themeColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 8),
                                    _buildAvatar(senderEmail, isDark, colorScheme),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface)
                        .withValues(alpha: 0.92),
                    border: Border(
                      top: BorderSide(color: AppColors.cyan.withValues(alpha: 0.18), width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_activeThreadRootId != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.forum_outlined, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Replying in thread')),
                              TextButton(onPressed: _closeThread, child: const Text('Exit')),
                            ],
                          ),
                        ),
                      if (_replyContext != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Replying to ${_displayName((_replyContext?['sender'] as String?) ?? '')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (_replyContext?['preview'] as String?) ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _clearReplyContext,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.add_circle_outline, color: colorScheme.onSurfaceVariant),
                            onPressed: _isSending || !canSend ? null : _showAttachmentSheet,
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                              style: TextStyle(color: colorScheme.onSurface),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              enabled: !_isSending && canSend,
                              onSubmitted: (_) => canSend ? _sendMessage() : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: themeColor,
                            child: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                    onPressed: canSend ? _sendMessage : null,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

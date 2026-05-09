import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _DemoMessage {
  final String senderEmail;
  final String text;
  final DateTime timestamp;

  const _DemoMessage({
    required this.senderEmail,
    required this.text,
    required this.timestamp,
  });
}

class DemoGroupChatPage extends StatefulWidget {
  const DemoGroupChatPage({super.key});

  @override
  State<DemoGroupChatPage> createState() => _DemoGroupChatPageState();
}

class _DemoGroupChatPageState extends State<DemoGroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late List<_DemoMessage> _messages;

  @override
  void initState() {
    super.initState();
    final me = FirebaseAuth.instance.currentUser?.email ?? 'you@example.com';
    final now = DateTime.now();

    _messages = [
      _DemoMessage(
        senderEmail: 'alice@mapapp.com',
        text: 'Hey everyone! Has anyone figured out why the navigation bar disappears on Android after a hot reload?',
        timestamp: now.subtract(const Duration(minutes: 42)),
      ),
      _DemoMessage(
        senderEmail: 'bob@mapapp.com',
        text: "I've seen that too — I think it's a scaffold key issue. Try wrapping your root scaffold in a GlobalKey.",
        timestamp: now.subtract(const Duration(minutes: 40)),
      ),
      _DemoMessage(
        senderEmail: 'alice@mapapp.com',
        text: "Oh nice, I'll try that. Also getting a Firebase auth error when signing in with Google on physical devices. Anyone else?",
        timestamp: now.subtract(const Duration(minutes: 38)),
      ),
      _DemoMessage(
        senderEmail: me,
        text: 'I had that — you need to add your SHA-1 fingerprint to the Firebase console under your Android app settings.',
        timestamp: now.subtract(const Duration(minutes: 35)),
      ),
      _DemoMessage(
        senderEmail: 'carol@mapapp.com',
        text: 'Question: how do you all handle deep linking on iOS? I set up the URL scheme but it never opens the app.',
        timestamp: now.subtract(const Duration(minutes: 30)),
      ),
      _DemoMessage(
        senderEmail: 'dave@mapapp.com',
        text: 'You also need to add the Associated Domains entitlement for Universal Links. Check the Flutter docs on deep linking.',
        timestamp: now.subtract(const Duration(minutes: 28)),
      ),
      _DemoMessage(
        senderEmail: 'bob@mapapp.com',
        text: 'Does anyone know why image_picker crashes on Android API 26? It works fine on newer versions.',
        timestamp: now.subtract(const Duration(minutes: 22)),
      ),
      _DemoMessage(
        senderEmail: me,
        text: "It's a permissions issue — on API < 29 you need WRITE_EXTERNAL_STORAGE. Add it to your AndroidManifest.xml.",
        timestamp: now.subtract(const Duration(minutes: 20)),
      ),
      _DemoMessage(
        senderEmail: 'bob@mapapp.com',
        text: 'That fixed it, thanks! 🙌',
        timestamp: now.subtract(const Duration(minutes: 18)),
      ),
      _DemoMessage(
        senderEmail: 'carol@mapapp.com',
        text: "What state management is everyone using? We're still on setState and it's getting messy.",
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
      _DemoMessage(
        senderEmail: me,
        text: "We switched to Provider recently and it's been really clean. Highly recommend for mid-size apps.",
        timestamp: now.subtract(const Duration(minutes: 10)),
      ),
      _DemoMessage(
        senderEmail: 'alice@mapapp.com',
        text: 'We use Riverpod — works great with Firebase streams. A bit more boilerplate upfront but very scalable.',
        timestamp: now.subtract(const Duration(minutes: 8)),
      ),
      _DemoMessage(
        senderEmail: 'dave@mapapp.com',
        text: 'Can someone review my PR for the profile page? I think I also fixed the text overflow bug in the chat room.',
        timestamp: now.subtract(const Duration(minutes: 3)),
      ),
    ];
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final me = FirebaseAuth.instance.currentUser?.email ?? 'you@example.com';
    setState(() {
      _messages.add(_DemoMessage(
        senderEmail: me,
        text: text,
        timestamp: DateTime.now(),
      ));
    });
    _messageController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.email ?? 'you@example.com';
    const themeColor = Color(0xFF1A237E);
    const onThemeColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: themeColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: onThemeColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.code, color: onThemeColor, size: 18),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'App Development Club',
                    style: TextStyle(color: onThemeColor, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Text(
              '5 members',
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: onThemeColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.senderEmail == me;

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[400],
                          child: Text(
                            msg.senderEmail[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.65,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? themeColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                Text(
                                  msg.senderEmail.split('@')[0],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: isMe ? onThemeColor : Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg.timestamp),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isMe
                                      ? Colors.white60
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[800],
                          child: Text(
                            me[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
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
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
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
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: themeColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

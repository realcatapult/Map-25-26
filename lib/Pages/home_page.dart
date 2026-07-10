import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:login_ui/Pages/chat_list_page.dart';
import 'package:login_ui/Pages/chat_room_page.dart';
import 'package:login_ui/Pages/direct_message_page.dart';
import 'package:login_ui/Pages/settings_page.dart';
import 'package:login_ui/Pages/search_page.dart';
import 'package:login_ui/components/interests_picker_dialog.dart';
import 'package:login_ui/services/chat_service.dart';

class _CalendarEvent {
  final String title;
  final String description;
  final String groupId;
  final String groupName;
  final DateTime date;

  const _CalendarEvent({
    required this.title,
    required this.description,
    required this.groupId,
    required this.groupName,
    required this.date,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ChatService _chatService = ChatService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _selectedIndex = 0;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoadingNotifications = false;

  Map<DateTime, List<_CalendarEvent>> _eventsByDay = {};
  bool _isLoadingEvents = false;
  final Map<String, String> _groupNamesById = {};
  final Set<String> _enabledGroupIds = {};
  Set<String> _lastGroupIds = {};
  bool _handledInterestsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowInterestsOnboarding();
    });
  }

  Future<void> _maybeShowInterestsOnboarding() async {
    if (_handledInterestsOnboarding || !mounted) return;

    _handledInterestsOnboarding = true;

    final shouldShow = await _chatService.shouldShowInterestsOnboarding();
    if (!mounted || !shouldShow) return;

    final existingInterests = await _chatService.getCurrentUserInterests();
    if (!mounted) return;

    final selected = await showInterestsPickerDialog(
      context,
      initialSelection: existingInterests,
      isOnboarding: true,
    );

    if (selected == null || selected.isEmpty) return;

    await _chatService.updateCurrentUserInterests(selected);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preferences saved. Your recommendations are personalized.'),
      ),
    );
  }

  DateTime _normalizeDay(DateTime day) {
    return DateTime.utc(day.year, day.month, day.day);
  }

  List<_CalendarEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = _normalizeDay(day);
    return _eventsByDay[normalizedDay] ?? [];
  }

  void _syncGroups(List<QueryDocumentSnapshot> groupDocs) {
    final groupIds = groupDocs.map((doc) => doc.id).toSet();
    if (setEquals(groupIds, _lastGroupIds)) {
      return;
    }

    _groupNamesById.clear();
    for (final doc in groupDocs) {
      final data = doc.data() as Map<String, dynamic>;
      _groupNamesById[doc.id] = data['name'] ?? 'Group';
    }

    if (_enabledGroupIds.isEmpty) {
      _enabledGroupIds.addAll(groupIds);
    } else {
      _enabledGroupIds.removeWhere((id) => !groupIds.contains(id));
      for (final id in groupIds) {
        _enabledGroupIds.add(id);
      }
    }

    _lastGroupIds = groupIds;
    _loadEventsForGroups(_enabledGroupIds.toList());
    _loadNotifications(groupDocs);
  }

  Future<void> _loadNotifications(List<QueryDocumentSnapshot> groupDocs) async {
    if (_isLoadingNotifications) return;
    setState(() {
      _isLoadingNotifications = true;
    });

    final groups = groupDocs.map<Map<String, String>>((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, 'name': (data['name'] ?? 'Group').toString()};
    }).toList();

    final items = await _chatService.getRecentNotifications(groups);

    const demoNotification = {
      'type': 'group',
      'groupName': 'Community Service Club',
      'senderEmail': 'organizer@demo.com',
      'text': 'Who wants to go to the foodbank tomorrow?',
      'groupId': '',
      'groupName_display': 'Community Service Club',
    };

    if (!mounted) return;
    setState(() {
      _notifications = [demoNotification, ...items];
      _isLoadingNotifications = false;
    });
  }

  String _formatNotificationSubtitle(Map<String, dynamic> item) {
    final sender = (item['senderEmail'] as String?) ?? '';
    if (sender.isEmpty) return '';
    final name = sender.split('@').first;
    return 'From $name';
  }

  String _formatNotificationTitle(Map<String, dynamic> item) {
    final type = item['type'] as String?;
    if (type == 'dm') {
      return item['otherEmail'] as String? ?? 'Direct message';
    }
    return item['groupName'] as String? ?? 'Group';
  }

  String _formatNotificationBody(Map<String, dynamic> item) {
    final text = (item['text'] as String?) ?? '';
    final imageUrl = item['imageUrl'] as String?;
    if (text.isNotEmpty) return text;
    if (imageUrl != null) return 'Sent an image';
    return 'New message';
  }

  void _openNotification(Map<String, dynamic> item) {
    final type = item['type'] as String?;
    if (type == 'dm') {
      final threadId = item['threadId'] as String?;
      final otherEmail = item['otherEmail'] as String?;
      if (threadId == null || otherEmail == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DirectMessagePage(threadId: threadId, otherEmail: otherEmail),
        ),
      );
      return;
    }

    final groupId = item['groupId'] as String?;
    final groupName = item['groupName'] as String?;
    if (groupId == null || groupId.isEmpty || groupName == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatRoomPage(groupId: groupId, groupName: groupName),
      ),
    );
  }

  Future<void> _loadEventsForGroups(List<String> groupIds) async {
    if (_isLoadingEvents) return;
    setState(() {
      _isLoadingEvents = true;
    });

    final Map<DateTime, List<_CalendarEvent>> nextEvents = {};
    for (final groupId in groupIds) {
      final groupName = _groupNamesById[groupId] ?? 'Group';
      final events = await _chatService.getGroupEvents(groupId);

      for (final event in events) {
        final title = event['title'] as String? ?? 'Event';
        final description = event['description'] as String? ?? '';
        final dateValue = event['date'];
        DateTime date;
        if (dateValue is Timestamp) {
          date = dateValue.toDate();
        } else if (dateValue is DateTime) {
          date = dateValue;
        } else {
          continue;
        }

        final normalized = _normalizeDay(date);
        nextEvents.putIfAbsent(normalized, () => []);
        nextEvents[normalized]!.add(
          _CalendarEvent(
            title: title,
            description: description,
            groupId: groupId,
            groupName: groupName,
            date: date,
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _eventsByDay = nextEvents;
      _isLoadingEvents = false;
    });
  }

  void _showCalendarFilterDialog(List<QueryDocumentSnapshot> groupDocs) {
    if (groupDocs.isEmpty) return;

    final groupNames = {
      for (final doc in groupDocs)
        doc.id: (doc.data() as Map<String, dynamic>)['name'] ?? 'Group',
    };

    final selected = <String>{..._enabledGroupIds};
    if (selected.isEmpty) {
      selected.addAll(groupNames.keys);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calendar Filters'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: groupNames.entries.map((entry) {
                final isSelected = selected.contains(entry.key);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selected.add(entry.key);
                      } else {
                        selected.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  selected
                    ..clear()
                    ..addAll(groupNames.keys);
                });
              },
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() {
                  selected.clear();
                });
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _enabledGroupIds
                    ..clear()
                    ..addAll(selected);
                });
                _loadEventsForGroups(_enabledGroupIds.toList());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  final List<Map<String, String>> _announcements = [
    {
      'title': 'Club Elections Tomorrow',
      'time': '2 hours ago',
      'from': 'President',
    },
    {'title': 'Fundraising Event', 'time': '5 hours ago', 'from': 'Secretary'},
    {'title': 'Meeting Friday', 'time': '1 day ago', 'from': 'President'},
  ];

  void _onItemTapped(int index) {
    if (index == 1) {
      // Navigate to Chat page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatListPage()),
      );
      return;
    }
    if (index == 3) {
      // Navigate to Search page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SearchPage()),
      );
      return;
    }
    if (index == 4) {
      // Navigate to Settings page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('GroupApp', style: TextStyle(color: Colors.white)),
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

          final groupDocs = snapshot.data?.docs ?? [];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncGroups(groupDocs);
          });

          final showNotifications = _selectedIndex != 2;

          return SafeArea(
            child: Column(
              children: [
                if (showNotifications)
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_isLoadingNotifications)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _notifications.isEmpty
                                ? Center(
                                    child: Text(
                                      'No new notifications',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _notifications.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 12),
                                    itemBuilder: (context, index) {
                                      final item = _notifications[index];
                                      final subtitle =
                                          _formatNotificationSubtitle(item);
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          _formatNotificationTitle(item),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatNotificationBody(item),
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (subtitle.isNotEmpty)
                                              Text(
                                                subtitle,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        onTap: () => _openNotification(item),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Calendar section
                Expanded(
                  flex: showNotifications ? 4 : 5,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Calendar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.tune),
                                tooltip: 'Calendar settings',
                                onPressed: groupDocs.isEmpty
                                    ? null
                                    : () =>
                                          _showCalendarFilterDialog(groupDocs),
                              ),
                            ],
                          ),
                          if (_isLoadingEvents)
                            const LinearProgressIndicator(minHeight: 2),
                          TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            eventLoader: _getEventsForDay,
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarStyle: CalendarStyle(
                              selectedDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Display events for selected day
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedDay != null
                                      ? 'Events for ${_selectedDay!.month}/${_selectedDay!.day}/${_selectedDay!.year}'
                                      : 'No date selected',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_selectedDay != null &&
                                    _getEventsForDay(_selectedDay!).isNotEmpty)
                                  ..._getEventsForDay(_selectedDay!).map(
                                    (event) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '• ${event.title}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            event.groupName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          if (event.description.isNotEmpty)
                                            Text(
                                              event.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    'No events scheduled',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom half - Announcements
                Expanded(
                  flex: showNotifications ? 3 : 4,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Announcements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _announcements.length,
                            itemBuilder: (context, index) {
                              final announcement = _announcements[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            announcement['title']!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${announcement['from']} • ${announcement['time']}',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

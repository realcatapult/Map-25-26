import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String demoUserEmail = 'demo@groupapp.com';

  // Generate a random 6-character join code
  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Create a new group chat with join code
  Future<String> createGroupChat(
    String groupName,
    List<String> memberEmails,
    bool isPublic,
    String whoCanPost,
    int themeColor,
    String themeIcon,
    List<String>? keywords,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    if (currentUser.email == null) throw Exception('No email for user');

    final joinCode = _generateJoinCode();
    final members = <String>{
      currentUser.email!,
      ...memberEmails.where((email) => email.isNotEmpty),
      demoUserEmail,
    }.toList();

    final groupDoc = await _firestore.collection('groups').add({
      'name': groupName,
      'createdBy': currentUser.email,
      'createdAt': FieldValue.serverTimestamp(),
      'members': members,
      'joinCode': joinCode,
      'isPublic': isPublic,
      'admins': [currentUser.email],
      'whoCanPost': whoCanPost,
      'themeColor': themeColor,
      'themeIcon': themeIcon,
      'keywords': keywords ?? const <String>[],
    });

    return groupDoc.id;
  }

  // Join a group with join code
  Future<void> joinGroupWithCode(String joinCode) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final querySnapshot = await _firestore
        .collection('groups')
        .where('joinCode', isEqualTo: joinCode.toUpperCase())
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Invalid join code');
    }

    final groupDoc = querySnapshot.docs.first;
    final members = List<String>.from(groupDoc.data()['members'] ?? []);

    if (members.contains(currentUser.email)) {
      throw Exception('You are already in this group');
    }

    await _firestore.collection('groups').doc(groupDoc.id).update({
      'members': FieldValue.arrayUnion([currentUser.email]),
    });
  }

  // Get all groups the current user is a member of
  Stream<QuerySnapshot> getUserGroups() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUser.email)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Send a message to a group
  Future<void> sendMessage(
    String groupId,
    String message, {
    String? imageUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final groupData = groupDoc.data();
    if (groupData != null) {
      final whoCanPost = groupData['whoCanPost'] ?? 'all';
      final admins = List<String>.from(groupData['admins'] ?? []);
      final createdBy = groupData['createdBy'] ?? '';
      final isAdmin =
          admins.contains(currentUser.email) ||
          (createdBy == currentUser.email);
      if (whoCanPost == 'admins' && !isAdmin) {
        throw Exception('Only admins can send messages');
      }
    }

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add({
          'text': message,
          'senderEmail': currentUser.email,
          'timestamp': FieldValue.serverTimestamp(),
          if (imageUrl != null) 'imageUrl': imageUrl,
        });
  }

  // Upload image to Firebase Storage and return URL
  Future<String> uploadImage(File imageFile, String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}.jpg';
    final ref = _storage.ref().child('chat_images/$groupId/$fileName');

    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  // Upload profile picture and return URL
  Future<String> uploadProfilePicture(File imageFile) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final fileName = '${currentUser.uid}.jpg';
    final ref = _storage.ref().child('profile_pictures/$fileName');

    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  // Update user profile picture URL
  Future<void> updateProfilePicture(String imageUrl) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    await _firestore.collection('users').doc(currentUser.uid).set({
      'email': currentUser.email,
      'profilePicture': imageUrl,
    }, SetOptions(merge: true));
  }

  // Get user profile picture
  Future<String?> getProfilePicture(String email) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data()['profilePicture'] as String?;
    }
    return null;
  }

  // Get messages for a group
  Stream<QuerySnapshot> getMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get group details
  Future<DocumentSnapshot> getGroup(String groupId) {
    return _firestore.collection('groups').doc(groupId).get();
  }

  // Watch group details
  Stream<DocumentSnapshot> watchGroup(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots();
  }

  // Update group settings
  Future<void> updateGroupSettings(
    String groupId, {
    bool? isPublic,
    String? whoCanPost,
    int? themeColor,
    String? themeIcon,
    String? bannerUrl,
    String? overview,
    List<String>? keywords,
  }) async {
    final updates = <String, dynamic>{};
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (whoCanPost != null) updates['whoCanPost'] = whoCanPost;
    if (themeColor != null) updates['themeColor'] = themeColor;
    if (themeIcon != null) updates['themeIcon'] = themeIcon;
    if (bannerUrl != null) updates['bannerUrl'] = bannerUrl;
    if (overview != null) updates['overview'] = overview;
    if (keywords != null) updates['keywords'] = keywords;

    if (updates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(updates);
    }
  }

  // Upload group banner image and return URL
  Future<String> uploadGroupBanner(File imageFile, String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_banner.jpg';
    final ref = _storage.ref().child('group_banners/$groupId/$fileName');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  // Stream of all public groups for Discover page
  Stream<QuerySnapshot> getPublicGroups() {
    return _firestore
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Join a public group directly by ID (no join code needed)
  Future<void> joinGroupById(String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    final data = groupDoc.data()!;
    if (!(data['isPublic'] as bool? ?? false)) {
      throw Exception('This group is private');
    }

    final members = List<String>.from(data['members'] ?? []);
    if (members.contains(currentUser.email)) {
      throw Exception('You are already in this group');
    }

    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([currentUser.email]),
    });
  }

  // Search public groups by name (client-side filter)
  Future<List<QueryDocumentSnapshot>> searchPublicGroups(String query) async {
    final snapshot = await _firestore
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .get();

    final lowerQuery = query.toLowerCase();
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final overview = (data['overview'] ?? '').toString().toLowerCase();
      final keywords = List<String>.from(data['keywords'] ?? const <String>[])
          .map((value) => value.toLowerCase())
          .toList();
      final keywordMatch = keywords.any((keyword) => keyword.contains(lowerQuery));
      return name.contains(lowerQuery) || overview.contains(lowerQuery) || keywordMatch;
    }).toList();
  }

  // Update group admins
  Future<void> updateGroupAdmins(String groupId, List<String> admins) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': admins,
    });
  }

  String _directMessageId(String emailA, String emailB) {
    final ids = [emailA.toLowerCase(), emailB.toLowerCase()]..sort();
    return '${ids[0]}__${ids[1]}';
  }

  Future<String> getOrCreateDirectMessage(String otherEmail) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    if (currentUser.email == null) throw Exception('No email for user');

    final docId = _directMessageId(currentUser.email!, otherEmail);
    final docRef = _firestore.collection('directMessages').doc(docId);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'participants': [currentUser.email, otherEmail],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return docId;
  }

  Stream<QuerySnapshot> getDirectMessages(String threadId) {
    return _firestore
        .collection('directMessages')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendDirectMessage(String threadId, String message) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    if (currentUser.email == null) throw Exception('No email for user');

    await _firestore
        .collection('directMessages')
        .doc(threadId)
        .collection('messages')
        .add({
          'text': message,
          'senderEmail': currentUser.email,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Stream<QuerySnapshot> getDirectMessageThreads() {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('directMessages')
        .where('participants', arrayContains: currentUser.email)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Leave a group
  Future<void> leaveGroup(String groupId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([currentUser.email]),
    });
  }

  // Get user data (first name, last name)
  Future<Map<String, dynamic>?> getUserData(String email) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    }
    return null;
  }

  // Update user data (first name, last name)
  Future<void> updateUserData(String firstName, String lastName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    await _firestore.collection('users').doc(currentUser.uid).set({
      'email': currentUser.email,
      'firstName': firstName,
      'lastName': lastName,
    }, SetOptions(merge: true));
  }

  Future<List<String>> getCurrentUserInterests() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const [];

    final doc = await _firestore.collection('users').doc(currentUser.uid).get();
    final data = doc.data();
    if (data == null) return const [];

    return List<String>.from(data['interests'] ?? const <String>[]);
  }

  Future<bool> shouldShowInterestsOnboarding() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final doc = await _firestore.collection('users').doc(currentUser.uid).get();
    final data = doc.data();
    if (data == null) return true;

    final seen = data['interestsOnboardingSeen'] as bool? ?? false;
    final interests = List<String>.from(data['interests'] ?? const <String>[]);
    return !seen || interests.isEmpty;
  }

  Future<void> updateCurrentUserInterests(List<String> interests) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    await _firestore.collection('users').doc(currentUser.uid).set({
      'email': currentUser.email,
      'interests': interests,
      'interestsOnboardingSeen': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addGroupEvent(
    String groupId,
    String groupName,
    String title,
    String description,
    DateTime date,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .add({
          'title': title,
          'description': description,
          'date': Timestamp.fromDate(date),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser.email,
          'groupId': groupId,
          'groupName': groupName,
        });
  }

  Future<List<Map<String, dynamic>>> getGroupEvents(String groupId) async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<Map<String, dynamic>?> _latestGroupMessage(
    String groupId,
    String groupName,
  ) async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return {
      'type': 'group',
      'groupId': groupId,
      'groupName': groupName,
      'text': data['text'] ?? '',
      'imageUrl': data['imageUrl'],
      'senderEmail': data['senderEmail'] ?? '',
      'timestamp': data['timestamp'],
    };
  }

  Future<Map<String, dynamic>?> _latestDirectMessage(
    String threadId,
    String otherEmail,
  ) async {
    final snapshot = await _firestore
        .collection('directMessages')
        .doc(threadId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return {
      'type': 'dm',
      'threadId': threadId,
      'otherEmail': otherEmail,
      'text': data['text'] ?? '',
      'imageUrl': data['imageUrl'],
      'senderEmail': data['senderEmail'] ?? '',
      'timestamp': data['timestamp'],
    };
  }

  Future<List<Map<String, dynamic>>> getRecentNotifications(
    List<Map<String, String>> groups,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      return [];
    }

    final List<Map<String, dynamic>> items = [];

    for (final group in groups) {
      final groupId = group['id'] ?? '';
      if (groupId.isEmpty) continue;
      final groupName = group['name'] ?? 'Group';
      final latest = await _latestGroupMessage(groupId, groupName);
      if (latest != null) {
        items.add(latest);
      }
    }

    final threadSnapshot = await _firestore
        .collection('directMessages')
        .where('participants', arrayContains: currentUser.email)
        .orderBy('createdAt', descending: true)
        .get();

    for (final doc in threadSnapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final otherEmail = participants.firstWhere(
        (email) => email != currentUser.email,
        orElse: () => 'Unknown',
      );
      final latest = await _latestDirectMessage(doc.id, otherEmail);
      if (latest != null) {
        items.add(latest);
      }
    }

    items.sort((a, b) {
      final aTime = a['timestamp'] as Timestamp?;
      final bTime = b['timestamp'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return items;
  }
}

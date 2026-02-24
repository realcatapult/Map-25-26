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
  }) async {
    final updates = <String, dynamic>{};
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (whoCanPost != null) updates['whoCanPost'] = whoCanPost;
    if (themeColor != null) updates['themeColor'] = themeColor;
    if (themeIcon != null) updates['themeIcon'] = themeIcon;

    if (updates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(updates);
    }
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
}

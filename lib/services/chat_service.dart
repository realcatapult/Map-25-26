import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math';
import 'dart:io';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final joinCode = _generateJoinCode();

    final groupDoc = await _firestore.collection('groups').add({
      'name': groupName,
      'createdBy': currentUser.email,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [currentUser.email, ...memberEmails],
      'joinCode': joinCode,
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

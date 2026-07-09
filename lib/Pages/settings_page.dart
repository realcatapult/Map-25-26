import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_ui/services/chat_service.dart';
import 'package:login_ui/services/auth_service.dart';
import 'package:login_ui/services/theme_service.dart';
import 'package:login_ui/Pages/support_chat_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  String? _profilePictureUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final profilePic = await _chatService.getProfilePicture(
        currentUser.email!,
      );
      final userData = await _chatService.getUserData(currentUser.email!);

      setState(() {
        _profilePictureUrl = profilePic;
        _firstNameController.text = userData?['firstName'] ?? '';
        _lastNameController.text = userData?['lastName'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadProfilePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isSaving = true;
      });

      final imageUrl = await _chatService.uploadProfilePicture(
        File(image.path),
      );
      await _chatService.updateProfilePicture(imageUrl);

      setState(() {
        _profilePictureUrl = imageUrl;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    }
  }

  Future<void> _saveUserData() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both first and last name')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _chatService.updateUserData(
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
      );

      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Picture Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isSaving
                              ? null
                              : _pickAndUploadProfilePicture,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[400],
                                backgroundImage: _profilePictureUrl != null
                                    ? NetworkImage(_profilePictureUrl!)
                                    : null,
                                child: _profilePictureUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[700],
                                      )
                                    : null,
                              ),
                              if (_isSaving)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap to change profile picture',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Display Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Display',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Dark Mode'),
                          value: ThemeService.isDark,
                          onChanged: (value) {
                            ThemeService.setThemeMode(
                              value ? ThemeMode.dark : ThemeMode.light,
                            );
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('Help & Support'),
                          subtitle: const Text('Ask the AI assistant'),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SupportChatPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // User Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email (read-only)
                        TextField(
                          enabled: false,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: currentUser?.email ?? '',
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // First Name
                        TextField(
                          controller: _firstNameController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            hintText: 'Enter your first name',
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),

                        // Last Name
                        TextField(
                          controller: _lastNameController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            hintText: 'Enter your last name',
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveUserData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _authService.signOut(),
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}

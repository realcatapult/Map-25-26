import 'package:flutter/material.dart';
import 'package:login_ui/components/my_textfield.dart';
import 'package:login_ui/components/my_button.dart';
import 'package:login_ui/components/square_tile.dart';
import 'package:login_ui/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? showRegisterPage;

  const LoginPage({super.key, this.showRegisterPage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // text editing controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  // sign user in method
  void signUserIn() async {
    try {
      await _authService.signInWithEmailPassword(
        emailController.text.trim(),
        passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 50),

                // App name
                const Text(
                  'GroupApp',
                  style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold),
                ),

                // logo
                // const Icon(
                // Icons.lock,
                // size: 45,
                // ),
                const SizedBox(height: 50),

                // welcome back
                Text(
                  'Welcome back!',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
                const SizedBox(height: 10),

                // Email
                MyTextField(
                  controller: emailController,
                  hintText: 'Email',
                  obscureText: false,
                ),
                const SizedBox(height: 16),

                // Password
                MyTextField(
                  controller: passwordController,
                  hintText: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 10),

                // Forgot password
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Sign in button
                MyButton(onTap: signUserIn),
                const SizedBox(height: 40),

                // Divider with text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(thickness: 0.5, color: Colors.grey[400]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          'Or continue with',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      Expanded(
                        child: Divider(thickness: 0.5, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // social buttons placeholder with labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google button + label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SquareTile(imagePath: 'lib/images/google.png'),
                        const SizedBox(height: 8),
                        const Text(
                          'Google',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(width: 25),

                    // Apple button + label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SquareTile(imagePath: 'lib/images/apple.png'),
                        const SizedBox(height: 8),
                        const Text(
                          'Apple',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 50),

                //not a member register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Not a member?',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: widget.showRegisterPage,
                      child: const Text(
                        'Register now',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

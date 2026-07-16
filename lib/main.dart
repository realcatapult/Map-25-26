import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'Pages/admin_dashboard_page.dart';
import 'Pages/auth_page.dart';
import 'Pages/home_page.dart';
import 'services/chat_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _postAuthLanding() {
    final chatService = ChatService();
    return FutureBuilder<bool>(
      future: chatService.isCurrentUserSchoolAdmin(),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: NeonBackground(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (adminSnapshot.data == true) {
          return AdminDashboardPage();
        }

        return const HomePage();
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const primaryColor = AppColors.primary;
    const secondaryColor = AppColors.secondary;

    final baseTextColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedTextColor =
        isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: baseTextColor, displayColor: baseTextColor);

    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final surfaceHigh = isDark ? AppColors.surfaceHigh : Colors.white;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      textTheme: poppinsTextTheme,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: brightness,
          ).copyWith(
            primary: primaryColor,
            secondary: secondaryColor,
            surface: surface,
            surfaceContainerLow: isDark ? AppColors.surface : const Color(0xFFF1F5FB),
            surfaceContainerHigh: surfaceHigh,
            surfaceContainerHighest: surfaceHigh,
            onSurface: baseTextColor,
            onSurfaceVariant: mutedTextColor,
            onPrimary: Colors.white,
          ),
      scaffoldBackgroundColor: isDark ? AppColors.bg : AppColors.bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardColor: surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        hintStyle: TextStyle(color: mutedTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : primaryColor.withValues(alpha: 0.20),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
      ),
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.idTokenChanges(),
            builder: (context, snapshot) {
              // Show loading spinner while checking auth state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: NeonBackground(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              // If user is logged in, show HomePage
              if (snapshot.hasData) {
                return _postAuthLanding();
              }

              // If user is not logged in, show AuthPage
              return const AuthPage();
            },
          ),
        );
      },
    );
  }
}

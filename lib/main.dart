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
import 'components/unity_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            surfaceContainerLow: isDark ? AppColors.surface : const Color(0xFFF0EBDF),
            surfaceContainerHigh: surfaceHigh,
            surfaceContainerHighest: surfaceHigh,
            onSurface: baseTextColor,
            onSurfaceVariant: mutedTextColor,
            onPrimary: AppColors.navy,
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
          foregroundColor: AppColors.navy,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
          home: const _AuthGate(),
        );
      },
    );
  }
}

/// Watches auth state, shows the Unity loading screen while resolving, and
/// plays the split-apart reveal exactly once when the user logs in.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final ChatService _chatService = ChatService();

  // True until the reveal animation has played for the current session, so we
  // only split-reveal on an actual login transition (not on every rebuild).
  bool _revealPending = false;
  bool _wasLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const UnityLoadingScreen();
        }

        final loggedIn = snapshot.hasData;

        // Detect the logged-out -> logged-in transition to arm the reveal.
        if (loggedIn && !_wasLoggedIn) {
          _revealPending = true;
        }
        _wasLoggedIn = loggedIn;

        if (!loggedIn) {
          return const AuthPage();
        }

        final landing = _postAuthLanding();

        if (_revealPending) {
          _revealPending = false;
          return UnityRevealOverlay(child: landing);
        }
        return landing;
      },
    );
  }

  Widget _postAuthLanding() {
    return FutureBuilder<bool>(
      future: _chatService.isCurrentUserSchoolAdmin(),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const UnityLoadingScreen();
        }
        if (adminSnapshot.data == true) {
          return AdminDashboardPage();
        }
        return const HomePage();
      },
    );
  }
}

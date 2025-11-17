import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/conversations_screen.dart';
import 'screens/phone_signup_screen.dart';
import 'services/auth_service.dart';
import 'services/topic_detection_service.dart';
import 'config/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize AI topic detection service
  TopicDetectionService().initialize();
  
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TABS Chat',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AuthWrapper(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        background: AppColors.background,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'SF Pro Display', // Will fallback to system font
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.1,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: Colors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.75,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final authService = AuthService();
      
      return StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          // Handle errors in stream
          if (snapshot.hasError) {
            print('Auth stream error: ${snapshot.error}');
            return const PhoneSignupScreen();
          }
          
          // Show loading while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          }
          
          // If user is signed in, show main app
          if (snapshot.hasData && snapshot.data != null) {
            return const ConversationsScreen();
          }
          
          // If user is not signed in, show signup screen
          return const PhoneSignupScreen();
        },
      );
    } catch (e) {
      print('AuthWrapper error: $e');
      // Fallback to signup screen if there's any error
      return const PhoneSignupScreen();
    }
  }
}

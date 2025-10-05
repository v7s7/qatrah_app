import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // <-- dev flag
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ProviderScope
import 'core/theme/theme_v2.dart';
import 'core/services/db_bootstrap.dart'; // desktop sqflite FFI bootstrap
import 'core/services/db/app_database.dart'; // DB reset helpers

// Auth screens
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/intro_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';

// Bottom nav + tabs
import 'features/shell/widgets/bottom_nav_shell.dart';
import 'features/home/screens/home_dashboard.dart';
import 'features/usage/screens/usage_history_screen.dart';
import 'features/achievements/screens/achievements_screen.dart';
import 'features/profile/screens/account_info_screen.dart';
import 'features/home/screens/monthly_report_screen.dart';
import 'features/profile/screens/edit_info_screen.dart';
import 'features/profile/screens/change_password_screen.dart';

// Usage detail
import 'features/usage/screens/washing_detail_screen.dart';

// Dev: Serial log replay
import 'features/dev/screens/log_replay_screen.dart'; // <-- added

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapDatabaseForDesktop(); // Windows/Linux sqflite_ffi init (no-op on mobile)

  // ========================= DEV-ONLY RESET =========================
  if (kDebugMode) {
    // ⚠️ This deletes the entire database file, then it will be recreated
    // on next access (schema + seeded profile row).
    // COMMENT OUT AFTER YOU RUN ONCE.
    // await AppDatabase.reset();

    // If you prefer to keep profile/settings and only clear usage rows:
    // await AppDatabase.clearUsageOnly();
  }
  // =================================================================

  runApp(const ProviderScope(child: QatrahApp())); // Riverpod root
}

class QatrahApp extends StatelessWidget {
  const QatrahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qatrah',
      debugShowCheckedModeBanner: false,
      theme: AppThemeV2.dark,
      initialRoute: '/splash',
      routes: {
        // Auth
        '/splash': (context) => const SplashScreen(),
        '/intro': (context) => const IntroScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot': (context) => const ForgotPasswordScreen(),

        // Profile
        '/profile/edit': (context) => const EditInfoScreen(),
        '/profile/password': (context) => const ChangePasswordScreen(),

        // Reports
        '/report': (context) => const MonthlyReportScreen(),

        // App shell with tabs
        '/home': (context) => BottomNavShell(
          pages: const [
            HomeDashboard(),
            UsageHistoryScreen(),
            AchievementsScreen(),
            AccountInfoScreen(),
          ],
        ),

        // Detail screens
        '/usage/detail': (context) => const WashingDetailScreen(),

        // Dev: Serial log replay screen
        '/dev/replay': (context) => const LogReplayScreen(), // <-- added
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/interceptors/auth_interceptor.dart';
import 'core/interceptors/logging_interceptor.dart';
import 'core/interceptors/token_refresh_interceptor.dart';
import 'core/retry/retry_interceptor.dart';
import 'core/retry/retry_policy.dart';
import 'core/services/admin_dashboard_service.dart';
import 'core/services/admin_student_service.dart';
import 'core/services/api_client.dart';
import 'core/services/auth_service.dart';
import 'core/services/internship_service.dart';
import 'core/services/logbook_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/student_report_service.dart';
import 'core/services/token_service.dart';
import 'features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'features/admin/presentation/screens/student_adviser_assignment_screen.dart';
import 'features/admin/presentation/providers/adviser_management_provider.dart';
import 'features/adviser/presentation/screens/adviser_dashboard_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/auth_gate_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/internship/presentation/screens/internship_profile_screen.dart';
import 'features/logbook/presentation/screens/logbook_screen.dart';
import 'features/student/presentation/screens/student_dashboard_screen.dart';
import 'features/student/presentation/screens/student_dtr_screen.dart';
import 'features/student/presentation/screens/student_report_screen.dart';
import 'features/supervisor/presentation/screens/supervisor_dashboard_screen.dart';

void main() {
  runApp(const InternTrackApp());
}

class InternTrackApp extends StatelessWidget {
  const InternTrackApp({super.key});

  Widget _dashboardFor(AuthProvider authProvider) {
    final userName = authProvider.user?.name.isNotEmpty == true
        ? authProvider.user!.name
        : 'User';

    switch (authProvider.role.toLowerCase()) {
      case 'admin':
        return AdminDashboardScreen(userName: userName);
      case 'supervisor':
        return SupervisorDashboardScreen(userName: userName);
      case 'adviser':
        return AdviserDashboardScreen(userName: userName);
      case 'student':
      default:
        return StudentDashboardScreen(
          userName: userName,
          companyName: null,
          requiredHours: null,
        );
    }
  }

  Widget _guardGuestRoute(AuthProvider authProvider, Widget child) {
    if (authProvider.isAuthenticated) {
      return _dashboardFor(authProvider);
    }
    return child;
  }

  Widget _guardProtectedRoute(AuthProvider authProvider, Widget child) {
    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }
    return child;
  }

  Widget _guardRoleRoute(
    AuthProvider authProvider,
    String allowedRole,
    Widget child,
  ) {
    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    if (authProvider.role.toLowerCase() != allowedRole.toLowerCase()) {
      return _dashboardFor(authProvider);
    }

    return child;
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF0F4C5C);
    const brandBlue = Color(0xFF326DE6);
    const appBackground = Color(0xFFF6F7FB);
    const textPrimary = Color(0xFF102A56);
    const textSecondary = Color(0xFF4A6480);
    const borderColor = Color(0xFFD8E2EC);
    final textTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return MultiProvider(
      providers: [
        Provider<TokenService>(create: (_) => const TokenService()),
        Provider<ApiClient>(create: (context) {
          final apiClient = ApiClient();
          final tokenService = context.read<TokenService>();

          // Register interceptors in order
          // Request flow: Auth → Logging → Retry → (request)
          // Error flow: TokenRefresh → Retry → Logging → Auth
          apiClient.addInterceptor(AuthInterceptor(tokenService));
          apiClient.addInterceptor(LoggingInterceptor());
          apiClient.addInterceptor(RetryInterceptor(apiClient.client, RetryPolicies.standard));

          return apiClient;
        }),
        ProxyProvider<ApiClient, AuthService>(
          update: (context, apiClient, previous) => AuthService(apiClient),
        ),
        ProxyProvider<ApiClient, AdminStudentService>(
          update: (context, apiClient, previous) => AdminStudentService(apiClient),
        ),
        ProxyProvider<ApiClient, AdminDashboardService>(
          update: (context, apiClient, previous) =>
              AdminDashboardService(apiClient),
        ),
        ProxyProvider<ApiClient, InternshipService>(
          update: (context, apiClient, previous) => InternshipService(apiClient),
        ),
        ProxyProvider<ApiClient, LogbookService>(
          update: (context, apiClient, previous) => LogbookService(apiClient),
        ),
        ProxyProvider<ApiClient, NotificationService>(
          update: (context, apiClient, previous) => NotificationService(apiClient),
        ),
        ProxyProvider<ApiClient, StudentReportService>(
          update: (context, apiClient, previous) => StudentReportService(apiClient),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final apiClient = context.read<ApiClient>();
            final tokenService = context.read<TokenService>();
            final authService = context.read<AuthService>();
            final authProvider = AuthProvider(
              tokenService,
              authService: authService,
            );

            // Register token refresh interceptor after AuthProvider is available
            apiClient.addInterceptor(TokenRefreshInterceptor(authProvider));

            return authProvider..initialize();
          },
        ),
        ChangeNotifierProvider(
          create: (context) => AdviserManagementProvider(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'InternTrack',
            debugShowCheckedModeBanner: false,
            initialRoute: AppRoutes.authGate,
            routes: {
              AppRoutes.authGate: (_) => const AuthGateScreen(),

              AppRoutes.home: (_) => const AuthGateScreen(),

              AppRoutes.login: (_) =>
                  _guardGuestRoute(authProvider, const LoginScreen()),

              AppRoutes.register: (_) =>
                  _guardGuestRoute(authProvider, const RegisterScreen()),

              AppRoutes.dashboard: (_) {
                return _guardProtectedRoute(
                  authProvider,
                  _dashboardFor(authProvider),
                );
              },

              AppRoutes.studentDashboard: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  StudentDashboardScreen(
                    userName: authProvider.user?.name ?? 'Student',
                    companyName: null,
                    requiredHours: null,
                  ),
                );
              },

              AppRoutes.adminDashboard: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'admin',
                  AdminDashboardScreen(
                    userName: authProvider.user?.name ?? 'Admin',
                  ),
                );
              },

              AppRoutes.supervisorDashboard: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'supervisor',
                  SupervisorDashboardScreen(
                    userName: authProvider.user?.name ?? 'Supervisor',
                  ),
                );
              },

              AppRoutes.adviserDashboard: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'adviser',
                  AdviserDashboardScreen(
                    userName: authProvider.user?.name ?? 'Adviser',
                  ),
                );
              },

              AppRoutes.internshipProfile: (_) {
                final token = authProvider.token ?? '';
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  InternshipProfileScreen(token: token),
                );
              },

              AppRoutes.logbook: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  const LogbookScreen(),
                );
              },

              AppRoutes.studentDtr: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  const StudentDtrScreen(),
                );
              },

              AppRoutes.studentReport: (_) {
                final token = authProvider.token ?? '';
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  StudentReportScreen(token: token),
                );
              },

              AppRoutes.studentAdviserAssignment: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'admin',
                  const StudentAdviserAssignmentScreen(),
                );
              },
            },
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: brandColor,
                surface: appBackground,
                primary: brandColor,
                secondary: brandBlue,
                error: const Color(0xFFB42318),
              ),
              scaffoldBackgroundColor: appBackground,
              textTheme: textTheme.copyWith(
                headlineLarge: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
                headlineMedium: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                headlineSmall: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
                titleLarge: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                titleMedium: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                bodyLarge: textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  color: textSecondary,
                ),
                bodyMedium: textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: textSecondary,
                ),
                labelLarge: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              useMaterial3: true,
              visualDensity: VisualDensity.standard,
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: textPrimary,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: false,
                titleTextStyle: textTheme.titleLarge?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                iconTheme: const IconThemeData(color: textPrimary),
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.white,
                elevation: 1.5,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE6EAF0)),
                ),
              ),
              dividerTheme: const DividerThemeData(
                color: Color(0xFFE7EBF0),
                thickness: 1,
                space: 1,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 16,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF8A98A8),
                  fontWeight: FontWeight.w500,
                ),
                labelStyle: const TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: const TextStyle(
                  color: brandColor,
                  fontWeight: FontWeight.w700,
                ),
                helperStyle: const TextStyle(
                  color: Color(0xFF667085),
                  height: 1.35,
                ),
                errorStyle: const TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                prefixIconColor: const Color(0xFF57707A),
                suffixIconColor: const Color(0xFF57707A),
                errorMaxLines: 3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: brandColor, width: 1.6),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF04438)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFB42318),
                    width: 1.6,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF7FAAB5),
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size(44, 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1.5,
                  shadowColor: const Color(0x330F4C5C),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandColor,
                  minimumSize: const Size(44, 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 18,
                  ),
                  side: const BorderSide(color: Color(0xFFB8CAD3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: brandColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: textPrimary,
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: textPrimary,
                contentTextStyle: textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              progressIndicatorTheme: const ProgressIndicatorThemeData(
                color: brandColor,
                linearTrackColor: Color(0xFFDDE2EA),
              ),
              tooltipTheme: TooltipThemeData(
                waitDuration: const Duration(milliseconds: 450),
                decoration: BoxDecoration(
                  color: textPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_routes.dart';
import 'core/interceptors/auth_interceptor.dart';
import 'core/interceptors/logging_interceptor.dart';
import 'core/interceptors/token_refresh_interceptor.dart';
import 'core/retry/retry_interceptor.dart';
import 'core/retry/retry_policy.dart';
import 'core/services/admin_dashboard_service.dart';
import 'core/services/admin_student_service.dart';
import 'core/services/adviser_management_service.dart';
import 'core/services/api_client.dart';
import 'core/services/auth_service.dart';
import 'core/services/internship_service.dart';
import 'core/services/logbook_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/student_report_service.dart';
import 'core/services/token_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
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
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/student/navigation/student_notification_routing.dart';
import 'features/student/presentation/screens/student_dashboard_screen.dart';
import 'features/student/presentation/screens/student_dtr_screen.dart';
import 'features/student/presentation/screens/student_report_screen.dart';
import 'features/supervisor/presentation/screens/supervisor_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.create();
  runApp(InternTrackApp(themeController: themeController));
}

class InternTrackApp extends StatelessWidget {
  const InternTrackApp({super.key, required this.themeController});

  final ThemeController themeController;

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        Provider<TokenService>(create: (_) => const TokenService()),
        Provider<ApiClient>(
          create: (context) {
            final apiClient = ApiClient();
            final tokenService = context.read<TokenService>();

            // Register interceptors in order
            // Request flow: Auth → Logging → Retry → (request)
            // Error flow: TokenRefresh → Retry → Logging → Auth
            apiClient.addInterceptor(AuthInterceptor(tokenService));
            apiClient.addInterceptor(LoggingInterceptor());
            apiClient.addInterceptor(
              RetryInterceptor(apiClient.client, RetryPolicies.standard),
            );

            return apiClient;
          },
        ),
        ProxyProvider<ApiClient, AuthService>(
          update: (context, apiClient, previous) => AuthService(apiClient),
        ),
        ProxyProvider<ApiClient, AdminStudentService>(
          update: (context, apiClient, previous) =>
              AdminStudentService(apiClient),
        ),
        ProxyProvider<ApiClient, AdminDashboardService>(
          update: (context, apiClient, previous) =>
              AdminDashboardService(apiClient),
        ),
        ProxyProvider<ApiClient, AdviserManagementService>(
          update: (context, apiClient, previous) =>
              AdviserManagementService(apiClient),
        ),
        ProxyProvider<ApiClient, InternshipService>(
          update: (context, apiClient, previous) =>
              InternshipService(apiClient),
        ),
        ProxyProvider<ApiClient, LogbookService>(
          update: (context, apiClient, previous) => LogbookService(apiClient),
        ),
        ProxyProvider<ApiClient, NotificationService>(
          update: (context, apiClient, previous) =>
              NotificationService(apiClient),
        ),
        ProxyProvider<ApiClient, StudentReportService>(
          update: (context, apiClient, previous) =>
              StudentReportService(apiClient),
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
        ChangeNotifierProxyProvider<
          AdviserManagementService,
          AdviserManagementProvider
        >(
          create: (context) => AdviserManagementProvider(
            service: context.read<AdviserManagementService>(),
          ),
          update: (context, adviserService, provider) {
            final notifier =
                provider ?? AdviserManagementProvider(service: adviserService);
            notifier.updateService(adviserService);
            return notifier;
          },
        ),
      ],
      child: Consumer2<AuthProvider, ThemeController>(
        builder: (context, authProvider, themeController, _) {
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
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  const InternshipProfileScreen(),
                );
              },

              AppRoutes.logbook: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  Builder(
                    builder: (context) {
                      final raw =
                          ModalRoute.of(context)?.settings.arguments;
                      final int? focusId =
                          raw is LogbookNavArgs ? raw.logId : null;
                      return LogbookScreen(initialFocusLogId: focusId);
                    },
                  ),
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
                return _guardRoleRoute(
                  authProvider,
                  'student',
                  const StudentReportScreen(),
                );
              },

              AppRoutes.studentAdviserAssignment: (_) {
                return _guardRoleRoute(
                  authProvider,
                  'admin',
                  const StudentAdviserAssignmentScreen(),
                );
              },

              AppRoutes.settings: (_) {
                return _guardProtectedRoute(
                  authProvider,
                  const SettingsScreen(),
                );
              },
            },
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeController.themeMode,
          );
        },
      ),
    );
  }
}

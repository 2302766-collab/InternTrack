import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
<<<<<<< MMP-103
import '../../../../core/config/api_config.dart';
=======
>>>>>>> main
import '../../../../core/services/auth_service.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/auth_shell.dart';
import '../../../../shared/widgets/form_error_banner.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthService _authService;

  bool _isLoading = false;
  String? _generalError;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    return email.isNotEmpty &&
        emailRegex.hasMatch(email) &&
        password.isNotEmpty &&
        password.length >= 8;
  }

  Future<void> _login() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    _log('Starting login for $email via ${ApiConfig.baseUrl}');

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final result = await _authService.login(
        email: email,
        password: _passwordController.text,
      );
      _log('Login API call succeeded');

      final token = result['token'] as String;
      AppUser? user;
      final rawUser = result['user'];
      if (rawUser is Map<String, dynamic>) {
        user = AppUser.fromJson(rawUser);
      }
      _log(
        'Parsed login response tokenLength=${token.length} role=${user?.role ?? 'missing'}',
      );

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      _log('Persisting login session');
      await authProvider.setToken(token, user: user);

      if (!mounted) return;

      final nextRoute = authProvider.dashboardRoute;
      _log('Navigating to $nextRoute');
      Navigator.pushNamedAndRemoveUntil(
        context,
        nextRoute,
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _generalError = e.message;
      });
    } catch (e) {
      _log('Login failed: $e');
      if (!mounted) return;

      setState(() {
        _generalError = _formatLoginError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _log('Login flow finished');
    }
  }

  void _log(String message) {
    debugPrint('[LoginScreen] $message');
  }

  String _formatLoginError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIcon: label == 'Email'
          ? const Icon(Icons.mail_outline)
          : const Icon(Icons.lock_outline),
      suffixIcon: label == 'Password'
          ? IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() {
                _obscurePassword = !_obscurePassword;
              }),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to track your internship progress.',
      onBack: null,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          const Text(
            "Don't have an account?",
            style: TextStyle(color: Color(0xFF365A63)),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pushNamed(context, AppRoutes.register);
                  },
            child: const Text('Create one'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () {
          setState(() {});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              enabled: !_isLoading,
              decoration: _inputDecoration('Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim() ?? '';
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

                if (text.isEmpty) {
                  return 'Email is required';
                }

                if (!emailRegex.hasMatch(text)) {
                  return 'Enter a valid email address';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              decoration: _inputDecoration('Password'),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_isFormValid && !_isLoading) {
                  _login();
                }
              },
              validator: (value) {
                final text = value ?? '';

                if (text.isEmpty) {
                  return 'Password is required';
                }

                if (text.length < 8) {
                  return 'Password must be at least 8 characters';
                }

                return null;
              },
            ),
            if (_generalError != null) ...[
              const SizedBox(height: 12),
              FormErrorBanner(message: _generalError!),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (!_isFormValid || _isLoading) ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
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
  static const _fieldFill = Color(0xFF223652);
  static const _fieldBorder = Color(0x334EC9FF);
  static const _mutedText = Color(0xFFA9B7C8);
  static const _brightText = Color(0xFFF2F7FF);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthService _authService;

  bool _isLoading = false;
  String? _generalError;
  bool _obscurePassword = true;

  String _messageForLoginError(Object error) {
    if (error is ApiException) {
      switch (error.errorType) {
        case ApiErrorType.networkError:
        case ApiErrorType.timeout:
          return 'Unable to reach the login server at ${ApiConfig.baseUrl}. '
              'Make sure the Laravel API is running, then try again.';
        default:
          return error.message;
      }
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

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
      Navigator.pushNamedAndRemoveUntil(context, nextRoute, (route) => false);
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _generalError = _messageForLoginError(e);
      });
    } catch (e) {
      _log('Login failed: $e');
      if (!mounted) return;

      setState(() {
        _generalError = _messageForLoginError(e);
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

  InputDecoration _inputDecoration(String label) {
    final isPassword = label == 'Password';

    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: label == 'Email' ? 'Enter your email' : 'Enter your password',
      filled: true,
      fillColor: _fieldFill.withAlpha(235),
      labelStyle: const TextStyle(
        color: _mutedText,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF6E8199),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: label == 'Email'
          ? const Icon(Icons.alternate_email_rounded, color: _mutedText)
          : const Icon(Icons.lock_outline_rounded, color: _mutedText),
      suffixIcon: isPassword
          ? IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: _mutedText,
              ),
              onPressed: () => setState(() {
                _obscurePassword = !_obscurePassword;
              }),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFF6ED6FF), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFFF8A9B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFFFAAB6), width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0x223C7CA3)),
      ),
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
            style: TextStyle(color: _mutedText),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pushNamed(context, AppRoutes.register);
                  },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF75D8FF),
            ),
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
              style: const TextStyle(
                color: _brightText,
                fontWeight: FontWeight.w600,
              ),
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
            const SizedBox(height: 18),
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              decoration: _inputDecoration('Password'),
              obscureText: _obscurePassword,
              style: const TextStyle(
                color: _brightText,
                fontWeight: FontWeight.w600,
              ),
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
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6DE2FF), Color(0xFF42B9FF)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x553CB9FF),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: (!_isFormValid || _isLoading) ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0E2036),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Login',
                              style: TextStyle(
                                color: Color(0xFF0D1A2D),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF0D1A2D),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

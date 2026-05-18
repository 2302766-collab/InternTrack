import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/widgets/auth_shell.dart';
import '../../../../shared/widgets/form_error_banner.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _fieldFill = Color(0xFF223652);
  static const _fieldBorder = Color(0x334EC9FF);
  static const _mutedText = Color(0xFFA9B7C8);
  static const _brightText = Color(0xFFF2F7FF);
  static const _hintText = Color(0xFFD2DEEC);

  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthService _authService;

  bool _isLoading = false;
  String? _generalError;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedGender = 'Male';

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    return firstName.isNotEmpty &&
        firstName.length >= 2 &&
        lastName.isNotEmpty &&
        lastName.length >= 2 &&
        email.isNotEmpty &&
        emailRegex.hasMatch(email) &&
        password.isNotEmpty &&
        password.length >= 8 &&
        confirmPassword.isNotEmpty &&
        password == confirmPassword;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      await _authService.register(
        name: '$firstName $lastName',
        email: _emailController.text.trim(),
        gender: _selectedGender,
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful. Please log in.'),
        ),
      );

      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _generalError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    IconData? prefix;
    switch (label) {
      case 'First Name':
      case 'Last Name':
        prefix = Icons.person_outline;
        break;
      case 'Email':
        prefix = Icons.mail_outline;
        break;
      case 'Password':
      case 'Confirm Password':
        prefix = Icons.lock_outline;
        break;
      case 'Gender':
        prefix = Icons.person_rounded;
        break;
    }

    final isPassword = label == 'Password';
    final isConfirm = label == 'Confirm Password';

    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: switch (label) {
        'First Name' => 'Enter your first name',
        'Last Name' => 'Enter your last name',
        'Email' => 'Enter your email',
        'Password' => 'Create a password',
        'Confirm Password' => 'Re-enter your password',
        'Gender' => 'Select gender',
        _ => label,
      },
      filled: true,
      fillColor: _fieldFill.withAlpha(235),
      labelStyle: const TextStyle(
        color: Color(0xFF89CFF2),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF89CFF2),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(color: _hintText, fontWeight: FontWeight.w600),
      prefixIcon: prefix != null ? Icon(prefix, color: _mutedText) : null,
      suffixIcon: (isPassword || isConfirm)
          ? IconButton(
              tooltip: (isPassword ? _obscurePassword : _obscureConfirm)
                  ? 'Show password'
                  : 'Hide password',
              icon: Icon(
                (isPassword ? _obscurePassword : _obscureConfirm)
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: _mutedText,
              ),
              onPressed: () => setState(() {
                if (isPassword) {
                  _obscurePassword = !_obscurePassword;
                } else {
                  _obscureConfirm = !_obscureConfirm;
                }
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
      title: 'Create your account',
      subtitle:
          'Join InternTrack to log hours and collaborate with your supervisor.',
      onBack: () {
        Navigator.pop(context);
      },
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          const Text(
            'Already have an account?',
            style: TextStyle(color: _mutedText),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF75D8FF),
            ),
            child: const Text('Log in'),
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
              controller: _firstNameController,
              enabled: !_isLoading,
              decoration: _inputDecoration('First Name'),
              cursorColor: const Color(0xFF75D8FF),
              style: const TextStyle(
                color: _brightText,
                fontWeight: FontWeight.w600,
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'First name is required';
                }

                if (text.length < 2) {
                  return 'Enter a valid first name';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastNameController,
              enabled: !_isLoading,
              decoration: _inputDecoration('Last Name'),
              cursorColor: const Color(0xFF75D8FF),
              style: const TextStyle(
                color: _brightText,
                fontWeight: FontWeight.w600,
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return 'Last name is required';
                }

                if (text.length < 2) {
                  return 'Enter a valid last name';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: _inputDecoration('Gender'),
              dropdownColor: const Color(0xFF223652),
              style: const TextStyle(
                color: _brightText,
                fontWeight: FontWeight.w600,
              ),
              iconEnabledColor: _mutedText,
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _selectedGender = value;
                      });
                    },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              enabled: !_isLoading,
              decoration: _inputDecoration('Email'),
              keyboardType: TextInputType.emailAddress,
              cursorColor: const Color(0xFF75D8FF),
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
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              decoration: _inputDecoration('Password'),
              obscureText: _obscurePassword,
              cursorColor: const Color(0xFF75D8FF),
              style: const TextStyle(
                color: _brightText,
                fontWeight: FontWeight.w600,
              ),
              textInputAction: TextInputAction.next,
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
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              enabled: !_isLoading,
              decoration: _inputDecoration('Confirm Password'),
              obscureText: _obscureConfirm,
              cursorColor: const Color(0xFF75D8FF),
              style: const TextStyle(
                color: _brightText,
                fontWeight: FontWeight.w600,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_isFormValid && !_isLoading) {
                  _register();
                }
              },
              validator: (value) {
                final text = value ?? '';

                if (text.isEmpty) {
                  return 'Confirm password is required';
                }

                if (text != _passwordController.text) {
                  return 'Passwords do not match';
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
                  onPressed: (!_isFormValid || _isLoading) ? null : _register,
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
                              'Create Account',
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

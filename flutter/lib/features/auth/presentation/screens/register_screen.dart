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
    }

    final isPassword = label == 'Password';
    final isConfirm = label == 'Confirm Password';

    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      prefixIcon: prefix != null ? Icon(prefix) : null,
      suffixIcon: (isPassword || isConfirm)
          ? IconButton(
              tooltip: (isPassword ? _obscurePassword : _obscureConfirm)
                  ? 'Show password'
                  : 'Hide password',
              icon: Icon(
                (isPassword ? _obscurePassword : _obscureConfirm)
                    ? Icons.visibility_off
                    : Icons.visibility,
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
            style: TextStyle(color: Color(0xFF365A63)),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
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
              height: 54,
              child: ElevatedButton(
                onPressed: (!_isFormValid || _isLoading) ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

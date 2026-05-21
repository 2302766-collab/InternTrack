import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exceptions/api_exception.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../models/app_user.dart';

Future<bool?> showProfileEditDialog(
  BuildContext context, {
  required String title,
  required AppUser? user,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _ProfileEditDialog(title: title, user: user),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully.')),
    );
  }

  return saved;
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.title, required this.user});

  final String title;
  final AppUser? user;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  static const List<String> _genderOptions = <String>['Male', 'Female'];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedGender;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _selectedGender = _normalizeGender(widget.user?.gender);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _normalizeGender(String? gender) {
    final normalized = gender?.trim().toLowerCase();
    switch (normalized) {
      case 'female':
        return 'Female';
      case 'male':
      default:
        return 'Male';
    }
  }

  String _messageForError(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().updateProfile(
        name: _nameController.text.trim(),
        gender: _selectedGender,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _messageForError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey<String>('profile_edit_name_field'),
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                hintText: 'Enter your full name',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Full name is required';
                }
                if (trimmed.length < 2) {
                  return 'Enter a valid full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('profile_edit_gender_field'),
              value: _selectedGender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: _genderOptions
                  .map(
                    (gender) => DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

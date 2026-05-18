import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/logbook_service.dart';
import '../../../../shared/models/log_entry.dart';
import '../log_date_policy.dart';

class LogEditScreen extends StatefulWidget {
  final LogEntryItem log;
  final LogbookService service;

  const LogEditScreen({super.key, required this.log, required this.service});

  @override
  State<LogEditScreen> createState() => _LogEditScreenState();
}

class _LogEditScreenState extends State<LogEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _dateController;
  late final TextEditingController _hoursController;
  late final TextEditingController _taskController;
  late final TextEditingController _reasonController;

  bool _autoValidate = false;
  bool _isSaving = false;
  String? _formError;
  Map<String, String?> _fieldErrors = _emptyFieldErrors();

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.log.date);
    _hoursController = TextEditingController(
      text: widget.log.hoursRendered.toString(),
    );
    _taskController = TextEditingController(text: widget.log.taskDescription);
    _reasonController = TextEditingController();

    _dateController.addListener(() => _clearFieldError('date'));
    _hoursController.addListener(() => _clearFieldError('hours'));
    _taskController.addListener(() => _clearFieldError('task'));
    _reasonController.addListener(() => _clearFieldError('reason'));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _hoursController.dispose();
    _taskController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  static Map<String, String?> _emptyFieldErrors() => <String, String?>{
    'date': null,
    'hours': null,
    'task': null,
    'reason': null,
  };

  void _clearFieldError(String key) {
    if (_fieldErrors[key] != null || _formError != null) {
      setState(() {
        _fieldErrors[key] = null;
        _formError = null;
      });
    }
  }

  Future<void> _selectLogDate() async {
    final currentText = _dateController.text.trim();
    final parsed = DateTime.tryParse(currentText);
    final initialDate = LogDatePolicy.clampToAllowedRange(
      parsed ?? LogDatePolicy.today(),
    );

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: LogDatePolicy.earliestAllowedDate(),
      lastDate: LogDatePolicy.today(),
    );

    if (selected == null || !mounted) return;

    _dateController.text = LogDatePolicy.formatForApi(selected);
    setState(() {});
  }

  String? _validateDate(String? value, {String? serverError}) {
    return LogDatePolicy.validate(value, serverError: serverError);
  }

  String? _validateHours(String? value, {String? serverError}) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'Hours must be a number';
    if (parsed < 1 || parsed > 12) return 'Hours must be between 1 and 12';
    return serverError;
  }

  String? _validateTask(String? value, {String? serverError}) {
    if ((value ?? '').trim().isEmpty) return 'Task description is required';
    return serverError;
  }

  void _handleApiException(ApiException e) {
    final mapped = _emptyFieldErrors();

    final details = e.details ?? const <String, dynamic>{};
    details.forEach((key, messages) {
      final first = messages is List && messages.isNotEmpty
          ? messages.first.toString()
          : messages?.toString();
      switch (key) {
        case 'date':
        case 'log_date':
          mapped['date'] = first;
          break;
        case 'hours':
        case 'hours_rendered':
          mapped['hours'] = first;
          break;
        case 'task':
        case 'task_description':
        case 'description':
          mapped['task'] = first;
          break;
        case 'reason':
          mapped['reason'] = first;
          break;
        default:
          break;
      }
    });

    final hasMapped = mapped.values.any(
      (value) => value != null && value.isNotEmpty,
    );

    setState(() {
      _fieldErrors = mapped;
      _formError = hasMapped ? null : e.message;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    setState(() {
      _autoValidate = true;
      _formError = null;
      _fieldErrors = _emptyFieldErrors();
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final isDirectEdit = widget.log.isPending;
      if (isDirectEdit) {
        await widget.service.updateLog(
          id: widget.log.id,
          date: _dateController.text.trim(),
          hoursRendered: int.parse(_hoursController.text.trim()),
          taskDescription: _taskController.text.trim(),
        );
      } else {
        final reason = _reasonController.text.trim();
        if (reason.length < 5) {
          setState(() {
            _fieldErrors['reason'] = 'Reason must be at least 5 characters';
            _isSaving = false;
          });
          _formKey.currentState?.validate();
          return;
        }

        await widget.service.requestLogEdit(
          id: widget.log.id,
          date: _dateController.text.trim(),
          hoursRendered: int.parse(_hoursController.text.trim()),
          taskDescription: _taskController.text.trim(),
          reason: reason,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.log.isPending
                ? 'Log updated successfully.'
                : 'Edit request sent to admin for approval.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _handleApiException(e);
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = e.toString().replaceFirst('Exception: ', '');
        });
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Log')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate
              ? AutovalidateMode.always
              : AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _dateController,
                enabled: !_isSaving,
                readOnly: true,
                onTap: _isSaving ? null : _selectLogDate,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  helperText: LogDatePolicy.helperText,
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) =>
                    _validateDate(value, serverError: _fieldErrors['date']),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hoursController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  labelText: 'Hours Rendered',
                  hintText: '1-12',
                ),
                validator: (value) =>
                    _validateHours(value, serverError: _fieldErrors['hours']),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taskController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Task Description',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    _validateTask(value, serverError: _fieldErrors['task']),
              ),
              if (!widget.log.isPending) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for admin approval',
                    alignLabelWithHint: true,
                    hintText:
                        'Explain what was wrong and why it needs correction.',
                  ),
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return _fieldErrors['reason'] ?? 'Reason is required';
                    }
                    if (trimmed.length < 5) {
                      return _fieldErrors['reason'] ??
                          'Reason must be at least 5 characters';
                    }
                    return _fieldErrors['reason'];
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'This log is no longer pending, so changes will be sent to admin for approval before they are applied.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 8),
                Text(_formError!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            const Text('Saving...'),
                          ],
                        )
                      : Text(
                          widget.log.isPending
                              ? 'Save Changes'
                              : 'Send Edit Request',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

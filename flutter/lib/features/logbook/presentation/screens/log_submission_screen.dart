import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/logbook_service.dart';
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../core/utils/file_picker_helper_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_picker_helper_web.dart'
    as file_picker;
import '../../../../core/utils/picked_file_data.dart';
import '../log_date_policy.dart';

class LogSubmissionScreen extends StatefulWidget {
  final String token;
  final LogbookService service;

  const LogSubmissionScreen({
    super.key,
    required this.token,
    required this.service,
  });

  @override
  State<LogSubmissionScreen> createState() => _LogSubmissionScreenState();
}

class _LogSubmissionScreenState extends State<LogSubmissionScreen> {
  static const int _maxAttachmentBytes = 5 * 1024 * 1024;
  static const List<String> _allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'pdf',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<PickedFileData?>> _attachmentFieldKey =
      GlobalKey<FormFieldState<PickedFileData?>>();

  late final TextEditingController _dateController;
  late final TextEditingController _hoursController;
  late final TextEditingController _taskController;

  bool _autoValidate = false;
  bool _isSubmitting = false;
  String? _formGeneralError;
  String? _attachmentError;
  PickedFileData? _selectedFile;
  Map<String, String?> _apiFieldErrors = _emptyFieldErrors();

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: LogDatePolicy.formatForApi(LogDatePolicy.today()),
    );
    _hoursController = TextEditingController(text: '8');
    _taskController = TextEditingController();

    _dateController.addListener(() => _clearFieldError('date'));
    _hoursController.addListener(() => _clearFieldError('hours'));
    _taskController.addListener(() => _clearFieldError('task'));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _hoursController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  static Map<String, String?> _emptyFieldErrors() => <String, String?>{
    'date': null,
    'hours': null,
    'task': null,
    'attachment': null,
  };

  void _clearFieldError(String key) {
    if (_apiFieldErrors[key] != null || _formGeneralError != null) {
      setState(() {
        _apiFieldErrors[key] = null;
        if (key != 'attachment') {
          _formGeneralError = null;
        }
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

  String? _validateSelectedFile(PickedFileData file) {
    final name = file.name.toLowerCase();
    final hasAllowedExt = _allowedExtensions.any(
      (ext) => name.endsWith('.$ext') || name.endsWith(ext),
    );
    if (!hasAllowedExt) {
      return 'Only JPG, PNG, or PDF files are allowed.';
    }

    if (file.bytes.length > _maxAttachmentBytes) {
      return 'File must be 5MB or smaller.';
    }

    return null;
  }

  String? _validateAttachment() {
    return _attachmentError ?? _apiFieldErrors['attachment'];
  }

  bool get _isSubmitEnabled {
    return !_isSubmitting &&
        _validateDate(
              _dateController.text,
              serverError: _apiFieldErrors['date'],
            ) ==
            null &&
        _validateHours(
              _hoursController.text,
              serverError: _apiFieldErrors['hours'],
            ) ==
            null &&
        _validateTask(
              _taskController.text,
              serverError: _apiFieldErrors['task'],
            ) ==
            null &&
        _validateAttachment() == null;
  }

  Future<void> _pickAttachment() async {
    final selected = await file_picker.pickSingleFile(
      allowedExtensions: _allowedExtensions,
    );

    if (!mounted) return;

    final validationError = selected != null
        ? _validateSelectedFile(selected)
        : null;

    setState(() {
      _attachmentError = validationError;
      _selectedFile = validationError == null ? selected : null;
      _apiFieldErrors['attachment'] = null;
    });

    _attachmentFieldKey.currentState?.didChange(_selectedFile);
    if (_autoValidate) {
      _attachmentFieldKey.currentState?.validate();
    }
  }

  void _removeAttachment() {
    setState(() {
      _selectedFile = null;
      _attachmentError = null;
      _apiFieldErrors['attachment'] = null;
    });
    _attachmentFieldKey.currentState?.didChange(null);
    if (_autoValidate) {
      _attachmentFieldKey.currentState?.validate();
    }
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
        case 'file':
        case 'attachment':
          mapped['attachment'] = first;
          break;
        default:
          break;
      }
    });

    var hasMappedFieldError = mapped.values.any(
      (value) => value != null && value.isNotEmpty,
    );

    if (!hasMappedFieldError) {
      final lower = e.message.toLowerCase();
      if (lower.contains('date')) {
        mapped['date'] = e.message;
      } else if (lower.contains('hour')) {
        mapped['hours'] = e.message;
      } else if (lower.contains('description') || lower.contains('task')) {
        mapped['task'] = e.message;
      } else if (lower.contains('file') || lower.contains('attachment')) {
        mapped['attachment'] = e.message;
      }

      hasMappedFieldError = mapped.values.any(
        (value) => value != null && value.isNotEmpty,
      );
    }

    setState(() {
      _apiFieldErrors = mapped;
      _formGeneralError = hasMappedFieldError ? null : e.message;
      if (mapped['attachment'] != null) {
        _attachmentError = mapped['attachment'];
      }
    });

    _formKey.currentState?.validate();
    _attachmentFieldKey.currentState?.validate();
  }

  Future<void> _submitLog() async {
    setState(() {
      _autoValidate = true;
      _formGeneralError = null;
      _apiFieldErrors = _emptyFieldErrors();
      _attachmentError = null;
    });

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final created = await widget.service.createLog(
        date: _dateController.text.trim(),
        hoursRendered: int.parse(_hoursController.text.trim()),
        taskDescription: _taskController.text.trim(),
      );

      if (_selectedFile != null) {
        final uploadError = _validateSelectedFile(_selectedFile!);
        if (uploadError != null) {
          setState(() {
            _attachmentError = uploadError;
          });
          _attachmentFieldKey.currentState?.validate();
          return;
        }

        await widget.service.uploadAttachment(
          logId: created.id,
          bytes: _selectedFile!.bytes,
          fileName: _selectedFile!.name,
          mimeType: _selectedFile!.mimeType,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily log submitted successfully.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _handleApiException(e);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formGeneralError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  bool _isImageFile(PickedFileData file) {
    final mime = file.mimeType.toLowerCase();
    final name = file.name.toLowerCase();
    return mime.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  bool _isPdfFile(PickedFileData file) {
    final mime = file.mimeType.toLowerCase();
    return mime == 'application/pdf' ||
        file.name.toLowerCase().endsWith('.pdf');
  }

  Future<void> _previewSelectedImage() async {
    final file = _selectedFile;
    if (file == null || !_isImageFile(file)) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF102A56),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: InteractiveViewer(
                    child: Image.memory(file.bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _previewSelectedPdf() async {
    final file = _selectedFile;
    if (file == null || !_isPdfFile(file)) return;

    final opened = await file_download.openBytesInNewTab(
      bytes: file.bytes,
      mimeType: file.mimeType,
    );

    if (!mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF preview is only available on web in this build.'),
        ),
      );
    }
  }

  Widget _buildSelectedAttachmentPreview() {
    final file = _selectedFile;
    if (file == null) {
      return const SizedBox.shrink();
    }

    final isImage = _isImageFile(file);
    final isPdf = _isPdfFile(file);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useColumn = constraints.maxWidth < 700;

          final previewTile = Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: isImage
                  ? Image.memory(file.bytes, fit: BoxFit.cover)
                  : Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.insert_drive_file_rounded,
                      size: 42,
                      color: isPdf
                          ? const Color(0xFFD92D20)
                          : const Color(0xFF667085),
                    ),
            ),
          );

          final details = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        file.name.split('.').last.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475467),
                        ),
                      ),
                    ),
                    if (isImage || isPdf)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF8FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isImage
                              ? 'Image preview ready'
                              : 'PDF preview available',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF175CD3),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF102A56),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selected file - ${_formatFileSize(file.bytes.length)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  isImage
                      ? 'Thumbnail shown below. Use Preview to inspect the full image.'
                      : isPdf
                      ? 'Open the PDF preview in a browser tab before submitting.'
                      : 'File is attached and ready to upload.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (isImage)
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _previewSelectedImage,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Preview Image'),
                      ),
                    if (isPdf)
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _previewSelectedPdf,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Preview PDF'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _removeAttachment,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          );

          return useColumn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    previewTile,
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                file.name.split('.').last.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475467),
                                ),
                              ),
                            ),
                            if (isImage || isPdf)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF8FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isImage
                                      ? 'Image preview ready'
                                      : 'PDF preview available',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF175CD3),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF102A56),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Selected file - ${_formatFileSize(file.bytes.length)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isImage
                              ? 'Thumbnail shown above. Use Preview to inspect the full image.'
                              : isPdf
                              ? 'Open the PDF preview in a browser tab before submitting.'
                              : 'File is attached and ready to upload.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (isImage)
                              ElevatedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _previewSelectedImage,
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text('Preview Image'),
                              ),
                            if (isPdf)
                              ElevatedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _previewSelectedPdf,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Preview PDF'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : _removeAttachment,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [previewTile, const SizedBox(width: 16), details],
                );
        },
      ),
    );
  }

  Widget _buildAttachmentField() {
    return FormField<PickedFileData?>(
      key: _attachmentFieldKey,
      autovalidateMode: _autoValidate
          ? AutovalidateMode.always
          : AutovalidateMode.onUserInteraction,
      validator: (_) => _validateAttachment(),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _selectedFile != null
                          ? 'Change Attachment'
                          : 'Choose File',
                    ),
                  ),
                ),
                if (_selectedFile != null)
                  IconButton(
                    onPressed: _isSubmitting ? null : _removeAttachment,
                    tooltip: 'Remove file',
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Attachment (optional) - jpg/jpeg/png/pdf - <= 5MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_selectedFile != null) _buildSelectedAttachmentPreview(),
            if (state.hasError) ...[
              const SizedBox(height: 6),
              Text(state.errorText!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Daily Log')),
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
                enabled: !_isSubmitting,
                readOnly: true,
                onTap: _isSubmitting ? null : _selectLogDate,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  helperText: LogDatePolicy.helperText,
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) =>
                    _validateDate(value, serverError: _apiFieldErrors['date']),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hoursController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  labelText: 'Hours Rendered',
                  hintText: '1-12',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) => _validateHours(
                  value,
                  serverError: _apiFieldErrors['hours'],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taskController,
                enabled: !_isSubmitting,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Task Description',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    _validateTask(value, serverError: _apiFieldErrors['task']),
              ),
              const SizedBox(height: 12),
              _buildAttachmentField(),
              if (_formGeneralError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formGeneralError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitEnabled ? _submitLog : null,
                  child: _isSubmitting
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
                            const Text('Submitting...'),
                          ],
                        )
                      : const Text('Submit Log'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

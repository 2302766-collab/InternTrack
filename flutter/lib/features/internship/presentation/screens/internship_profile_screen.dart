import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/internship_service.dart';
import '../../../../shared/models/internship_profile.dart';
import '../../../../shared/models/supervisor_option.dart';
import '../../../student/presentation/widgets/student_scaffold.dart';

class InternshipProfileScreen extends StatefulWidget {
<class InternshipProfileScreen extends StatefulWidget {
  const InternshipProfileScreen({super.key});

  @override
  State<InternshipProfileScreen> createState() =>
      _InternshipProfileScreenState();
}


  @override
  State<InternshipProfileScreen> createState() =>
      _InternshipProfileScreenState();
}

class _InternshipProfileScreenState extends State<InternshipProfileScreen> {
  static final DateTime _firstPickableDate = DateTime(2000);
  static final DateTime _lastPickableDate = DateTime(2100, 12, 31);

  late final InternshipService _service;

  InternshipProfile? _profile;
  List<SupervisorOption> _supervisors = <SupervisorOption>[];
  int? _selectedSupervisorId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadErrorMessage;
  String? _submitErrorMessage;
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _requiredHoursController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = context.read<InternshipService>();
    _loadProfile();
  }

  String _formatApiDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _readableDateHelper(String iso) {
    final parsed = DateTime.tryParse(iso.trim());
    if (parsed == null) {
      return 'Choose a date using the calendar';
    }
    return DateFormat.yMMMd().format(parsed);
  }

  Future<void> _pickStartDate() async {
    if (_isSubmitting) return;

    final parsed = DateTime.tryParse(_startDateController.text.trim());
    final initialDate = parsed ?? DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _clampDate(initialDate),
      firstDate: _firstPickableDate,
      lastDate: _lastPickableDate,
    );

    if (selected == null || !mounted) return;

    setState(() {
      _startDateController.text = _formatApiDate(selected);
      _submitErrorMessage = null;
    });
  }

  Future<void> _pickEndDate() async {
    if (_isSubmitting) return;

    final start = DateTime.tryParse(_startDateController.text.trim());
    final parsed = DateTime.tryParse(_endDateController.text.trim());
    final initialDate = parsed ?? start?.add(const Duration(days: 1)) ?? DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _clampDate(initialDate),
      firstDate: _firstPickableDate,
      lastDate: _lastPickableDate,
    );

    if (selected == null || !mounted) return;

    setState(() {
      _endDateController.text = _formatApiDate(selected);
      _submitErrorMessage = null;
    });
  }

  DateTime _clampDate(DateTime date) {
    if (date.isBefore(_firstPickableDate)) return _firstPickableDate;
    if (date.isAfter(_lastPickableDate)) return _lastPickableDate;
    return date;
  }

  String _userFacingErrorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });

    try {
      final profile = await _service.getInternshipProfile();
      final supervisors = profile == null
          ? await _service.getSupervisors()
          : <SupervisorOption>[];

      if (mounted) {
        setState(() {
          _profile = profile;
          _supervisors = supervisors;
          _selectedSupervisorId = supervisors.isNotEmpty
              ? supervisors.first.id
              : null;
          _isEditing = false;
          _submitErrorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadErrorMessage = _userFacingErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyProfileToControllers(InternshipProfile profile) {
    _companyNameController.text = profile.companyName;
    _companyAddressController.text = profile.companyAddress;
    _requiredHoursController.text = profile.requiredHours.toString();
    _startDateController.text = profile.startDate;
    _endDateController.text = profile.endDate;
  }

  void _beginEditing() {
    final profile = _profile;
    if (profile == null) return;

    setState(() {
      _submitErrorMessage = null;
      _applyProfileToControllers(profile);
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    final profile = _profile;
    if (profile == null) return;

    setState(() {
      _submitErrorMessage = null;
      _applyProfileToControllers(profile);
      _isEditing = false;
    });
  }

  String? _validateCompanyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Company name is required';
    }
    return null;
  }

  String? _validateCompanyAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Company address is required';
    }
    return null;
  }

  String? _validateRequiredHours(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required hours is required';
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 1) {
      return 'Required hours must be a whole number greater than 0';
    }

    return null;
  }

  String? _validateStartDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Start date is required';
    }

    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return 'Start date is invalid';
    }

    return null;
  }

  String? _validateEndDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'End date is required';
    }

    final start = DateTime.tryParse(_startDateController.text.trim());
    final end = DateTime.tryParse(value.trim());

    if (end == null) {
      return 'End date is invalid';
    }

    if (start != null && !end.isAfter(start)) {
      return 'End date must be after start date';
    }

    return null;
  }

  Future<void> _submitCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitErrorMessage = null;
    });

    try {
      final createdProfile = await _service.createInternshipProfile(
        companyName: _companyNameController.text.trim(),
        companyAddress: _companyAddressController.text.trim(),
        supervisorId: _selectedSupervisorId!,
        requiredHours: int.parse(_requiredHoursController.text.trim()),
        startDate: _startDateController.text.trim(),
        endDate: _endDateController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _profile = createdProfile;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitErrorMessage = _userFacingErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitErrorMessage = null;
    });

    try {
      final updated = await _service.updateInternshipProfile(
        companyName: _companyNameController.text.trim(),
        companyAddress: _companyAddressController.text.trim(),
        requiredHours: int.parse(_requiredHoursController.text.trim()),
        startDate: _startDateController.text.trim(),
        endDate: _endDateController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _profile = updated;
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitErrorMessage = _userFacingErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildDateField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required Future<void> Function() onPick,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      readOnly: true,
      enableInteractiveSelection: false,
      showCursor: false,
      onTap: _isSubmitting ? null : onPick,
      keyboardType: TextInputType.none,
      decoration: InputDecoration(
        labelText: label,
        helperText: _readableDateHelper(controller.text),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      validator: validator,
    );
  }

  Widget _buildSubmitErrorBanner() {
    final message = _submitErrorMessage;
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSharedFields({required bool includeSupervisorDropdown}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _companyNameController,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(labelText: 'Company Name'),
          validator: _validateCompanyName,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _companyAddressController,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(labelText: 'Company Address'),
          validator: _validateCompanyAddress,
        ),
        const SizedBox(height: 12),
        if (includeSupervisorDropdown) ...[
          DropdownButtonFormField<int>(
            value: _selectedSupervisorId,
            decoration: const InputDecoration(
              labelText: 'Assigned Supervisor',
            ),
            items: _supervisors
                .map(
                  (supervisor) => DropdownMenuItem<int>(
                    value: supervisor.id,
                    child: Text(supervisor.displayLabel),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      _selectedSupervisorId = value;
                    });
                  },
            validator: (value) {
              if (value == null) {
                return 'Supervisor is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _requiredHoursController,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(labelText: 'Required Hours'),
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: _validateRequiredHours,
        ),
        const SizedBox(height: 12),
        _buildDateField(
          key: const ValueKey<String>('internship_profile_start_date_field'),
          controller: _startDateController,
          label: 'Start Date',
          onPick: _pickStartDate,
          validator: _validateStartDate,
        ),
        const SizedBox(height: 12),
        _buildDateField(
          key: const ValueKey<String>('internship_profile_end_date_field'),
          controller: _endDateController,
          label: 'End Date',
          onPick: _pickEndDate,
          validator: _validateEndDate,
        ),
      ],
    );
  }

  Widget _buildSupervisorSummaryTile() {
    final profile = _profile!;
    final name = profile.supervisorName?.trim();
    final label = name != null && name.isNotEmpty
        ? name
        : (profile.supervisorId?.toString() ?? 'Not assigned');

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Assigned Supervisor',
        border: OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          if ((profile.supervisorEmail ?? '').isNotEmpty)
            Text(
              profile.supervisorEmail!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    final profile = _profile!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Internship Profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Company: ${profile.companyName}'),
            Text('Address: ${profile.companyAddress}'),
            Text('Required Hours: ${profile.requiredHours}'),
            Text(
              'Start Date: ${_readableDateHelper(profile.startDate) ?? profile.startDate}',
            ),
            Text(
              'End Date: ${_readableDateHelper(profile.endDate) ?? profile.endDate}',
            ),
            Text(
              'Supervisor: ${profile.supervisorName?.trim().isNotEmpty == true ? profile.supervisorName : profile.supervisorId?.toString() ?? "Not assigned"}',
            ),
            if ((profile.supervisorEmail ?? '').isNotEmpty)
              Text('Supervisor Email: ${profile.supervisorEmail}'),
            Text(
              'Adviser ID: ${profile.adviserId?.toString() ?? "Not assigned"}',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey<String>('internship_profile_edit_button'),
                onPressed: _isSubmitting ? null : _beginEditing,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Internship Profile',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildSupervisorSummaryTile(),
          const SizedBox(height: 16),
          _buildSharedFields(includeSupervisorDropdown: false),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>(
                    'internship_profile_cancel_button',
                  ),
                  onPressed: _isSubmitting ? null : _cancelEditing,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>(
                    'internship_profile_save_button',
                  ),
                  onPressed: _isSubmitting ? null : _submitEdit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFormView() {
    if (_supervisors.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No supervisors are available yet. Please contact your administrator.',
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSharedFields(includeSupervisorDropdown: true),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey<String>(
                'internship_profile_create_button',
              ),
              onPressed: _isSubmitting ? null : _submitCreate,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Internship Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _loadErrorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadProfile,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _requiredHoursController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudentScaffold(
      currentRoute: AppRoutes.internshipProfile,
      appBar: AppBar(title: const Text('Internship Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadErrorMessage != null
            ? _buildLoadErrorView()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSubmitErrorBanner(),
                    if (_profile != null && !_isEditing) _buildSummaryView(),
                    if (_profile != null && _isEditing) _buildEditFormView(),
                    if (_profile == null) _buildCreateFormView(),
                  ],
                ),
              ),
      ),
    );
  }
}

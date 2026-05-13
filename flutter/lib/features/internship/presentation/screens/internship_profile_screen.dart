import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../shared/models/internship_profile.dart';
import '../../../../shared/models/supervisor_option.dart';
import '../../../../core/services/internship_service.dart';
import '../../../student/presentation/widgets/student_scaffold.dart';

class InternshipProfileScreen extends StatefulWidget {
  final String token;

  const InternshipProfileScreen({super.key, required this.token});

  @override
  State<InternshipProfileScreen> createState() =>
      _InternshipProfileScreenState();
}

class _InternshipProfileScreenState extends State<InternshipProfileScreen> {
  late final InternshipService _service;

  InternshipProfile? _profile;
  List<SupervisorOption> _supervisors = <SupervisorOption>[];
  int? _selectedSupervisorId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

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

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
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
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
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

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _requiredHoursController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
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
            Text('Start Date: ${profile.startDate}'),
            Text('End Date: ${profile.endDate}'),
            Text(
              'Supervisor: ${profile.supervisorName?.trim().isNotEmpty == true ? profile.supervisorName : profile.supervisorId?.toString() ?? "Not assigned"}',
            ),
            if ((profile.supervisorEmail ?? '').isNotEmpty)
              Text('Supervisor Email: ${profile.supervisorEmail}'),
            Text(
              'Adviser ID: ${profile.adviserId?.toString() ?? "Not assigned"}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
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
        children: [
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(labelText: 'Company Name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _companyAddressController,
            decoration: const InputDecoration(labelText: 'Company Address'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company address is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedSupervisorId,
            decoration: const InputDecoration(labelText: 'Assigned Supervisor'),
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
          TextFormField(
            controller: _requiredHoursController,
            decoration: const InputDecoration(labelText: 'Required Hours'),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required hours is required';
              }

              final parsed = int.tryParse(value.trim());
              if (parsed == null || parsed < 1) {
                return 'Required hours must be greater than 0';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _startDateController,
            decoration: const InputDecoration(
              labelText: 'Start Date',
              hintText: 'YYYY-MM-DD',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Start date is required';
              }

              final parsed = DateTime.tryParse(value.trim());
              if (parsed == null) {
                return 'Enter a valid date (YYYY-MM-DD)';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _endDateController,
            decoration: const InputDecoration(
              labelText: 'End Date',
              hintText: 'YYYY-MM-DD',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'End date is required';
              }

              final start = DateTime.tryParse(_startDateController.text.trim());
              final end = DateTime.tryParse(value.trim());

              if (end == null) {
                return 'Enter a valid date (YYYY-MM-DD)';
              }

              if (start != null && !end.isAfter(start)) {
                return 'End date must be after start date';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Internship Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
        ],
      ),
    );
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
            : _errorMessage != null
            ? _buildErrorView()
            : _profile != null
            ? _buildSummaryView()
            : SingleChildScrollView(child: _buildFormView()),
      ),
    );
  }
}

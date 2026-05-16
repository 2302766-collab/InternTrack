import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/admin_dashboard_service.dart';
import '../../../../core/services/admin_student_service.dart';
import '../../../../core/services/admin_user_management_service.dart';
import '../../../../core/services/intern_reporting_service.dart';
import '../../../../core/utils/file_picker_helper_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_picker_helper_web.dart'
    as file_picker;
import '../../../../core/utils/file_download_stub.dart'
    if (dart.library.html) '../../../../core/utils/file_download_web.dart'
    as file_download;
import '../../../../shared/models/admin_dashboard_summary.dart';
import '../../../../shared/models/admin_student_summary.dart';
import '../../../../shared/models/admin_students_page.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/dtr_export_dialog.dart';
import '../../../../shared/widgets/notification_bell_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String userName;

  const AdminDashboardScreen({super.key, required this.userName});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const int _itemsPerPage = 10;
  static const int _managedUsersPerPage = 9;
  static const String _filterAll = 'all';
  static const String _filterNeedsAttention = 'needs_attention';
  static const String _filterMissingProfile = 'missing_profile';
  static const String _filterMissingSupervisor = 'missing_supervisor';
  static const String _filterMissingAdviser = 'missing_adviser';
  static const String _userRoleAll = 'all';

  static const Color _pageBackground = Color(0xFFF3F6FB);
  static const Color _surfaceColor = Colors.white;
  static const Color _borderColor = Color(0xFFD8E2EC);
  static const Color _textPrimary = Color(0xFF0F254A);
  static const Color _textSecondary = Color(0xFF5E718D);
  static const Color _brandPrimary = Color(0xFF123C73);
  static const Color _brandSecondary = Color(0xFF0F766E);
  static const Color _accentGold = Color(0xFFF4B740);

  late final AdminStudentService _studentService;
  late final AdminDashboardService _dashboardService;
  late final AdminUserManagementService _userManagementService;
  late final InternReportingService _reportingService;

  final List<AdminStudentSummary> _students = <AdminStudentSummary>[];
  final List<AppUser> _managedUsers = <AppUser>[];
  final GlobalKey _profileMenuAnchorKey = GlobalKey();
  final TextEditingController _managedUserSearchController =
      TextEditingController();
  final Set<int> _exportingStudentIds = <int>{};
  final Set<int> _deletingUserIds = <int>{};

  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  bool _isCreatingUser = false;
  String? _errorMessage;
  String? _userManagementError;
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalStudents = 0;
  int _managedUsersPage = 1;
  String _selectedFilter = _filterAll;
  String _userSearchQuery = '';
  String _selectedUserRoleFilter = _userRoleAll;
  AdminDashboardSummary? _dashboardSummary;
  late DateTime _exportStartDate;
  late DateTime _exportEndDate;

  @override
  void initState() {
    super.initState();
    _studentService = context.read<AdminStudentService>();
    _dashboardService = context.read<AdminDashboardService>();
    _userManagementService = context.read<AdminUserManagementService>();
    _reportingService = InternReportingService(context.read<ApiClient>());
    final now = DateTime.now();
    _exportStartDate = DateTime(now.year, now.month, 1);
    _exportEndDate = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoading && _students.isEmpty && _dashboardSummary == null) {
      _refreshDashboard();
    }
  }

  @override
  void dispose() {
    _managedUserSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    await _loadDashboard(page: 1);
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _lastPage || page == _currentPage) {
      return;
    }

    await _loadDashboard(page: page);
  }

  Future<void> _loadDashboard({required int page}) async {
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) {
      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorMessage = 'Missing authentication token. Please log in again.';
      });
      return;
    }

    final isInitialRequest =
        (_students.isEmpty || _dashboardSummary == null) && !_isPageLoading;

    if (isInitialRequest) {
      setState(() {
        _isInitialLoading = true;
        _errorMessage = null;
      });
    } else {
      if (_isPageLoading) {
        return;
      }

      setState(() {
        _isPageLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _studentService.fetchStudents(page: page, perPage: _itemsPerPage),
        _dashboardService.getSummary(),
        _userManagementService.fetchManagedUsers(),
      ]);

      if (!mounted) return;

      final studentsPage = results[0] as AdminStudentsPage;
      final summary = results[1] as AdminDashboardSummary;
      final managedUsers = results[2] as List<AppUser>;

      setState(() {
        _currentPage = studentsPage.currentPage;
        _lastPage = studentsPage.lastPage == 0 ? 1 : studentsPage.lastPage;
        _totalStudents = studentsPage.total;
        _dashboardSummary = summary;
        _errorMessage = null;
        _userManagementError = null;
        _students
          ..clear()
          ..addAll(studentsPage.students);
        _managedUsers
          ..clear()
          ..addAll(managedUsers);
        _syncManagedUsersPage();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isPageLoading = false;
        });
      }
    }
  }

  Future<void> _openAdviserAssignment() async {
    await Navigator.pushNamed(context, AppRoutes.studentAdviserAssignment);

    if (mounted) {
      await _loadDashboard(page: _currentPage);
    }
  }

  List<AppUser> get _filteredManagedUsers {
    final query = _userSearchQuery.trim().toLowerCase();

    return _managedUsers.where((user) {
      final matchesRole =
          _selectedUserRoleFilter == _userRoleAll ||
          user.role == _selectedUserRoleFilter;
      if (!matchesRole) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query) ||
          user.id.toString().contains(query);
    }).toList();
  }

  List<AppUser> get _paginatedManagedUsers {
    final filteredUsers = _filteredManagedUsers;
    if (filteredUsers.isEmpty) {
      return const <AppUser>[];
    }

    final start = ((_managedUsersPage - 1) * _managedUsersPerPage).clamp(
      0,
      filteredUsers.length,
    );
    final end = (start + _managedUsersPerPage).clamp(0, filteredUsers.length);
    return filteredUsers.sublist(start, end);
  }

  int get _managedUsersLastPage {
    final total = _filteredManagedUsers.length;
    if (total == 0) {
      return 1;
    }
    return (total / _managedUsersPerPage).ceil();
  }

  void _syncManagedUsersPage() {
    final lastPage = _managedUsersLastPage;
    if (_managedUsersPage > lastPage) {
      _managedUsersPage = lastPage;
    }
    if (_managedUsersPage < 1) {
      _managedUsersPage = 1;
    }
  }

  int _managedUserCountForRole(String role) {
    return _managedUsers.where((user) => user.role == role).length;
  }

  void _updateManagedUserSearch(String value) {
    setState(() {
      _userSearchQuery = value;
      _managedUsersPage = 1;
    });
  }

  void _updateManagedUserRoleFilter(String role) {
    setState(() {
      _selectedUserRoleFilter = role;
      _managedUsersPage = 1;
    });
  }

  void _goToManagedUsersPage(int page) {
    final lastPage = _managedUsersLastPage;
    if (page < 1 || page > lastPage || page == _managedUsersPage) {
      return;
    }

    setState(() {
      _managedUsersPage = page;
    });
  }

  List<int> _visibleManagedUserPages(bool isCompact) {
    final lastPage = _managedUsersLastPage;
    if (lastPage <= 1) {
      return const <int>[1];
    }

    if (isCompact) {
      final pages = <int>{_managedUsersPage};
      if (_managedUsersPage > 1) {
        pages.add(_managedUsersPage - 1);
      }
      if (_managedUsersPage < lastPage) {
        pages.add(_managedUsersPage + 1);
      }
      final sorted = pages.toList()..sort();
      return sorted;
    }

    final start = (_managedUsersPage - 2).clamp(1, lastPage);
    final end = (_managedUsersPage + 2).clamp(1, lastPage);
    final pages = <int>[];
    for (var page = start; page <= end; page++) {
      pages.add(page);
    }
    return pages;
  }

  Future<void> _openCreateUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedRole = 'Student';
    var obscurePassword = true;

    final draft = await showDialog<_ManagedUserDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add User'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          hintText: 'Enter the user name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'user@example.com',
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Email is required.';
                          }
                          if (!trimmed.contains('@')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Student',
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: 'Adviser',
                            child: Text('Adviser'),
                          ),
                          DropdownMenuItem(
                            value: 'Supervisor',
                            child: Text('Supervisor'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedRole = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Minimum 8 characters',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _ManagedUserDraft(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        role: selectedRole,
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    if (draft == null) {
      return;
    }

    await _createManagedUser(draft);
  }

  Future<void> _createManagedUser(_ManagedUserDraft draft) async {
    if (_isCreatingUser) {
      return;
    }

    setState(() {
      _isCreatingUser = true;
      _userManagementError = null;
    });

    try {
      final createdUser = await _userManagementService.createManagedUser(
        name: draft.name,
        email: draft.email,
        password: draft.password,
        role: draft.role,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${createdUser.role} account created.')),
      );
      await _loadDashboard(page: _currentPage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userManagementError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingUser = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteManagedUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Remove ${user.role}'),
          content: Text(
            'Remove ${user.name} (${user.email})? Student records will be deleted. Adviser and supervisor assignments will be cleared automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingUserIds.add(user.id);
      _userManagementError = null;
    });

    try {
      final removedUser = await _userManagementService.deleteManagedUser(
        user.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${removedUser.role} account removed.')),
      );
      await _loadDashboard(page: _currentPage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userManagementError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _deletingUserIds.remove(user.id);
        });
      }
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _exportStudentDtr(AdminStudentSummary student) async {
    final selection = await showDtrExportDialog(
      context,
      initialStartDate: _exportStartDate,
      initialEndDate: _exportEndDate,
      title: 'Export ${student.name} DTR',
      description:
          'Download a PDF or Excel copy of this student\'s daily time record for the selected date range.',
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _exportStartDate = selection.startDate;
      _exportEndDate = selection.endDate;
      _exportingStudentIds.add(student.studentId);
    });

    try {
      final file = await _reportingService.exportDtr(
        role: 'admin',
        studentId: student.studentId,
        startDate: selection.startDate,
        endDate: selection.endDate,
        pdf: selection.pdf,
      );

      if (!mounted) {
        return;
      }

      final downloaded = await file_download.downloadBytes(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: file.mimeType,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'DTR export downloaded successfully.'
                : 'Export is ready, but direct download is only available on web in this build.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingStudentIds.remove(student.studentId);
        });
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final file = await file_picker.pickSingleFile(
        allowedExtensions: const <String>['jpg', 'jpeg', 'png'],
      );
      if (file == null) {
        return;
      }

      await authProvider.updateAvatarBytes(file.bytes);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update profile photo right now.'),
        ),
      );
    }
  }

  Future<void> removeProfilePhoto() async {
    await context.read<AuthProvider>().updateAvatarBase64(null);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
  }

  List<AdminStudentSummary> get _filteredStudents {
    return _students.where(matchesSelectedFilter).toList();
  }

  bool matchesSelectedFilter(AdminStudentSummary student) {
    switch (_selectedFilter) {
      case _filterNeedsAttention:
        return !student.hasInternshipProfile ||
            !student.hasSupervisor ||
            !student.hasAdviser;
      case _filterMissingProfile:
        return !student.hasInternshipProfile;
      case _filterMissingSupervisor:
        return student.hasInternshipProfile && !student.hasSupervisor;
      case _filterMissingAdviser:
        return student.hasInternshipProfile && !student.hasAdviser;
      case _filterAll:
      default:
        return true;
    }
  }

  String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'AD';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  ImageProvider<Object>? avatarImageProviderFor(String? avatarBase64) {
    if (avatarBase64 == null || avatarBase64.isEmpty) {
      return null;
    }

    try {
      return MemoryImage(base64Decode(avatarBase64));
    } catch (_) {
      return null;
    }
  }

  Widget buildAvatar({
    required AppUser? user,
    required double radius,
    double fontSize = 16,
  }) {
    final imageProvider = avatarImageProviderFor(user?.avatarBase64);
    final name = user?.name ?? widget.userName;

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE2ECF8),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              initialsFor(name),
              style: TextStyle(
                color: _brandPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  String greetingForHour() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  Future<void> openProfilePanel() async {
    final anchorContext = _profileMenuAnchorKey.currentContext;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    final anchorOffset = anchorBox?.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final anchorSize = anchorBox?.size ?? const Size(280, 64);

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Admin profile',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final authProvider = dialogContext.watch<AuthProvider>();
        final user = authProvider.user;

        return SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: (anchorOffset?.dy ?? 86) + anchorSize.height + 10,
                left: (() {
                  final desiredLeft =
                      (anchorOffset?.dx ?? (overlay.size.width - 344)) -
                      (344 - anchorSize.width);
                  final maxLeft = overlay.size.width > 376
                      ? overlay.size.width - 360.0
                      : 16.0;
                  return desiredLeft.clamp(16.0, maxLeft);
                })(),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 344,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _borderColor),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x260F172A),
                          blurRadius: 34,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                buildAvatar(
                                  user: user,
                                  radius: 30,
                                  fontSize: 20,
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Material(
                                    color: _brandSecondary,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () async {
                                        Navigator.of(dialogContext).pop();
                                        await _pickProfilePhoto();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name.isNotEmpty == true
                                        ? user!.name
                                        : widget.userName,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email.isNotEmpty == true
                                        ? user!.email
                                        : 'No email available',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  buildMiniTag(
                                    label:
                                        (user?.role.isNotEmpty == true
                                                ? user!.role
                                                : 'Administrator')
                                            .toUpperCase(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        buildProfileActionTile(
                          icon: Icons.edit_outlined,
                          title: 'Change profile photo',
                          subtitle: 'Upload a JPG or PNG image for this admin.',
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await _pickProfilePhoto();
                          },
                        ),
                        if ((user?.avatarBase64 ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          buildProfileActionTile(
                            icon: Icons.hide_image_outlined,
                            title: 'Remove profile photo',
                            subtitle:
                                'Switch back to the generated initials avatar.',
                            onTap: () async {
                              Navigator.of(dialogContext).pop();
                              await removeProfilePhoto();
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        buildProfileInfoCard(user),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              await _logout();
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Log out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB42318),
                              side: const BorderSide(color: Color(0xFFF0C4C0)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildMiniTag({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _brandPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget buildProfileActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _brandPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildProfileInfoCard(AppUser? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Administrator',
            value: user?.name.isNotEmpty == true ? user!.name : widget.userName,
          ),
          const SizedBox(height: 10),
          buildInfoRow(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            value: user?.email.isNotEmpty == true
                ? user!.email
                : 'Not available',
          ),
          const SizedBox(height: 10),
          buildInfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Role',
            value: user?.role.isNotEmpty == true ? user!.role : 'Administrator',
          ),
          const SizedBox(height: 10),
          buildInfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'Account ID',
            value: user != null ? '#${user.id}' : 'Unavailable',
          ),
        ],
      ),
    );
  }

  Widget buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: _brandPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildHeader(AuthProvider authProvider) {
    final user = authProvider.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${greetingForHour()}, ${user?.name.split(' ').first ?? 'Admin'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Administrative Command Center',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Monitor internship operations, resolve student setup gaps, and keep approvals moving from one place.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          NotificationBellButton(token: authProvider.token ?? ''),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: _profileMenuAnchorKey,
              onTap: openProfilePanel,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildAvatar(user: user, radius: 22, fontSize: 14),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name.isNotEmpty == true
                                ? user!.name
                                : widget.userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.role.isNotEmpty == true
                                ? user!.role
                                : 'Administrator',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeroCard(AdminDashboardSummary summary) {
    final attentionRate = summary.totalStudents == 0
        ? 0
        : ((summary.studentsRequiringAttention / summary.totalStudents) * 100)
              .round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF17396B), Color(0xFF0E5E78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Live Operations Snapshot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${summary.studentsRequiringAttention} students need action from admin',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${summary.pendingLogs} logs are still pending review, and $attentionRate% of active students have setup items that need attention.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.84),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              buildHeroStatChip(
                label: 'Students',
                value: '${summary.totalStudents}',
              ),
              buildHeroStatChip(
                label: 'Completion',
                value:
                    '${summary.averageCompletionPercentage.toStringAsFixed(0)}%',
              ),
              buildHeroStatChip(
                label: 'Approved Logs',
                value: '${summary.approvedLogs}',
              ),
              buildHeroStatChip(
                label: 'Pending Review',
                value: '${summary.pendingLogs}',
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildHeroStatChip({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? _accentGold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryGrid(AdminDashboardSummary summary) {
    final items = <_SummaryItem>[
      _SummaryItem(
        label: 'Pending Logs',
        value: '${summary.pendingLogs}',
        subtitle: 'Waiting in the review flow',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFB54708),
      ),
      _SummaryItem(
        label: 'Missing Profiles',
        value: '${summary.studentsWithoutProfile}',
        subtitle: 'Students who still need setup',
        icon: Icons.description_outlined,
        color: const Color(0xFF9E4F15),
      ),
      _SummaryItem(
        label: 'No Supervisor',
        value: '${summary.studentsWithoutSupervisor}',
        subtitle: 'Internship profiles without supervision',
        icon: Icons.badge_outlined,
        color: const Color(0xFF175CD3),
      ),
      _SummaryItem(
        label: 'No Adviser',
        value: '${summary.studentsWithoutAdviser}',
        subtitle: 'Students who need adviser assignment',
        icon: Icons.school_outlined,
        color: const Color(0xFF6941C6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 740;
        final itemWidth = isCompact
            ? constraints.maxWidth
            : (constraints.maxWidth - 18) / 2;

        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: items
              .map(
                (item) =>
                    SizedBox(width: itemWidth, child: buildSummaryCard(item)),
              )
              .toList(),
        );
      },
    );
  }

  Widget buildSummaryCard(_SummaryItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(fontSize: 12.5, color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActionPanel(AdminDashboardSummary summary) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;

          return Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: stacked ? 0 : 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The dashboard should help you complete work, not only watch metrics. Use these actions to clear assignments and fix onboarding gaps quickly.',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _openAdviserAssignment,
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: const Text('Manage Assignments'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _isCreatingUser
                              ? null
                              : _openCreateUserDialog,
                          icon: _isCreatingUser
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            _isCreatingUser ? 'Creating...' : 'Add User',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandSecondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFilter = _filterNeedsAttention;
                            });
                          },
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('Attention Queue'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brandPrimary,
                            side: const BorderSide(color: Color(0xFFC5D4EA)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!stacked) const SizedBox(width: 18),
              if (stacked) const SizedBox(height: 18),
              Expanded(
                flex: stacked ? 0 : 5,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFF8FBFF), Color(0xFFF4F8FD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD7E4F4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: _brandPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Priority Insight',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        summary.studentsWithoutAdviser > 0
                            ? '${summary.studentsWithoutAdviser} students still need adviser assignment, and ${summary.studentsWithoutSupervisor} still need supervisor coverage.'
                            : (summary.studentsWithoutSupervisor > 0
                                  ? '${summary.studentsWithoutSupervisor} students still need supervisor coverage.'
                                  : 'All current internship profiles already have assignment coverage.'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use assignment management to assign, update, and remove supervisor or adviser links without leaving the admin workspace.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildSectionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(22),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget buildFilterChips() {
    final filters = <_StudentFilter>[
      const _StudentFilter(key: _filterAll, label: 'All Students'),
      const _StudentFilter(
        key: _filterNeedsAttention,
        label: 'Needs Attention',
      ),
      const _StudentFilter(
        key: _filterMissingProfile,
        label: 'Missing Profile',
      ),
      const _StudentFilter(
        key: _filterMissingSupervisor,
        label: 'No Supervisor',
      ),
      const _StudentFilter(key: _filterMissingAdviser, label: 'No Adviser'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: filters
          .map(
            (filter) => ChoiceChip(
              label: Text(filter.label),
              selected: _selectedFilter == filter.key,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter.key;
                });
              },
              backgroundColor: const Color(0xFFF8FAFC),
              selectedColor: const Color(0xFFDCEBFF),
              side: BorderSide(
                color: _selectedFilter == filter.key
                    ? _brandPrimary
                    : const Color(0xFFD0D5DD),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              labelStyle: TextStyle(
                color: _selectedFilter == filter.key
                    ? _brandPrimary
                    : const Color(0xFF475467),
                fontWeight: FontWeight.w800,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget buildStudentCard(AdminStudentSummary student) {
    final progress = (student.completionPercentage / 100).clamp(0.0, 1.0);
    final isExporting = _exportingStudentIds.contains(student.studentId);
    final issues = <Widget>[
      if (!student.hasInternshipProfile)
        buildStatusBadge(
          label: 'Missing internship profile',
          backgroundColor: const Color(0xFFFFF4E5),
          foregroundColor: const Color(0xFFB54708),
        ),
      if (student.hasInternshipProfile && !student.hasSupervisor)
        buildStatusBadge(
          label: 'No supervisor assigned',
          backgroundColor: const Color(0xFFE8F1FF),
          foregroundColor: const Color(0xFF175CD3),
        ),
      if (student.hasInternshipProfile && !student.hasAdviser)
        buildStatusBadge(
          label: 'No adviser assigned',
          backgroundColor: const Color(0xFFF1EBFF),
          foregroundColor: const Color(0xFF6941C6),
        ),
      if (student.hasInternshipProfile &&
          student.hasSupervisor &&
          student.hasAdviser)
        buildStatusBadge(
          label: 'Setup complete',
          backgroundColor: const Color(0xFFE7F6EC),
          foregroundColor: const Color(0xFF067647),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: issues),
                  ],
                ),
              ),
              if (student.hasInternshipProfile &&
                  (!student.hasAdviser || !student.hasSupervisor))
                TextButton.icon(
                  onPressed: _openAdviserAssignment,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    !student.hasSupervisor && !student.hasAdviser
                        ? 'Assign Roles'
                        : (!student.hasSupervisor
                              ? 'Assign Supervisor'
                              : 'Assign Adviser'),
                  ),
                  style: TextButton.styleFrom(foregroundColor: _brandPrimary),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFDCE3EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _brandSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${student.completionPercentage.round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _brandSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              buildStudentMeta(
                icon: Icons.business_outlined,
                label: 'Company',
                value: student.company?.isNotEmpty == true
                    ? student.company!
                    : 'Not assigned yet',
              ),
              buildStudentMeta(
                icon: Icons.schedule_rounded,
                label: 'Approved Hours',
                value: '${student.approvedHours} / ${student.requiredHours}',
              ),
              OutlinedButton.icon(
                onPressed: isExporting
                    ? null
                    : () => _exportStudentDtr(student),
                icon: isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(isExporting ? 'Exporting...' : 'Export DTR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brandPrimary,
                  side: const BorderSide(color: Color(0xFFC5D4EA)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStudentMeta({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _brandPrimary),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatusBadge({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

<<<<<<< HEAD
  List<int> visiblePages(bool isCompact) {
=======
  Widget _buildManagedUserSection() {
    final filteredUsers = _filteredManagedUsers;
    final paginatedUsers = _paginatedManagedUsers;
    final totalUsers = filteredUsers.length;
    final startItem = totalUsers == 0
        ? 0
        : ((_managedUsersPage - 1) * _managedUsersPerPage) + 1;
    final endItem = (_managedUsersPage * _managedUsersPerPage).clamp(
      0,
      totalUsers,
    );
    final roleFilters = <_ManagedRoleFilter>[
      _ManagedRoleFilter(
        key: _userRoleAll,
        label: 'All Users',
        count: _managedUsers.length,
      ),
      _ManagedRoleFilter(
        key: 'Student',
        label: 'Students',
        count: _managedUserCountForRole('Student'),
      ),
      _ManagedRoleFilter(
        key: 'Adviser',
        label: 'Advisers',
        count: _managedUserCountForRole('Adviser'),
      ),
      _ManagedRoleFilter(
        key: 'Supervisor',
        label: 'Supervisors',
        count: _managedUserCountForRole('Supervisor'),
      ),
    ];

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add or remove student, adviser, and supervisor accounts directly from the admin workspace.',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_userManagementError != null) ...[
            const SizedBox(height: 14),
            Text(
              _userManagementError!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 860;

              return Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: stacked ? 0 : 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: stacked ? constraints.maxWidth : 460,
                        ),
                        child: TextField(
                          controller: _managedUserSearchController,
                          onChanged: _updateManagedUserSearch,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: 'Search user',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            suffixIcon: _userSearchQuery.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _managedUserSearchController.clear();
                                      _updateManagedUserSearch('');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFD7E4F4),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: Color(0xFFD7E4F4),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: _brandPrimary,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!stacked) const SizedBox(width: 12),
                  if (stacked) const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD7E4F4)),
                    ),
                    child: Text(
                      '$startItem-$endItem of $totalUsers users',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: roleFilters.map((filter) {
              final selected = _selectedUserRoleFilter == filter.key;
              return ChoiceChip(
                label: Text('${filter.label} (${filter.count})'),
                selected: selected,
                onSelected: (_) => _updateManagedUserRoleFilter(filter.key),
                backgroundColor: const Color(0xFFF8FAFC),
                selectedColor: const Color(0xFFDCEBFF),
                side: BorderSide(
                  color: selected ? _brandPrimary : const Color(0xFFD0D5DD),
                ),
                labelStyle: TextStyle(
                  color: selected ? _brandPrimary : const Color(0xFF475467),
                  fontWeight: FontWeight.w800,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 980;
              final itemWidth = isCompact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;

              if (paginatedUsers.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBFDFF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _userSearchQuery.trim().isEmpty
                        ? 'No users matched this filter.'
                        : 'No users matched "${_userSearchQuery.trim()}".',
                    style: const TextStyle(fontSize: 14, color: _textSecondary),
                  ),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: paginatedUsers.map((user) {
                  return SizedBox(
                    width: itemWidth,
                    child: _buildManagedUserTile(user),
                  );
                }).toList(),
              );
            },
          ),
          if (filteredUsers.isNotEmpty) ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) =>
                  _buildManagedUserPaginationControls(constraints, totalUsers),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagedUserTile(AppUser user) {
    final isDeleting = _deletingUserIds.contains(user.id);
    final roleMeta = _managedRoleMeta(user.role);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FF),
                child: Text(
                  _initialsFor(user.name),
                  style: const TextStyle(
                    color: _brandPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove user',
                onPressed: isDeleting
                    ? null
                    : () => _confirmDeleteManagedUser(user),
                icon: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFB42318),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusBadge(
                label: roleMeta.label,
                backgroundColor: roleMeta.background,
                foregroundColor: roleMeta.foreground,
              ),
              _buildStatusBadge(
                label: 'Account #${user.id}',
                backgroundColor: const Color(0xFFF2F4F7),
                foregroundColor: const Color(0xFF344054),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.email,
            style: const TextStyle(fontSize: 13, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  _ManagedRoleMeta _managedRoleMeta(String role) {
    switch (role) {
      case 'Student':
        return const _ManagedRoleMeta(
          label: 'Student',
          background: Color(0xFFE8F1FF),
          foreground: Color(0xFF175CD3),
        );
      case 'Adviser':
        return const _ManagedRoleMeta(
          label: 'Adviser',
          background: Color(0xFFF1EBFF),
          foreground: Color(0xFF6941C6),
        );
      case 'Supervisor':
        return const _ManagedRoleMeta(
          label: 'Supervisor',
          background: Color(0xFFE7F6EC),
          foreground: Color(0xFF067647),
        );
      default:
        return const _ManagedRoleMeta(
          label: 'User',
          background: Color(0xFFF2F4F7),
          foreground: Color(0xFF344054),
        );
    }
  }

  Widget _buildManagedUserPaginationControls(
    BoxConstraints constraints,
    int totalUsers,
  ) {
    final isCompact = constraints.maxWidth < 600;
    final visiblePages = _visibleManagedUserPages(isCompact);
    final startItem = totalUsers == 0
        ? 0
        : ((_managedUsersPage - 1) * _managedUsersPerPage) + 1;
    final endItem = (_managedUsersPage * _managedUsersPerPage).clamp(
      0,
      totalUsers,
    );

    if (isCompact) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildArrowButton(
                icon: Icons.chevron_left_rounded,
                compact: true,
                onPressed: _managedUsersPage > 1
                    ? () => _goToManagedUsersPage(_managedUsersPage - 1)
                    : null,
              ),
              ...visiblePages.map(
                (page) => _buildPageButton(
                  page: page,
                  selected: page == _managedUsersPage,
                  compact: true,
                  onTap: () => _goToManagedUsersPage(page),
                ),
              ),
              _buildArrowButton(
                icon: Icons.chevron_right_rounded,
                compact: true,
                onPressed: _managedUsersPage < _managedUsersLastPage
                    ? () => _goToManagedUsersPage(_managedUsersPage + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$startItem-$endItem of $totalUsers users',
            style: const TextStyle(fontSize: 14, color: _textSecondary),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 10,
      children: [
        _buildArrowButton(
          icon: Icons.keyboard_double_arrow_left_rounded,
          onPressed: _managedUsersPage > 1
              ? () => _goToManagedUsersPage(1)
              : null,
        ),
        _buildArrowButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _managedUsersPage > 1
              ? () => _goToManagedUsersPage(_managedUsersPage - 1)
              : null,
        ),
        ...visiblePages.map(
          (page) => _buildPageButton(
            page: page,
            selected: page == _managedUsersPage,
            compact: false,
            onTap: () => _goToManagedUsersPage(page),
          ),
        ),
        _buildArrowButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _managedUsersPage < _managedUsersLastPage
              ? () => _goToManagedUsersPage(_managedUsersPage + 1)
              : null,
        ),
        _buildArrowButton(
          icon: Icons.keyboard_double_arrow_right_rounded,
          onPressed: _managedUsersPage < _managedUsersLastPage
              ? () => _goToManagedUsersPage(_managedUsersLastPage)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          '$startItem-$endItem of $totalUsers users',
          style: const TextStyle(fontSize: 16, color: _textSecondary),
        ),
      ],
    );
  }

  List<int> _visiblePages(bool isCompact) {
>>>>>>> 1822302 (admin user management)
    if (_lastPage <= 1) {
      return const <int>[1];
    }

    if (isCompact) {
      final pages = <int>{_currentPage};
      if (_currentPage > 1) {
        pages.add(_currentPage - 1);
      }
      if (_currentPage < _lastPage) {
        pages.add(_currentPage + 1);
      }
      final sorted = pages.toList()..sort();
      return sorted;
    }

    final start = (_currentPage - 2).clamp(1, _lastPage);
    final end = (_currentPage + 2).clamp(1, _lastPage);
    final pages = <int>[];
    for (var page = start; page <= end; page++) {
      pages.add(page);
    }
    return pages;
  }

  Widget buildPageButton({
    required int page,
    required bool selected,
    required bool compact,
    VoidCallback? onTap,
  }) {
    final size = compact ? 40.0 : 42.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: _isPageLoading ? null : (onTap ?? () => _goToPage(page)),
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _brandPrimary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xFF344054),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool compact = false,
  }) {
    return IconButton(
      tooltip: compact ? null : 'Pagination',
      onPressed: _isPageLoading ? null : onPressed,
      icon: Icon(
        icon,
        color: onPressed == null
            ? const Color(0xFF98A2B3)
            : const Color(0xFF101828),
      ),
    );
  }

  Widget buildPaginationControls(BoxConstraints constraints) {
    if (_students.isEmpty && _totalStudents == 0) {
      return const SizedBox.shrink();
    }

    final isCompact = constraints.maxWidth < 600;
    final pagesToShow = visiblePages(isCompact);
    final startItem = _totalStudents == 0
        ? 0
        : ((_currentPage - 1) * _itemsPerPage) + 1;
    final endItem = (_currentPage * _itemsPerPage).clamp(0, _totalStudents);

    if (isCompact) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildArrowButton(
                icon: Icons.chevron_left_rounded,
                compact: true,
                onPressed: _currentPage > 1
                    ? () => _goToPage(_currentPage - 1)
                    : null,
              ),
              ...pagesToShow.map(
                (page) => buildPageButton(
                  page: page,
                  selected: page == _currentPage,
                  compact: true,
                ),
              ),
              buildArrowButton(
                icon: Icons.chevron_right_rounded,
                compact: true,
                onPressed: _currentPage < _lastPage
                    ? () => _goToPage(_currentPage + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$startItem-$endItem of $_totalStudents items',
            style: const TextStyle(fontSize: 14, color: _textSecondary),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 10,
      children: [
        buildArrowButton(
          icon: Icons.keyboard_double_arrow_left_rounded,
          onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
        ),
        buildArrowButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _currentPage > 1
              ? () => _goToPage(_currentPage - 1)
              : null,
        ),
        ...pagesToShow.map(
          (page) => buildPageButton(
            page: page,
            selected: page == _currentPage,
            compact: false,
          ),
        ),
        buildArrowButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _currentPage < _lastPage
              ? () => _goToPage(_currentPage + 1)
              : null,
        ),
        buildArrowButton(
          icon: Icons.keyboard_double_arrow_right_rounded,
          onPressed: _currentPage < _lastPage
              ? () => _goToPage(_lastPage)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          '$startItem-$endItem of $_totalStudents items',
          style: const TextStyle(fontSize: 16, color: _textSecondary),
        ),
      ],
    );
  }

  Widget buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null &&
        _students.isEmpty &&
        _dashboardSummary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: buildSectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _refreshDashboard,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final summary = _dashboardSummary;
    final filteredStudents = _filteredStudents;

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            if (summary != null) buildHeroCard(summary),
            if (summary != null) ...[
              const SizedBox(height: 22),
              buildSummaryGrid(summary),
              const SizedBox(height: 22),
              buildActionPanel(summary),
            ],
            const SizedBox(height: 22),
<<<<<<< HEAD
            buildSectionCard(
=======
            _buildManagedUserSection(),
            const SizedBox(height: 22),
            _buildSectionCard(
>>>>>>> 1822302 (admin user management)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Student Operations',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Review the current page of students, filter unresolved setup issues, and jump into adviser assignment when needed.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  buildFilterChips(),
                  const SizedBox(height: 20),
                  if (filteredStudents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                        'No students matched this filter on the current page.',
                        style: TextStyle(fontSize: 15, color: _textSecondary),
                      ),
                    )
                  else
                    ...filteredStudents.map(buildStudentCard),
                  if (_errorMessage != null &&
                      (_students.isNotEmpty || _dashboardSummary != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFB42318)),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  _loadDashboard(page: _currentPage),
                              child: const Text('Try loading again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_isPageLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_students.isNotEmpty || _totalStudents > 0) ...[
                    const SizedBox(height: 10),
                    buildPaginationControls(constraints),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 240,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF0F2D57),
                    Color(0xFF0E5A6A),
                    Color(0xFF3B82F6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: 160,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: -20,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                buildHeader(authProvider),
                Expanded(child: buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _StudentFilter {
  final String key;
  final String label;

  const _StudentFilter({required this.key, required this.label});
}

class _ManagedUserDraft {
  final String name;
  final String email;
  final String password;
  final String role;

  const _ManagedUserDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });
}

class _ManagedRoleFilter {
  final String key;
  final String label;
  final int count;

  const _ManagedRoleFilter({
    required this.key,
    required this.label,
    required this.count,
  });
}

class _ManagedRoleMeta {
  final String label;
  final Color background;
  final Color foreground;

  const _ManagedRoleMeta({
    required this.label,
    required this.background,
    required this.foreground,
  });
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/supervisor_log_service.dart';
import '../../../../shared/models/supervisor_log_item.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'supervisor_log_detail_screen.dart';

typedef SupervisorLogReviewScreenBuilder =
    Widget Function(
      BuildContext context,
      SupervisorLogItem log,
      SupervisorLogService service,
    );

class SupervisorPendingLogsScreen extends SupervisorLogQueueScreen {
  const SupervisorPendingLogsScreen({
    super.key,
    super.service,
    super.reviewScreenBuilder,
  });
}

class SupervisorLogQueueScreen extends StatefulWidget {
  final SupervisorLogService? service;
  final SupervisorLogReviewScreenBuilder? reviewScreenBuilder;

  const SupervisorLogQueueScreen({
    super.key,
    this.service,
    this.reviewScreenBuilder,
  });

  @override
  State<SupervisorLogQueueScreen> createState() =>
      _SupervisorLogQueueScreenState();
}

class _SupervisorLogQueueScreenState extends State<SupervisorLogQueueScreen> {
  static const Color _canvasColor = Color(0xFFF5F1EB);
  static const Color _panelColor = Colors.white;
  static const Color _panelSoft = Color(0xFFFAF7F2);
  static const Color _panelBorder = Color(0xFFE7DDD2);
  static const Color _headlineColor = Color(0xFF2F312B);
  static const Color _bodyColor = Color(0xFF6C6257);
  static const Color _accentPrimary = Color(0xFF9A5F3F);
  static const Color _accentSecondary = Color(0xFF55756A);
  static const Color _accentSoft = Color(0xFFF0E2D2);
  static const Color _accentSoftAlt = Color(0xFFE6EFEA);

  late final SupervisorLogService _service;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<SupervisorLogItem> _logs = <SupervisorLogItem>[];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? SupervisorLogService(context.read<ApiClient>());
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleExpiredSession() async {
    final authProvider = Provider.of<AuthProvider?>(context, listen: false);
    await authProvider?.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has expired. Please log in again.'),
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = (await _service.getPendingLogs())
          .where((log) => log.isPending)
          .toList();

      logs.sort((a, b) {
        final aTimestamp =
            DateTime.tryParse(a.submittedAt ?? '') ?? DateTime.tryParse(a.date);
        final bTimestamp =
            DateTime.tryParse(b.submittedAt ?? '') ?? DateTime.tryParse(b.date);

        if (aTimestamp != null && bTimestamp != null) {
          final cmp = bTimestamp.compareTo(aTimestamp);
          if (cmp != 0) return cmp;
        } else if (aTimestamp != null) {
          return -1;
        } else if (bTimestamp != null) {
          return 1;
        }

        return b.id.compareTo(a.id);
      });

      if (!mounted) return;

      setState(() {
        _logs = logs;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
        await _handleExpiredSession();
        return;
      }

      setState(() {
        _errorMessage = _readErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _readErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openLogDetails(SupervisorLogItem log) async {
    final reviewScreenBuilder =
        widget.reviewScreenBuilder ?? _defaultReviewScreenBuilder;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => reviewScreenBuilder(context, log, _service),
      ),
    );

    if (updated == true) {
      await _loadLogs();
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _panelBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _accentPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load pending logs.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _headlineColor,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadLogs,
              style: FilledButton.styleFrom(
                backgroundColor: _accentPrimary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _readErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Widget _buildEmptyState() {
    final message = _searchQuery.trim().isEmpty
        ? 'No pending logs to review.'
        : 'No pending logs matched your search.';
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _panelBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _panelSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _searchQuery.trim().isEmpty
                    ? Icons.task_alt_rounded
                    : Icons.search_off_rounded,
                color: _accentPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.trim().isEmpty
                  ? 'All caught up'
                  : 'No results found',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _headlineColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _bodyColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SupervisorLogItem> get _filteredLogs {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _logs;

    return _logs.where((log) {
      return log.studentName.toLowerCase().contains(query) ||
          log.date.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search by student or date',
        prefixIcon: const Icon(Icons.search, color: _accentPrimary),
        suffixIcon: _searchQuery.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                  _searchController.clear();
                },
                icon: const Icon(Icons.close),
                tooltip: 'Clear search',
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        filled: true,
        fillColor: _panelColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _accentPrimary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildLogCard(SupervisorLogItem log) {
    final dateLabel = _formatDate(log.date);

    return Card(
      color: _panelColor,
      surfaceTintColor: _panelColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: _panelBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _openLogDetails(log),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _headlineColor,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((log.companyName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.companyName!,
                      style: const TextStyle(
                        color: _accentSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _panelSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$dateLabel\n${_formatHours(log.hoursRendered)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _headlineColor,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Pending approval',
                  style: TextStyle(
                    color: _accentPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (log.taskDescription.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  log.taskDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _bodyColor,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: const Text('Pending review'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _panelSoft,
                    side: const BorderSide(color: _panelBorder),
                    labelStyle: const TextStyle(
                      color: _headlineColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      log.hasAttachments
                          ? Icons.attach_file_rounded
                          : Icons.hide_image_outlined,
                      size: 16,
                      color: log.hasAttachments ? _accentSecondary : _bodyColor,
                    ),
                    label: Text(log.hasAttachments ? 'With Proof' : 'No Proof'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: log.hasAttachments
                        ? _accentSoftAlt
                        : _panelSoft,
                    side: const BorderSide(color: _panelBorder),
                    labelStyle: TextStyle(
                      color: log.hasAttachments ? _accentSecondary : _bodyColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _panelSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.chevron_right_rounded, color: _accentPrimary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('MMM d').format(parsed.toLocal());
  }

  String _formatHours(int hours) {
    return hours == 1 ? '1 hr' : '$hours hrs';
  }

  Widget _defaultReviewScreenBuilder(
    BuildContext context,
    SupervisorLogItem log,
    SupervisorLogService service,
  ) {
    return SupervisorLogDetailScreen(
      logId: log.id,
      initialLog: log,
      service: service,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasColor,
      appBar: AppBar(
        backgroundColor: _canvasColor,
        surfaceTintColor: _canvasColor,
        title: const Text('Pending Logs'),
        actions: [
          IconButton(
            onPressed: _loadLogs,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    decoration: BoxDecoration(
                      color: _panelColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Queue',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _headlineColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_filteredLogs.length} pending log${_filteredLogs.length == 1 ? '' : 's'} ready for review.',
                          style: const TextStyle(
                            color: _bodyColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSearchField(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredLogs.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadLogs,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredLogs.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) =>
                                  _buildLogCard(_filteredLogs[index]),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

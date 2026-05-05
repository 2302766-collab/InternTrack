import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/supervisor_log_service.dart';
import '../../../../shared/models/supervisor_log_item.dart';
import 'supervisor_log_detail_screen.dart';

typedef SupervisorLogReviewScreenBuilder =
    Widget Function(
      BuildContext context,
      SupervisorLogItem log,
      SupervisorLogService service,
      String token,
    );

class SupervisorPendingLogsScreen extends SupervisorLogQueueScreen {
  const SupervisorPendingLogsScreen({
    super.key,
    required super.token,
    super.service,
    super.reviewScreenBuilder,
  });
}

class SupervisorLogQueueScreen extends StatefulWidget {
  final String token;
  final SupervisorLogService? service;
  final SupervisorLogReviewScreenBuilder? reviewScreenBuilder;

  const SupervisorLogQueueScreen({
    super.key,
    required this.token,
    this.service,
    this.reviewScreenBuilder,
  });

  @override
  State<SupervisorLogQueueScreen> createState() =>
      _SupervisorLogQueueScreenState();
}

class _SupervisorLogQueueScreenState extends State<SupervisorLogQueueScreen> {
  late final SupervisorLogService _service;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<SupervisorLogItem> _logs = <SupervisorLogItem>[];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SupervisorLogService(context.read<ApiClient>());
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        final aDate = DateTime.tryParse(a.date);
        final bDate = DateTime.tryParse(b.date);
        if (aDate != null && bDate != null) {
          final cmp = aDate.compareTo(bDate);
          if (cmp != 0) return cmp;
        }
        return a.id.compareTo(b.id);
      });

      if (!mounted) return;

      setState(() {
        _logs = logs;
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
        builder: (context) =>
            reviewScreenBuilder(context, log, _service, widget.token),
      ),
    );

    if (updated == true) {
      await _loadLogs();
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage ?? 'Failed to load pending logs.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadLogs, child: const Text('Retry')),
        ],
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
    return Center(child: Text(message));
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
        prefixIcon: const Icon(Icons.search),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildLogCard(SupervisorLogItem log) {
    final dateLabel = _formatDate(log.date);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _openLogDetails(log),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Student: ${log.studentName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$dateLabel (${_formatHours(log.hoursRendered)})',
              style: const TextStyle(
                color: Color(0xFF526171),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Status: ${log.status.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFFB54708),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (log.taskDescription.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  log.taskDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: const Text('Pending review'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFFFFF7E6),
                  ),
                  Chip(
                    avatar: Icon(
                      log.hasAttachments
                          ? Icons.attach_file_rounded
                          : Icons.hide_image_outlined,
                      size: 16,
                    ),
                    label: Text(
                      log.hasAttachments ? 'With Proof' : 'No Proof',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    String token,
  ) {
    return SupervisorLogDetailScreen(
      token: token,
      logId: log.id,
      initialLog: log,
      service: service,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : Column(
                children: [
                  _buildSearchField(),
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

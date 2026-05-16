import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/supervisor_log_service.dart';
import '../../../../shared/models/supervisor_log_item.dart';
import '../../../../shared/utils/session_expired_handler.dart';
import 'supervisor_log_detail_screen.dart';

typedef SupervisorLogReviewScreenBuilder =
    Widget Function(
      BuildContext context,
      SupervisorLogItem log,
      SupervisorLogService service,
    );

enum _ProofFilter { all, withProof, withoutProof }

enum _QueueSortOption { newestPending, oldestPending, mostHours, leastHours }

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
  late final SupervisorLogService _service;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minHoursController = TextEditingController();
  final TextEditingController _maxHoursController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<SupervisorLogItem> _logs = <SupervisorLogItem>[];
  String _searchQuery = '';
  String _minHoursQuery = '';
  String _maxHoursQuery = '';
  _ProofFilter _proofFilter = _ProofFilter.all;
  _QueueSortOption? _sortOption;

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
    _minHoursController.dispose();
    _maxHoursController.dispose();
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
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
        await handleExpiredSession(context);
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
    final message = _hasActiveFilters
        ? 'No pending logs match the current filters.'
        : 'No pending logs to review.';
    return Center(child: Text(message));
  }

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _proofFilter != _ProofFilter.all ||
        _sortOption != null ||
        _minHoursQuery.trim().isNotEmpty ||
        _maxHoursQuery.trim().isNotEmpty;
  }

  _HoursRange get _hoursRange {
    final min = _tryParseHours(_minHoursQuery);
    final max = _tryParseHours(_maxHoursQuery);

    if (min != null && max != null && min > max) {
      return const _HoursRange();
    }

    return _HoursRange(min: min, max: max);
  }

  bool get _hasInvalidHoursRange {
    final min = _tryParseHours(_minHoursQuery);
    final max = _tryParseHours(_maxHoursQuery);
    return min != null && max != null && min > max;
  }

  List<SupervisorLogItem> get _processedLogs {
    final query = _searchQuery.trim().toLowerCase();
    final hoursRange = _hoursRange;

    final logs = _logs.where((log) {
      if (query.isNotEmpty && !_matchesSearch(log, query)) {
        return false;
      }

      if (!_matchesProofFilter(log)) {
        return false;
      }

      final hours = log.hoursRendered.toDouble();
      if (hoursRange.min != null && hours < hoursRange.min!) {
        return false;
      }
      if (hoursRange.max != null && hours > hoursRange.max!) {
        return false;
      }

      return true;
    }).toList();

    _applySort(logs);
    return logs;
  }

  bool _matchesSearch(SupervisorLogItem log, String query) {
    return log.studentName.toLowerCase().contains(query) ||
        log.date.toLowerCase().contains(query) ||
        _formatDate(log.date).toLowerCase().contains(query);
  }

  bool _matchesProofFilter(SupervisorLogItem log) {
    switch (_proofFilter) {
      case _ProofFilter.all:
        return true;
      case _ProofFilter.withProof:
        return log.hasAttachments;
      case _ProofFilter.withoutProof:
        return !log.hasAttachments;
    }
  }

  void _applySort(List<SupervisorLogItem> logs) {
    switch (_sortOption) {
      case _QueueSortOption.newestPending:
        logs.sort(_compareByNewest);
        break;
      case _QueueSortOption.oldestPending:
        logs.sort(_compareByOldest);
        break;
      case _QueueSortOption.mostHours:
        logs.sort((a, b) {
          final cmp = b.hoursRendered.compareTo(a.hoursRendered);
          if (cmp != 0) return cmp;
          return _compareByOldest(a, b);
        });
        break;
      case _QueueSortOption.leastHours:
        logs.sort((a, b) {
          final cmp = a.hoursRendered.compareTo(b.hoursRendered);
          if (cmp != 0) return cmp;
          return _compareByOldest(a, b);
        });
        break;
      case null:
        break;
    }
  }

  int _compareByNewest(SupervisorLogItem a, SupervisorLogItem b) {
    final cmp = _compareParsedDates(a.date, b.date);
    if (cmp != 0) return -cmp;
    return b.id.compareTo(a.id);
  }

  int _compareByOldest(SupervisorLogItem a, SupervisorLogItem b) {
    final cmp = _compareParsedDates(a.date, b.date);
    if (cmp != 0) return cmp;
    return a.id.compareTo(b.id);
  }

  int _compareParsedDates(String a, String b) {
    final aDate = DateTime.tryParse(a);
    final bDate = DateTime.tryParse(b);

    if (aDate != null && bDate != null) {
      return aDate.compareTo(bDate);
    }
    if (aDate != null) return -1;
    if (bDate != null) return 1;
    return a.compareTo(b);
  }

  double? _tryParseHours(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _minHoursQuery = '';
      _maxHoursQuery = '';
      _proofFilter = _ProofFilter.all;
      _sortOption = null;
      _searchController.clear();
      _minHoursController.clear();
      _maxHoursController.clear();
    });
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildProofFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _proofFilter == _ProofFilter.all,
          onSelected: (_) {
            setState(() {
              _proofFilter = _ProofFilter.all;
            });
          },
        ),
        FilterChip(
          label: const Text('With Proof'),
          selected: _proofFilter == _ProofFilter.withProof,
          onSelected: (_) {
            setState(() {
              _proofFilter = _ProofFilter.withProof;
            });
          },
        ),
        FilterChip(
          label: const Text('Without Proof'),
          selected: _proofFilter == _ProofFilter.withoutProof,
          onSelected: (_) {
            setState(() {
              _proofFilter = _ProofFilter.withoutProof;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSortField() {
    return DropdownButtonFormField<_QueueSortOption>(
      isExpanded: true,
      initialValue: _sortOption,
      hint: const Text('Original order'),
      decoration: InputDecoration(
        labelText: 'Sort',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: const [
        DropdownMenuItem(
          value: _QueueSortOption.newestPending,
          child: Text('Newest Pending'),
        ),
        DropdownMenuItem(
          value: _QueueSortOption.oldestPending,
          child: Text('Oldest Pending'),
        ),
        DropdownMenuItem(
          value: _QueueSortOption.mostHours,
          child: Text('Most Hours'),
        ),
        DropdownMenuItem(
          value: _QueueSortOption.leastHours,
          child: Text('Least Hours'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _sortOption = value;
        });
      },
    );
  }

  Widget _buildHoursField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Optional',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final useWideControls = maxWidth >= 900;
        final useSplitHoursFields = maxWidth >= 640;
        final sortWidth = useWideControls ? 260.0 : maxWidth;
        final hoursWidth = useWideControls
            ? 180.0
            : useSplitHoursFields
            ? (maxWidth - 12) / 2
            : maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchField(),
            const SizedBox(height: 12),
            Text(
              'Proof Status',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _buildProofFilterChips(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: sortWidth, child: _buildSortField()),
                SizedBox(
                  width: hoursWidth,
                  child: _buildHoursField(
                    controller: _minHoursController,
                    label: 'Min hours',
                    onChanged: (value) {
                      setState(() {
                        _minHoursQuery = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: hoursWidth,
                  child: _buildHoursField(
                    controller: _maxHoursController,
                    label: 'Max hours',
                    onChanged: (value) {
                      setState(() {
                        _maxHoursQuery = value;
                      });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _hasActiveFilters ? _resetFilters : null,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset Filters'),
                ),
              ],
            ),
            if (_hasInvalidHoursRange) ...[
              const SizedBox(height: 8),
              Text(
                'Min hours is greater than max hours, so the hour range is being ignored.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFB54708)),
              ),
            ],
          ],
        );
      },
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
                    label: Text(log.hasAttachments ? 'With Proof' : 'No Proof'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
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
    final processedLogs = _processedLogs;

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
                  _buildControls(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: processedLogs.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadLogs,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: processedLogs.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) =>
                                  _buildLogCard(processedLogs[index]),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HoursRange {
  final double? min;
  final double? max;

  const _HoursRange({this.min, this.max});
}

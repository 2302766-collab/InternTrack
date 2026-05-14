import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/intern_list_service.dart';
import '../../../../shared/utils/session_expired_handler.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/models/intern_list_item.dart';
import 'intern_detail_screen.dart';

class InternListScreen extends StatefulWidget {
  final String token;
  final String role;
  final InternListService? service;

  const InternListScreen({
    super.key,
    required this.token,
    required this.role,
    this.service,
  });

  @override
  State<InternListScreen> createState() => _InternListScreenState();
}

class _InternListScreenState extends State<InternListScreen> {
  late final InternListService _service;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  static const int _perPage = 20;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _loadMoreError;
  List<InternListItem> _interns = [];
  String _searchQuery = '';
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _hasMorePages = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? InternListService(context.read<ApiClient>());
    _loadInterns();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInterns({bool reset = true}) async {
    if (!reset && (_isLoadingMore || !_hasMorePages)) return;

    setState(() {
      if (reset) {
        _isLoading = true;
        _errorMessage = null;
        _loadMoreError = null;
        _interns = [];
        _currentPage = 1;
        _lastPage = 1;
        _total = 0;
        _hasMorePages = false;
      } else {
        _isLoadingMore = true;
        _loadMoreError = null;
      }
    });

    final requestedPage = reset ? 1 : _currentPage + 1;

    try {
      final page = await _service.getInternPage(
        role: widget.role,
        page: requestedPage,
        perPage: _perPage,
        search: _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _interns = page.interns;
          } else {
            final existingIds = _interns.map((intern) => intern.id).toSet();
            _interns = [
              ..._interns,
              ...page.interns.where(
                (intern) => !existingIds.contains(intern.id),
              ),
            ];
          }
          _currentPage = page.currentPage;
          _lastPage = page.lastPage;
          _total = page.total;
          _hasMorePages = page.hasMorePages;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 401 || e.errorType == ApiErrorType.unauthorized) {
          await handleExpiredSession(context);
          return;
        }

        setState(() {
          final message = e.message;
          if (reset) {
            _errorMessage = message;
          } else {
            _loadMoreError = message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final message = e.toString().replaceFirst('Exception: ', '');
          if (reset) {
            _errorMessage = message;
          } else {
            _loadMoreError = message;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (reset) {
            _isLoading = false;
          } else {
            _isLoadingMore = false;
          }
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _loadInterns();
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _loadInterns();
  }

  Widget _buildEmptyState() {
    final message = _searchQuery.trim().isEmpty
        ? 'No assigned interns found.'
        : 'No interns matched your search.';
    return Center(child: Text(message));
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _loadInterns(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      onSubmitted: (_) {
        _searchDebounce?.cancel();
        _loadInterns();
      },
      decoration: InputDecoration(
        hintText: 'Search by student or company',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.trim().isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
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

  Widget _buildListView() {
    return ListView.separated(
      key: const PageStorageKey<String>('intern-list-scroll'),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _interns.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _interns.length) {
          return _buildPaginationFooter();
        }

        final intern = _interns[index];

        return _InternProgressCard(
          intern: intern,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InternDetailScreen(
                  token: widget.token,
                  role: widget.role,
                  profileId: intern.id,
                  initialIntern: intern,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaginationFooter() {
    if (_interns.isEmpty) return const SizedBox.shrink();

    final showingText = _total > 0
        ? 'Showing ${_interns.length} of $_total interns'
        : 'Showing ${_interns.length} interns';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Text(
            showingText,
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          if (_loadMoreError != null) ...[
            const SizedBox(height: 8),
            Text(
              _loadMoreError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _loadInterns(reset: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ] else if (_hasMorePages) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoadingMore
                  ? null
                  : () => _loadInterns(reset: false),
              icon: _isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                       child: CircularProgressIndicator(strokeWidth: 2),
                     )
                  : const Icon(Icons.expand_more),
              label: Text(_isLoadingMore ? 'Loading...' : 'Load More'),
            ),
          ] else if (_lastPage > 1) ...[
            const SizedBox(height: 8),
            const Text(
              'All interns loaded.',
              style: TextStyle(color: Color(0xFF667085)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleTitle = widget.role.isNotEmpty
        ? '${widget.role[0].toUpperCase()}${widget.role.substring(1).toLowerCase()} Interns'
        : 'Intern List';

    return Scaffold(
      appBar: AppBar(title: Text(roleTitle)),
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
                    child: _interns.isEmpty
                        ? _buildEmptyState()
                        : _buildListView(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InternProgressCard extends StatelessWidget {
  final InternListItem intern;
  final VoidCallback onTap;

  const _InternProgressCard({
    required this.intern,
    required this.onTap,
  });

  Color get _progressColor {
    if (intern.progressFraction >= 1) {
      return const Color(0xFF039855);
    }

    if (intern.progressFraction >= 0.6) {
      return const Color(0xFF2563EB);
    }

    return const Color(0xFFB54708);
  }

  Color get _alertColor {
    switch (intern.alertSeverity.toLowerCase()) {
      case 'error':
      case 'danger':
        return const Color(0xFFB42318);
      case 'warning':
        return const Color(0xFFB54708);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String? get _scheduleLabel {
    final startDate = (intern.startDate ?? '').trim();
    final endDate = (intern.endDate ?? '').trim();
    if (startDate.isEmpty || endDate.isEmpty) {
      return null;
    }

    return '${DateFormatter.formatApiDate(startDate)} to ${DateFormatter.formatApiDate(endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          intern.studentName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF16354D),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Company: ${intern.companyName}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF526072),
                          ),
                        ),
                        if (_scheduleLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Schedule: $_scheduleLabel',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _progressColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${intern.progressPercentage}%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _progressColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 12,
                  value: intern.progressFraction,
                  backgroundColor: const Color(0xFFE4E7EC),
                  valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Approved ${intern.completedHours} of ${intern.requiredHours} hours',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF344054),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${intern.remainingHours}h remaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF667085),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InternStatChip(
                    label: 'Approved',
                    value: intern.approvedLogs.toString(),
                    textColor: const Color(0xFF027A48),
                    backgroundColor: const Color(0xFFE8F7EE),
                  ),
                  _InternStatChip(
                    label: 'Pending',
                    value: intern.pendingLogs.toString(),
                    textColor: const Color(0xFFB54708),
                    backgroundColor: const Color(0xFFFFF4E5),
                  ),
                  _InternStatChip(
                    label: 'Rejected',
                    value: intern.rejectedLogs.toString(),
                    textColor: const Color(0xFFB42318),
                    backgroundColor: const Color(0xFFFEECEE),
                  ),
                ],
              ),
              if (intern.hasActiveAlert) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _alertColor.withAlpha(14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _alertColor.withAlpha(36)),
                  ),
                  child: Text(
                    intern.alertMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _alertColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InternStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color backgroundColor;

  const _InternStatChip({
    required this.label,
    required this.value,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

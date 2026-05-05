import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/intern_list_service.dart';
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
  static const int _perPage = 10;

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
      itemCount: _interns.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final intern = _interns[index];

        return Card(
          child: ListTile(
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
            title: Text(intern.studentName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Company: ${intern.companyName}'),
                Text('Required Hours: ${intern.requiredHours}'),
                if ((intern.startDate ?? '').isNotEmpty &&
                    (intern.endDate ?? '').isNotEmpty)
                  Text('Schedule: ${intern.startDate} to ${intern.endDate}'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
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
      padding: const EdgeInsets.only(top: 12),
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
              label: Text(_isLoadingMore ? 'Loading...' : 'Load more'),
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
                  _buildPaginationFooter(),
                ],
              ),
      ),
    );
  }
}

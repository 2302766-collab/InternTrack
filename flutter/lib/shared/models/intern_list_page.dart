import 'intern_list_item.dart';

class InternListPage {
  final List<InternListItem> interns;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMorePages;

  const InternListPage({
    required this.interns,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMorePages,
  });

  factory InternListPage.fromJson(
    Map<String, dynamic> json, {
    required int fallbackPage,
    required int fallbackPerPage,
  }) {
    final rawData = json['data'];
    final interns = rawData is List
        ? rawData
              .whereType<Map<String, dynamic>>()
              .map(InternListItem.fromJson)
              .toList()
        : <InternListItem>[];

    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return InternListPage(
      interns: interns,
      currentPage: (meta['current_page'] as num?)?.toInt() ?? fallbackPage,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      perPage: (meta['per_page'] as num?)?.toInt() ?? fallbackPerPage,
      total: (meta['total'] as num?)?.toInt() ?? interns.length,
      hasMorePages: meta['has_more_pages'] == true,
    );
  }
}

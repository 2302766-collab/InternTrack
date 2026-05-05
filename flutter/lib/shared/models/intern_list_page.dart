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
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const String _defaultDtrExportDescription =
    'Export this DTR as a PDF or Excel file. The selected date range decides which records are included in the export.';

class DtrExportSelection {
  final DateTime startDate;
  final DateTime endDate;
  final bool pdf;

  const DtrExportSelection({
    required this.startDate,
    required this.endDate,
    required this.pdf,
  });
}

Future<DtrExportSelection?> showDtrExportDialog(
  BuildContext context, {
  required DateTime initialStartDate,
  required DateTime initialEndDate,
  String title = 'Export DTR',
  String? description,
}) {
  return showDialog<DtrExportSelection>(
    context: context,
    builder: (context) => _DtrExportDialog(
      initialStartDate: initialStartDate,
      initialEndDate: initialEndDate,
      title: title,
      description: description,
    ),
  );
}

class _DtrExportDialog extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final String title;
  final String? description;

  const _DtrExportDialog({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.title,
    this.description,
  });

  @override
  State<_DtrExportDialog> createState() => _DtrExportDialogState();
}

class _DtrExportDialogState extends State<_DtrExportDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = _dateOnly(widget.initialStartDate);
    _endDate = _dateOnly(widget.initialEndDate);
  }

  @override
  Widget build(BuildContext context) {
    final validationMessage = _validationMessage();
    final canExport = validationMessage == null;
    final dialogDescription =
        (widget.description ?? '').trim().isEmpty
            ? _defaultDtrExportDescription
            : widget.description!;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dialogDescription.isNotEmpty) ...[
            Text(
              dialogDescription,
              style: const TextStyle(fontSize: 14, color: Color(0xFF526072)),
            ),
            const SizedBox(height: 16),
          ],
          _DateField(
            label: 'Start Date',
            value: _formatDate(_startDate),
            onTap: () => _pickDate(isStartDate: true),
          ),
          const SizedBox(height: 12),
          _DateField(
            label: 'End Date',
            value: _formatDate(_endDate),
            onTap: () => _pickDate(isStartDate: false),
          ),
          const SizedBox(height: 12),
          Text(
            validationMessage ??
                'Choose dates within the same month to keep the export format unchanged.',
            style: TextStyle(
              fontSize: 12,
              color: validationMessage == null
                  ? const Color(0xFF667085)
                  : const Color(0xFFB42318),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canExport ? () => _submit(pdf: true) : null,
          child: const Text('Export PDF'),
        ),
        OutlinedButton(
          onPressed: canExport ? () => _submit(pdf: false) : null,
          child: const Text('Export Excel'),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = DateTime(2000, 1, 1);
    final lastDate = DateTime.now().add(const Duration(days: 366));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      if (isStartDate) {
        _startDate = _dateOnly(pickedDate);
      } else {
        _endDate = _dateOnly(pickedDate);
      }
    });
  }

  void _submit({required bool pdf}) {
    Navigator.of(context).pop(
      DtrExportSelection(startDate: _startDate, endDate: _endDate, pdf: pdf),
    );
  }

  String? _validationMessage() {
    if (_startDate.isAfter(_endDate)) {
      return 'Start date must be on or before end date.';
    }

    if (_startDate.year != _endDate.year ||
        _startDate.month != _endDate.month) {
      return 'Choose start and end dates within the same month.';
    }

    return null;
  }

  String _formatDate(DateTime value) {
    return DateFormat('MMMM d, yyyy').format(value);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/shared/widgets/dtr_export_dialog.dart';

void main() {
  testWidgets('dialog returns PDF selection with the initial valid range', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildDialogHost(
        initialStartDate: DateTime(2026, 4, 1),
        initialEndDate: DateTime(2026, 4, 30),
        description: 'Export a monthly DTR file.',
      ),
    );

    await tester.tap(find.text('Open Export Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Export Dialog'), findsOneWidget);
    expect(find.text('Export a monthly DTR file.'), findsOneWidget);
    expect(find.text('April 1, 2026'), findsOneWidget);
    expect(find.text('April 30, 2026'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Export PDF'));
    await tester.pumpAndSettle();

    expect(find.text('pdf:2026-04-01->2026-04-30'), findsOneWidget);
  });

  testWidgets('dialog returns Excel selection when requested', (tester) async {
    await tester.pumpWidget(
      _buildDialogHost(
        initialStartDate: DateTime(2026, 4, 10),
        initialEndDate: DateTime(2026, 4, 25),
      ),
    );

    await tester.tap(find.text('Open Export Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export Excel'));
    await tester.pumpAndSettle();

    expect(find.text('excel:2026-04-10->2026-04-25'), findsOneWidget);
  });

  testWidgets('dialog disables export actions for cross-month ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildDialogHost(
        initialStartDate: DateTime(2026, 4, 30),
        initialEndDate: DateTime(2026, 5, 1),
      ),
    );

    await tester.tap(find.text('Open Export Dialog'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose start and end dates within the same month.'),
      findsOneWidget,
    );

    final pdfButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Export PDF'),
    );
    final excelButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export Excel'),
    );

    expect(pdfButton.onPressed, isNull);
    expect(excelButton.onPressed, isNull);
  });

  testWidgets('dialog updates dates after picking new values', (tester) async {
    await tester.pumpWidget(
      _buildDialogHost(
        initialStartDate: DateTime(2026, 4, 1),
        initialEndDate: DateTime(2026, 4, 30),
      ),
    );

    await tester.tap(find.text('Open Export Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('April 1, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('April 30, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('22').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('April 15, 2026'), findsOneWidget);
    expect(find.text('April 22, 2026'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Export PDF'));
    await tester.pumpAndSettle();

    expect(find.text('pdf:2026-04-15->2026-04-22'), findsOneWidget);
  });

  testWidgets('canceling the date picker keeps the original date range', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildDialogHost(
        initialStartDate: DateTime(2026, 4, 3),
        initialEndDate: DateTime(2026, 4, 27),
      ),
    );

    await tester.tap(find.text('Open Export Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('April 3, 2026'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('April 3, 2026'), findsOneWidget);
    expect(find.text('April 27, 2026'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export Excel'));
    await tester.pumpAndSettle();

    expect(find.text('excel:2026-04-03->2026-04-27'), findsOneWidget);
  });

  testWidgets('dialog shows start-before-end validation and can be canceled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildDialogHost(
        initialStartDate: DateTime(2026, 4, 20),
        initialEndDate: DateTime(2026, 4, 10),
      ),
    );

    await tester.tap(find.text('Open Export Dialog'));
    await tester.pumpAndSettle();

    expect(
      find.text('Start date must be on or before end date.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('canceled'), findsOneWidget);
  });
}

Widget _buildDialogHost({
  required DateTime initialStartDate,
  required DateTime initialEndDate,
  String? description,
}) {
  return MaterialApp(
    home: _DialogHost(
      initialStartDate: initialStartDate,
      initialEndDate: initialEndDate,
      description: description,
    ),
  );
}

class _DialogHost extends StatefulWidget {
  const _DialogHost({
    required this.initialStartDate,
    required this.initialEndDate,
    this.description,
  });

  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final String? description;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  String _result = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                final selection = await showDtrExportDialog(
                  context,
                  initialStartDate: widget.initialStartDate,
                  initialEndDate: widget.initialEndDate,
                  title: 'Export Dialog',
                  description: widget.description,
                );

                if (!mounted) {
                  return;
                }

                setState(() {
                  _result = selection == null
                      ? 'canceled'
                      : '${selection.pdf ? 'pdf' : 'excel'}:'
                            '${_format(selection.startDate)}->${_format(selection.endDate)}';
                });
              },
              child: const Text('Open Export Dialog'),
            ),
            const SizedBox(height: 16),
            Text(_result),
          ],
        ),
      ),
    );
  }

  String _format(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

import 'package:flutter/material.dart';

import 'student_bottom_nav_bar.dart';

class StudentScaffold extends StatelessWidget {
  const StudentScaffold({
    super.key,
    required this.currentRoute,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final String currentRoute;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showBottomNavigation = constraints.maxWidth < 960;

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            bottom: !showBottomNavigation,
            child: body,
          ),
          backgroundColor: backgroundColor,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          bottomNavigationBar: showBottomNavigation
              ? StudentBottomNavBar(currentRoute: currentRoute)
              : null,
        );
      },
    );
  }
}

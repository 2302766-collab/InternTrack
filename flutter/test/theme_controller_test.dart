import 'package:flutter_test/flutter_test.dart';
import 'package:intern_track_app/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme controller reads the saved preference', () async {
    SharedPreferences.setMockInitialValues({'is_dark_mode_enabled': true});

    final controller = await ThemeController.create();

    expect(controller.isDarkMode, isTrue);
  });

  test('theme controller persists toggle changes', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await ThemeController.create();

    await controller.setDarkMode(true);
    final preferences = await SharedPreferences.getInstance();

    expect(controller.isDarkMode, isTrue);
    expect(preferences.getBool('is_dark_mode_enabled'), isTrue);
  });
}

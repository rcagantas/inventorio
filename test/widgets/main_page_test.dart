import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/main.dart';

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockCollection mocks = MockCollection();
  MockPluginsManager mockPluginsManager = MockPluginsManager();
  MyApp app;

  group('Main Page', () {

    setUp(() async {
      debugDefaultTargetPlatformOverride = null;
      mockPluginsManager.setupDefaultMockValues();
      await mocks.initMocks();
      app = MyApp();
    });

    testWidgets('should navigate to settings page', (tester) async {
      await tester.pumpWidget(app);
      mocks.userState.signInWithGoogle();
      await tester.pump();

      await tester.tap(find.byKey(ObjectKey('inv_menu_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(ObjectKey('inv_settings_page')), findsOneWidget);
    });


  });
}
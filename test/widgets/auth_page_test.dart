import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/main.dart';
import 'package:inventorio/models/inv_status.dart';
import 'package:inventorio/widgets/inv_key.dart';

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockCollection mocks = MockCollection();
  MockPluginsManager mockPluginsManager = MockPluginsManager();
  MyApp app;

  group('Auth Page', () {

    setUp(() async {
      debugDefaultTargetPlatformOverride = null;
      mockPluginsManager.setupDefaultMockValues();
      await mocks.initMocks();
      app = MyApp();
    });

    testWidgets('should show splash screen on entry', (tester) async {
      await tester.pumpWidget(app);

      expect(find.byKey(InvKey.SPLASH_PAGE), findsOneWidget);
    });

    testWidgets('should show login screen when current login is unset', (tester) async {
      await tester.pumpWidget(app);

      await mocks.userState.signOut();
      await tester.pumpAndSettle();
      
      expect(find.byKey(InvKey.GOOGLE_SIGN_IN_BUTTON), findsOneWidget);
      expect(find.byKey(InvKey.APPLE_SIGN_IN_BUTTON), findsOneWidget);
    });

    testWidgets('should not show Apple Sign-In if not available', (tester) async {
      mockPluginsManager.setMock(MockPluginsManager.CHANNEL_APPLE_SIGN_IN, (call) async {
        if (call.method == 'isAvailable') {
          return Future.value(false);
        }
      });

      await tester.pumpWidget(app);

      await mocks.userState.signOut();
      await tester.pumpAndSettle();

      expect(find.byKey(InvKey.GOOGLE_SIGN_IN_BUTTON), findsOneWidget);
      expect(find.byKey(InvKey.APPLE_SIGN_IN_BUTTON), findsNothing);
    });

    testWidgets('should show authenticating when attempting to log in', (tester) async {
      await tester.pumpWidget(app);

      mocks.userState.setStatus(InvStatus.Authenticating);
      await tester.pump();

      expect(find.byKey(InvKey.LOADING_PAGE), findsOneWidget);
    });

    testWidgets('should show main page when logged in', (tester) async {
      await tester.pumpWidget(app);

      mocks.userState.signInWithGoogle();
      await tester.pumpAndSettle();

      expect(find.byKey(InvKey.MENU_BUTTON), findsOneWidget);
    });

  });
}
// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester utility that Flutter
// provides. For example, you can send tap and scroll gestures. You can also use WidgetTester to
// find child widgets in the widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inventorio/inventory_app2.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:mockito/mockito.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  final _injector = Injector.getInjector();
  final _mockGoogleSignIn = MockGoogleSignIn();
  final _mockGoogleSignInAccount = MockGoogleSignInAccount();

  void _setup() {
    when(_mockGoogleSignInAccount.id).thenReturn("1234");
    when(_mockGoogleSignIn.signInSilently()).thenAnswer((_) => Future.value(_mockGoogleSignInAccount));

    _injector.map<GoogleSignIn>((_) => _mockGoogleSignIn, isSingleton: true);
    _injector.map<InventoryBloc>((_) => InventoryBloc(), isSingleton: true);
  }

  test('User required on add item', () {
    _setup();
    var bloc = _injector.get<InventoryBloc>();
  });

//  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
//    // Build our app and trigger a frame.
//    await tester.pumpWidget(new InventoryApp());
//
//    // Verify that our counter starts at 0.
//    expect(find.text('0'), findsOneWidget);
//    expect(find.text('1'), findsNothing);
//
//    // Tap the '+' icon and trigger a frame.
//    await tester.tap(find.byIcon(Icons.add));
//    await tester.pump();
//
//    // Verify that our counter has incremented.
//    expect(find.text('0'), findsNothing);
//    expect(find.text('1'), findsOneWidget);
//  });
}

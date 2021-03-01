import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/models/inv_status.dart';
import 'package:inventorio/providers/user_state.dart';
import 'package:inventorio/services/inv_auth_service.dart';
import 'package:mockito/mockito.dart';

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserState userState;
  InvAuthServiceMock invAuthServiceMock;
  MockPluginsManager mockPluginsManager = MockPluginsManager();

  group('User State Provider', () {
    setUp(() {
      mockPluginsManager.setupDefaultMockValues();
      GetIt.instance.reset();
      GetIt.instance.registerLazySingleton<InvAuthService>(() => InvAuthServiceMock());

      invAuthServiceMock = GetIt.instance.get<InvAuthService>();
      userState = UserState();
    });

    test('should sign-in with email', () {
      userState.signInWithEmail('email', 'password');

      verify(invAuthServiceMock.signInWithEmailAndPassword(email: 'email', password: 'password')).called(1);
      expect(userState.status, InvStatus.Authenticating);
    });

    test('should fail sign-in with email when service throw', () {
      when(invAuthServiceMock.signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenThrow(Exception('failure'));

      userState.signInWithEmail('email', 'password');
      expect(userState.status, InvStatus.Unauthenticated);
    });

    test('should sign-in with Google', () async {
      var signIn = userState.signInWithGoogle();
      expect(userState.status, InvStatus.Authenticating);

      await signIn;
      verify(invAuthServiceMock.signInWithGoogle()).called(1);
      expect(userState.status, InvStatus.Authenticated);
    });

    test('should fail sign-in with Google when service throws', () async {
      when(invAuthServiceMock.signInWithGoogle()).thenThrow(Exception('failure'));

      await userState.signInWithGoogle();
      expect(userState.status, InvStatus.Unauthenticated);
    });

    test('should sign-in with Apple', () async {
      var signIn = userState.signInWithApple();

      expect(userState.status, InvStatus.Authenticating);

      await signIn;
      verify(invAuthServiceMock.signInWithApple()).called(1);
      expect(userState.status, InvStatus.Authenticated);
    });

    test('should fail sign-in with Apple when service throws', () async {
      when(invAuthServiceMock.signInWithApple()).thenThrow(Exception('failure'));

      await userState.signInWithApple();
      expect(userState.status, InvStatus.Unauthenticated);
    });

    test('should sign-out', () async {
      await userState.signInWithGoogle();

      await userState.signOut();

      verify(invAuthServiceMock.signOut()).called(1);
      expect(userState.status, InvStatus.Unauthenticated);
    });

    test('should change auth state to null', () async {
      when(invAuthServiceMock.onAuthStateChanged).thenAnswer((realInvocation) => Stream.value(null));

      userState = UserState();

      await Future.delayed(Duration(milliseconds: 10));
      expect(userState.status, InvStatus.Unauthenticated);
    });

    test('should have new UserState on new login', () async {
      when(invAuthServiceMock.onAuthStateChanged).thenAnswer((realInvocation) => Stream.value(InvAuth(uid: 'uid')));

      userState = UserState();

      await Future.delayed(Duration(milliseconds: 10));
      expect(userState.status, InvStatus.Authenticated);
    });
  });
}
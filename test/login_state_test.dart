// test/login_state_test.dart
//
// AGENT_APP_TESTS_V1 — the copyWith that used to wipe the login error.
//
// errorMessage was passed straight through with no fallback to the current
// value, so any copyWith that did not restate it cleared it: toggling the
// password eye after a failed login left the screen showing a failure with no
// reason on it. It is carried forward now, and the two emits that genuinely
// start over pass clearError.
//
// Pure unit tests. AgentLoginState is a plain Equatable value; the bloc that
// owns it is never constructed here, so nothing reaches AuthService.
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_agent_app/features/auth/bloc/agent_login_bloc.dart';

void main() {
  group('AgentLoginState', () {
    const failed = AgentLoginState(
      status: AgentLoginStatus.failure,
      errorMessage: 'Invalid email or password',
    );

    test('starts clean', () {
      const initial = AgentLoginState();

      expect(initial.status, AgentLoginStatus.initial);
      expect(initial.isPasswordVisible, isFalse);
      expect(initial.errorMessage, isNull);
    });

    test('an unrelated copyWith carries the error forward', () {
      // This is the eye toggle: it says nothing about the error and must not
      // silently drop it.
      final toggled = failed.copyWith(isPasswordVisible: true);

      expect(toggled.isPasswordVisible, isTrue);
      expect(toggled.status, AgentLoginStatus.failure);
      expect(toggled.errorMessage, 'Invalid email or password');
    });

    test('a copyWith with no arguments at all changes nothing', () {
      expect(failed.copyWith(), failed);
    });

    test('clearError is what clears it', () {
      // The retry emit: a fresh attempt must not sit under the spinner.
      final retry = failed.copyWith(
        status: AgentLoginStatus.loading,
        clearError: true,
      );

      expect(retry.status, AgentLoginStatus.loading);
      expect(retry.errorMessage, isNull);
      expect(retry.isPasswordVisible, isFalse);
    });

    test('clearError wins over an errorMessage passed beside it', () {
      expect(
        failed.copyWith(errorMessage: 'later', clearError: true).errorMessage,
        isNull,
      );
    });

    test('a new message replaces the old one', () {
      final next = failed.copyWith(
        errorMessage: 'Cannot reach the server. Check your connection.',
      );

      expect(next.errorMessage, 'Cannot reach the server. Check your connection.');
      expect(next.status, AgentLoginStatus.failure);
    });

    test('the success emit leaves nothing behind for the next screen', () {
      final ok = failed.copyWith(
        status: AgentLoginStatus.success,
        clearError: true,
      );

      expect(ok.status, AgentLoginStatus.success);
      expect(ok.errorMessage, isNull);
    });

    test('two states with the same fields are equal', () {
      const a = AgentLoginState(
        status: AgentLoginStatus.loading,
        isPasswordVisible: true,
      );
      const b = AgentLoginState(
        status: AgentLoginStatus.loading,
        isPasswordVisible: true,
      );

      expect(a, b);
      expect(a == failed, isFalse);
    });
  });
}

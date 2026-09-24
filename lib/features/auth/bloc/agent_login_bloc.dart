import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vpn_agent_app/features/auth/services/auth_service.dart'; // Import AuthService

// --- Events ---
abstract class AgentLoginEvent extends Equatable {
  const AgentLoginEvent();
  @override
  List<Object> get props => [];
}

class AgentLoginSubmitted extends AgentLoginEvent {
  final String email;
  final String password;
  const AgentLoginSubmitted({required this.email, required this.password});
}

class AgentLoginPasswordVisibilityToggled extends AgentLoginEvent {}

// --- States ---
enum AgentLoginStatus { initial, loading, success, failure }

class AgentLoginState extends Equatable {
  final AgentLoginStatus status;
  final bool isPasswordVisible;
  final String? errorMessage;

  const AgentLoginState({
    this.status = AgentLoginStatus.initial,
    this.isPasswordVisible = false,
    this.errorMessage,
  });

  /// AGENT_APP_F4 — errorMessage was passed straight through with no
  /// fallback to the current value, so any copyWith that did not restate the
  /// error cleared it: toggling the password eye after a failed login left
  /// the screen showing a failure with no reason. It is carried forward now,
  /// and the two emits that genuinely start over pass [clearError].
  AgentLoginState copyWith({
    AgentLoginStatus? status,
    bool? isPasswordVisible,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AgentLoginState(
      status: status ?? this.status,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, isPasswordVisible, errorMessage];
}

// --- Bloc ---
class AgentLoginBloc extends Bloc<AgentLoginEvent, AgentLoginState> {
  // AuthService ကို ခေါ်သုံးပါမယ်
  final AuthService _authService = AuthService();

  AgentLoginBloc() : super(const AgentLoginState()) {
    on<AgentLoginSubmitted>(_onSubmitted);
    on<AgentLoginPasswordVisibilityToggled>(_onTogglePassword);
  }

  void _onTogglePassword(
    AgentLoginPasswordVisibilityToggled event,
    Emitter<AgentLoginState> emit,
  ) {
    emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
  }

  Future<void> _onSubmitted(
    AgentLoginSubmitted event,
    Emitter<AgentLoginState> emit,
  ) async {
    // A fresh attempt: the previous failure must not sit under the spinner.
    emit(state.copyWith(status: AgentLoginStatus.loading, clearError: true));

    try {
      // ⭐️ Real API Call
      // AuthService ရဲ့ login function က Token သိမ်းတာတွေပါ အကုန်လုပ်ပေးပါလိမ့်မယ်
      final bool success = await _authService.login(
        event.email,
        event.password,
      );

      if (success) {
        emit(
          state.copyWith(status: AgentLoginStatus.success, clearError: true),
        );
      } else {
        emit(
          state.copyWith(
            status: AgentLoginStatus.failure,
            errorMessage: "Invalid email or password",
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AgentLoginStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

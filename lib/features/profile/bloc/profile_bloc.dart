import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';
import 'package:vpn_agent_app/features/profile/models/profile_user_model.dart';
import 'package:vpn_agent_app/features/profile/repositories/profile_repository.dart';

// --- Events ---
abstract class ProfileEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class ProfileStarted extends ProfileEvent {}

class ProfileRefreshed extends ProfileEvent {}

class ProfileTelegramUpdated extends ProfileEvent {
  final String username;
  ProfileTelegramUpdated(this.username);
}

class ProfilePaymentMethodsUpdated extends ProfileEvent {
  final List<PaymentMethod> methods;
  ProfilePaymentMethodsUpdated(this.methods);
}

// --- States ---
enum ProfileStatus { initial, loading, success, failure, updating }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final ProfileUser? user;
  final String? errorMessage;
  final String? successMessage; // For Toast/SnackBar

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.user,
    this.errorMessage,
    this.successMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileUser? user,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage, // Don't copy error, reset it often
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, successMessage];
}

// --- Bloc ---
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _repository;

  ProfileBloc({required ProfileRepository repository})
    : _repository = repository,
      super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileRefreshed>(_onRefreshed);
    on<ProfileTelegramUpdated>(_onTelegramUpdated);
    on<ProfilePaymentMethodsUpdated>(_onPaymentMethodsUpdated);
  }

  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    // 1. Load Cache First
    final cachedUser = _repository.getCachedProfile();
    if (cachedUser != null) {
      emit(state.copyWith(status: ProfileStatus.success, user: cachedUser));
    } else {
      emit(state.copyWith(status: ProfileStatus.loading));
    }

    // 2. Fetch Fresh Data
    await _fetchData(emit);
  }

  Future<void> _onRefreshed(
    ProfileRefreshed event,
    Emitter<ProfileState> emit,
  ) async {
    // Show loading indicator only if we want specific UI feedback,
    // otherwise just update silently or use 'updating'
    await _fetchData(emit);
  }

  Future<void> _fetchData(Emitter<ProfileState> emit) async {
    try {
      final user = await _repository.fetchProfile();
      emit(state.copyWith(status: ProfileStatus.success, user: user));
    } catch (e) {
      if (state.user == null) {
        emit(
          state.copyWith(
            status: ProfileStatus.failure,
            errorMessage: e.toString(),
          ),
        );
      }
      // If user exists (cache), simply keep it and maybe show a snackbar via listener
    }
  }

  Future<void> _onTelegramUpdated(
    ProfileTelegramUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.updating));
    final success = await _repository.updateTelegram(event.username);
    if (success) {
      emit(state.copyWith(successMessage: "Telegram updated!"));
      add(ProfileRefreshed()); // Reload profile to be safe
    } else {
      emit(
        state.copyWith(
          status: ProfileStatus.success,
          errorMessage: "Failed to update Telegram",
        ),
      );
    }
  }

  Future<void> _onPaymentMethodsUpdated(
    ProfilePaymentMethodsUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.updating));
    final success = await _repository.updatePaymentMethods(event.methods);
    if (success) {
      emit(state.copyWith(successMessage: "Payment methods saved!"));
      add(ProfileRefreshed());
    } else {
      emit(
        state.copyWith(
          status: ProfileStatus.success,
          errorMessage: "Failed to save payment methods",
        ),
      );
    }
  }
}

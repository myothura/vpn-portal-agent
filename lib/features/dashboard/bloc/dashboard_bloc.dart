import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';
import 'package:vpn_agent_app/features/dashboard/repositories/dashboard_repository.dart';

// --- Events ---
abstract class DashboardEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class DashboardStarted extends DashboardEvent {} // စစချင်း Load

class DashboardRefreshed
    extends DashboardEvent {} // User က ဆွဲချပြီး refresh လုပ်ရင်

class _DashboardAutoUpdated
    extends DashboardEvent {} // Timer နဲ့ Auto refresh လုပ်ရင်

// --- States ---
abstract class DashboardState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {
  final DashboardStats? cachedStats;
  DashboardLoading({this.cachedStats});

  // Without props every emit counted as a change, defeating the point of
  // Equatable on the state class.
  @override
  List<Object?> get props => [cachedStats];
}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  DashboardLoaded(this.stats);
  @override
  List<Object?> get props => [stats];
}

class DashboardError extends DashboardState {
  final String message;
  final DashboardStats? cachedStats;
  DashboardError(this.message, {this.cachedStats});

  @override
  List<Object?> get props => [message, cachedStats];
}

// --- Bloc ---
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardRepository _repository;
  Timer? _timer;

  DashboardBloc({required DashboardRepository repository})
    : _repository = repository,
      super(DashboardInitial()) {
    on<DashboardStarted>(_onStarted);
    on<DashboardRefreshed>(_onRefreshed);
    on<_DashboardAutoUpdated>(_onAutoUpdate);
  }

  // App စဖွင့်ရင်
  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<DashboardState> emit,
  ) async {
    // 1. Show Cache First (Instant Load)
    final cachedData = _repository.getCachedStats();
    if (cachedData != null) {
      emit(DashboardLoaded(cachedData));
    } else {
      emit(DashboardLoading());
    }

    // 2. Fetch Fresh Data
    await _fetchData(emit, isBackground: false);

    // 3. Start Polling (Real-time updates every 30 seconds)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      add(_DashboardAutoUpdated());
    });
  }

  Future<void> _onRefreshed(
    DashboardRefreshed event,
    Emitter<DashboardState> emit,
  ) async {
    // Manual Refresh ဆိုရင် Cache ရှိနေလဲ Loading ပြမယ် (User Feedback အတွက်)
    final currentStats = state is DashboardLoaded
        ? (state as DashboardLoaded).stats
        : null;
    emit(DashboardLoading(cachedStats: currentStats));
    await _fetchData(emit, isBackground: false);
  }

  Future<void> _onAutoUpdate(
    _DashboardAutoUpdated event,
    Emitter<DashboardState> emit,
  ) async {
    // Background update မို့ Loading မပြဘဲ တိတ်တဆိတ် update မယ်
    await _fetchData(emit, isBackground: true);
  }

  Future<void> _fetchData(
    Emitter<DashboardState> emit, {
    required bool isBackground,
  }) async {
    try {
      final stats = await _repository.fetchDashboardStats();
      emit(DashboardLoaded(stats));
    } catch (e) {
      // Background fetch ဆိုရင် Error မပြဘူး (User အနှောင့်အယှက်မဖြစ်အောင်)
      if (!isBackground) {
        final currentStats = state is DashboardLoaded
            ? (state as DashboardLoaded).stats
            : (state is DashboardLoading
                  ? (state as DashboardLoading).cachedStats
                  : null);

        emit(DashboardError(e.toString(), cachedStats: currentStats));
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rebate_data.dart';
import '../repositories/rebate_repository.dart';
import 'auth_provider.dart';

final rebateRepositoryProvider = Provider((ref) => RebateRepository());

final rebateProvider =
StateNotifierProvider.autoDispose<RebateNotifier, RebateState>(
      (ref) {
    final currentUser = ref.watch(currentUserProvider);

    final notifier = RebateNotifier(
      ref.watch(rebateRepositoryProvider),
      ref,
    );

    if (currentUser != null) {
      Future.microtask(() => notifier.loadUserRebates());
    }

    return notifier;
  },
);

class RebateState {
  final DateTime? startDate;
  final DateTime? endDate;
  final String reason;
  final bool isSubmitting;
  final bool submitSuccess;
  final String? errorMessage;
  final List<Rebate> userRebates;
  final bool isLoadingRebates;

  RebateState({
    this.startDate,
    this.endDate,
    this.reason = '',
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.errorMessage,
    this.userRebates = const [],
    this.isLoadingRebates = false,
  });

  int get totalDays {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }

  RebateState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    bool? isSubmitting,
    bool? submitSuccess,
    String? errorMessage,
    List<Rebate>? userRebates,
    bool? isLoadingRebates,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return RebateState(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      reason: reason ?? this.reason,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccess:
      clearSuccess ? false : (submitSuccess ?? this.submitSuccess),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userRebates: userRebates ?? this.userRebates,
      isLoadingRebates: isLoadingRebates ?? this.isLoadingRebates,
    );
  }
}

class RebateNotifier extends StateNotifier<RebateState> {
  final RebateRepository _repository;
  final Ref _ref;

  RebateNotifier(this._repository, this._ref) : super(RebateState());

  User? get _currentUser => _ref.read(currentUserProvider);

  void updateStartDate(DateTime date) {
    // If end date is before new start date, clear it
    final newEndDate =
    state.endDate != null && state.endDate!.isBefore(date)
        ? null
        : state.endDate;
    state = state.copyWith(
      startDate: date,
      clearEndDate: newEndDate == null,
      endDate: newEndDate,
    );
  }

  void updateEndDate(DateTime date) {
    state = state.copyWith(endDate: date);
  }

  void updateReason(String text) {
    state = state.copyWith(reason: text);
  }

  Future<void> loadUserRebates() async {
    final user = _currentUser;
    if (user == null) {
      state = state.copyWith(userRebates: [], isLoadingRebates: false);
      return;
    }

    state = state.copyWith(isLoadingRebates: true);
    final rebates = await _repository.getUserRebates(user.uid);

    if (mounted) {
      state = state.copyWith(
        userRebates: rebates,
        isLoadingRebates: false,
      );
    }
  }

  Future<void> submitRebate() async {
    final user = _currentUser;

    if (user == null || user.email == null) {
      state = state.copyWith(errorMessage: 'Please sign in to submit rebates');
      return;
    }

    if (state.startDate == null || state.endDate == null) {
      state = state.copyWith(errorMessage: 'Please select start and end dates');
      return;
    }

    if (state.endDate!.isBefore(state.startDate!)) {
      state =
          state.copyWith(errorMessage: 'End date must be after start date');
      return;
    }

    if (state.reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please provide a reason');
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    final submission = RebateSubmission(
      userName: user.displayName ?? 'User',
      userEmail: user.email!,
      userId: user.uid,
      startDate: state.startDate!,
      endDate: state.endDate!,
      reason: state.reason.trim(),
      totalDays: state.totalDays,
    );

    final result = await _repository.submitRebate(submission);

    if (mounted) {
      if (result.isSuccess) {
        state = state.copyWith(
          isSubmitting: false,
          submitSuccess: true,
          reason: '',
          clearStartDate: true,
          clearEndDate: true,
        );
        await loadUserRebates();
      } else {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
          result.error?.toString() ?? 'Failed to submit rebate',
        );
      }
    }
  }

  void clearSuccessMessage() {
    state = state.copyWith(clearSuccess: true);
  }

  void resetForm() {
    state = RebateState(userRebates: state.userRebates);
  }
}
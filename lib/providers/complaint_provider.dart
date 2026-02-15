import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/complaint_data.dart';
import '../repositories/complaint_repository.dart';
import 'auth_provider.dart';

final complaintRepositoryProvider = Provider((ref) => ComplaintRepository());

// ✅ FIXED: Auto-dispose provider that rebuilds when user changes
final complaintProvider = StateNotifierProvider.autoDispose<ComplaintNotifier, ComplaintState>(
      (ref) {
    // Watch the current user - provider rebuilds when user changes
    final currentUser = ref.watch(currentUserProvider);

    final notifier = ComplaintNotifier(
      ref.watch(complaintRepositoryProvider),
      ref,  // Pass ref instead of user
    );

    // Load complaints when provider is created and user is signed in
    if (currentUser != null) {
      Future.microtask(() => notifier.loadUserComplaints());
    }

    return notifier;
  },
);

class ComplaintState {
  final String complaintText;
  final String selectedCategory;
  final bool isSubmitting;
  final bool submitSuccess;
  final String? errorMessage;
  final List<Complaint> userComplaints;
  final bool isLoadingComplaints;

  ComplaintState({
    this.complaintText = '',
    this.selectedCategory = 'Food Quality',
    this.isSubmitting = false,
    this.submitSuccess = false,
    this.errorMessage,
    this.userComplaints = const [],
    this.isLoadingComplaints = false,
  });

  ComplaintState copyWith({
    String? complaintText,
    String? selectedCategory,
    bool? isSubmitting,
    bool? submitSuccess,
    String? errorMessage,
    List<Complaint>? userComplaints,
    bool? isLoadingComplaints,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ComplaintState(
      complaintText: complaintText ?? this.complaintText,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitSuccess: clearSuccess ? false : (submitSuccess ?? this.submitSuccess),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userComplaints: userComplaints ?? this.userComplaints,
      isLoadingComplaints: isLoadingComplaints ?? this.isLoadingComplaints,
    );
  }
}

class ComplaintNotifier extends StateNotifier<ComplaintState> {
  final ComplaintRepository _repository;
  final Ref _ref;  // ✅ Store ref instead of user

  ComplaintNotifier(this._repository, this._ref) : super(ComplaintState());

  // ✅ Get current user dynamically from ref
  User? get _currentUser => _ref.read(currentUserProvider);

  void updateComplaintText(String text) {
    state = state.copyWith(complaintText: text);
  }

  void updateCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<void> loadUserComplaints() async {
    final user = _currentUser;

    if (user == null) {
      state = state.copyWith(
        userComplaints: [],
        isLoadingComplaints: false,
      );
      return;
    }

    state = state.copyWith(isLoadingComplaints: true);

    final complaints = await _repository.getUserComplaints(user.uid);

    if (mounted) {
      state = state.copyWith(
        userComplaints: complaints,
        isLoadingComplaints: false,
      );
    }
  }

  Future<void> submitComplaint() async {
    final user = _currentUser;

    if (user == null || user.email == null) {
      state = state.copyWith(
        errorMessage: 'Please sign in to submit complaints',
      );
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    final userName = user.displayName ?? 'User';
    final userEmail = user.email!;
    final userId = user.uid;

    if (state.complaintText.trim().isEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Please describe your complaint',
      );
      return;
    }

    if (state.complaintText.trim().length < 10) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Please provide more details (at least 10 characters)',
      );
      return;
    }

    final submission = ComplaintSubmission(
      userName: userName,
      userEmail: userEmail,
      userId: userId,
      complaintText: state.complaintText.trim(),
      category: state.selectedCategory,
    );

    final result = await _repository.submitComplaint(submission);

    if (mounted) {
      if (result.isSuccess) {
        state = state.copyWith(
          isSubmitting: false,
          submitSuccess: true,
          complaintText: '', // Clear text
        );
        // Reload complaints
        await loadUserComplaints();
      } else {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: result.error?.toString() ?? 'Failed to submit complaint',
        );
      }
    }
  }

  void resetState() {
    state = ComplaintState();
  }

  void clearSuccessMessage() {
    state = state.copyWith(clearSuccess: true);
  }
}
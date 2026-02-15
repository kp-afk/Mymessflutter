import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Stream provider that watches auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ✅ FIXED: Get current user from the stream provider, not from the service directly
final currentUserProvider = Provider<User?>((ref) {
  // Watch the auth state stream and return its current value
  return ref.watch(authStateProvider).value;
});

// Helper provider to invalidate dependent providers when auth changes
final authChangeListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final previousUser = previous?.value;
    final currentUser = next.value;

    // User actually changed (signed in or out)
    if (previousUser?.uid != currentUser?.uid) {
      // Note: Individual providers will handle their own invalidation
      // by watching currentUserProvider
    }
  });
});
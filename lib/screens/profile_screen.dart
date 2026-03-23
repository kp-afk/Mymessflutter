import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import 'complaint_screen.dart';
import 'rebate_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showComplaintScreen = false;
  bool _showRebateScreen = false;
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    if (_showComplaintScreen) {
      return ComplaintScreen(
        onBack: () {
          setState(() => _showComplaintScreen = false);
        },
      );
    }

    if (_showRebateScreen) {
      return RebateScreen(
        onBack: () {
          setState(() => _showRebateScreen = false);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: authState.when(
        data: (user) => _buildProfileContent(user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildProfileContent(user) {
    final isSignedIn = user != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),

        // Avatar
        Center(
          child: isSignedIn && user.photoURL != null
              ? CircleAvatar(
            radius: 48,
            backgroundImage:
            CachedNetworkImageProvider(user.photoURL!),
          )
              : CircleAvatar(
            radius: 48,
            backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.account_circle,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // User Info
        Center(
          child: Text(
            isSignedIn ? (user.displayName ?? 'User') : 'Guest User',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (isSignedIn && user.email != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              user.email!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],

        const SizedBox(height: 32),

        // Sign In/Out Button
        if (!isSignedIn)
          FilledButton.icon(
            onPressed: _isSigningIn ? null : _handleSignIn,
            icon: _isSigningIn
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.login),
            label:
            Text(_isSigningIn ? 'Signing in...' : 'Sign in with Google'),
          )
        else
          OutlinedButton.icon(
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),

        const SizedBox(height: 24),
        const Divider(),

        // Settings
        _buildMenuTile(
          context: context,
          icon: Icons.settings,
          title: 'Settings',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings coming soon!')),
            );
          },
        ),

        const Divider(height: 1),

        // ── Rebates ──────────────────────────────────────────────────────
        _buildMenuTile(
          context: context,
          icon: Icons.receipt_long_rounded,
          title: 'My Rebates',
          subtitle: 'Apply & track your mess rebate requests',
          onTap: () {
            if (isSignedIn) {
              setState(() => _showRebateScreen = true);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please sign in to view rebates'),
                ),
              );
            }
          },
        ),

        const Divider(height: 1),

        // Complaints
        _buildMenuTile(
          context: context,
          icon: Icons.feedback,
          title: 'Complaints & Feedback',
          subtitle: 'Share your concerns with us',
          onTap: () {
            if (isSignedIn) {
              setState(() => _showComplaintScreen = true);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please sign in to submit complaints'),
                ),
              );
            }
          },
        ),

        const Divider(height: 1),
      ],
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Icon(
        Icons.chevron_right,
        color:
        Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
      ),
      onTap: onTap,
    );
  }

  Future<void> _handleSignIn() async {
    setState(() => _isSigningIn = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_data.dart';
import '../providers/meal_provider.dart';
import '../providers/auth_provider.dart';

class MealDashboard extends ConsumerWidget {
  const MealDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealScheduleState = ref.watch(mealProvider);
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          // The SliverAppBar title (collapsed state) and the FlexibleSpaceBar
          // background (expanded state) are SEPARATE — no overlap.
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            // Collapsed title — only visible when scrolled up
            title: Text(
              'Anusha Mess',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              // ⚠️ No title property here — that's what caused the overlap.
              // The collapsed title comes from SliverAppBar.title above.
              collapseMode: CollapseMode.pin,
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        greeting,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Anusha Mess',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (mealScheduleState.currentMeal != null) ...[
                  _CurrentMealCard(meal: mealScheduleState.currentMeal!),
                  const SizedBox(height: 12),
                ],

                if (mealScheduleState.currentMeal == null &&
                    mealScheduleState.nextMeal != null) ...[
                  _UpNextMealCard(
                    meal: mealScheduleState.nextMeal!,
                    showRsvp: true,
                  ),
                ] else if (mealScheduleState.currentMeal != null &&
                    mealScheduleState.nextMeal != null) ...[
                  _UpNextMealCard(
                    meal: mealScheduleState.nextMeal!,
                    showRsvp: false,
                  ),
                ],

                if (mealScheduleState.nextToNextMeal != null) ...[
                  const SizedBox(height: 12),
                  _ComingUpCard(meal: mealScheduleState.nextToNextMeal!),
                ],

                if (mealScheduleState.currentMeal == null &&
                    mealScheduleState.nextMeal == null) ...[
                  const SizedBox(height: 40),
                  const _EmptyStateCard(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────

ShapeBorder _cardShape({double radius = 20}) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const _SectionLabel({required this.text, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: c,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _MealItemRow extends StatelessWidget {
  final String item;
  const _MealItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Current Meal Card ────────────────────────────────────────────────────

class _CurrentMealCard extends ConsumerWidget {
  final MealInfo meal;
  const _CurrentMealCard({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: _cardShape(),
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(
              text: 'NOW SERVING',
              icon: Icons.restaurant_rounded,
              color: cs.onPrimaryContainer.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 10),
            Text(
              meal.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: cs.onPrimaryContainer.withValues(alpha: 0.10), height: 1),
            const SizedBox(height: 10),
            ...meal.items.map((item) => _MealItemRow(item: item)),
            const SizedBox(height: 4),
            _RsvpSection(mealInfo: meal),
          ],
        ),
      ),
    );
  }
}

// ─── Up Next Meal Card ────────────────────────────────────────────────────

class _UpNextMealCard extends ConsumerWidget {
  final MealInfo meal;
  final bool showRsvp;
  const _UpNextMealCard({required this.meal, required this.showRsvp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: _cardShape(),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SectionLabel(
                  text: 'UP NEXT',
                  icon: Icons.schedule_rounded,
                  color: cs.secondary,
                ),
                _CountdownChip(targetDateTime: meal.dateTime),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              meal.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 10),
            ...meal.items.map((item) => _MealItemRow(item: item)),
            if (showRsvp) ...[
              const SizedBox(height: 4),
              _RsvpSection(mealInfo: meal),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Coming Up Card ───────────────────────────────────────────────────────

class _ComingUpCard extends StatelessWidget {
  final MealInfo meal;
  const _ComingUpCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: _cardShape(radius: 14),
      color: cs.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.upcoming_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coming up later',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${meal.name}  ·  ${meal.start}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: _cardShape(),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.no_meals_rounded,
                size: 36, color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              'No upcoming meals today',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Countdown Chip ───────────────────────────────────────────────────────

class _CountdownChip extends StatefulWidget {
  final DateTime targetDateTime;
  const _CountdownChip({required this.targetDateTime});

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  late Timer _timer;
  String _timeLeft = '';

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(
        const Duration(minutes: 1), (_) => _updateTimeLeft());
  }

  void _updateTimeLeft() {
    final duration = widget.targetDateTime.difference(DateTime.now());
    if (duration.isNegative) {
      setState(() => _timeLeft = 'Starting!');
    } else {
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      setState(() => _timeLeft = h > 0 ? '${h}h ${m}m' : '${m}m');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            _timeLeft,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RSVP Section ─────────────────────────────────────────────────────────

class _RsvpSection extends ConsumerWidget {
  final MealInfo mealInfo;
  static const totalStudents = 600;

  const _RsvpSection({required this.mealInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealKey = createMealKey(mealInfo);
    final rsvpState = ref.watch(rsvpProvider(mealKey));
    final authState = ref.watch(authStateProvider);
    final cs = Theme.of(context).colorScheme;

    return authState.when(
      data: (user) {
        final isSignedIn = user != null;

        return Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Joining for ${mealInfo.name}?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Action area
              if (!isSignedIn)
                _buildSignInPrompt(context, cs)
              else if (rsvpState.isLoading)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (rsvpState.userSelection == RsvpOption.none)
                  _buildButtons(context, ref, user, mealKey, cs)
                else
                  _buildSelectionState(
                      context, ref, user, mealKey, rsvpState, cs),

              const SizedBox(height: 16),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 12),

              // Attendance stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${rsvpState.yesCount} attending',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'of $totalStudents students',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: rsvpState.yesCount / totalStudents,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),

              if (rsvpState.yesCount > 0) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showAttendeesDialog(
                        context, mealInfo.name),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: const Text("See who's going →"),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e',
            style: TextStyle(
                color: Theme.of(context).colorScheme.error)),
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Sign in to RSVP',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(
      BuildContext context,
      WidgetRef ref,
      dynamic user,
      String mealKey,
      ColorScheme cs,
      ) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => ref
                .read(rsvpProvider(mealKey).notifier)
                .updateAttendance(
              true,
              user.uid,
              user.displayName ?? 'User',
              user.email ?? '',
            ),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text("I'm in"),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => ref
                .read(rsvpProvider(mealKey).notifier)
                .updateAttendance(
              false,
              user.uid,
              user.displayName ?? 'User',
              user.email ?? '',
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Skipping'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionState(
      BuildContext context,
      WidgetRef ref,
      dynamic user,
      String mealKey,
      dynamic rsvpState,
      ColorScheme cs,
      ) {
    final isYes = rsvpState.userSelection == RsvpOption.yes;
    return Column(
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isYes ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isYes
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 15,
                color: isYes
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                isYes ? "You're going!" : 'Skipping this one',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isYes
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => ref
              .read(rsvpProvider(mealKey).notifier)
              .removeAttendance(user.uid),
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            textStyle: const TextStyle(fontSize: 12),
            minimumSize: const Size(0, 30),
          ),
          child: const Text('Change my response'),
        ),
      ],
    );
  }

  void _showAttendeesDialog(BuildContext context, String mealName) {
    showDialog(
      context: context,
      // ProviderScope is already above — we just need a ConsumerWidget inside
      // the dialog so it can watch the provider and rebuild on every push.
      builder: (context) => _AttendeesDialog(
        mealKey: createMealKey(mealInfo),
        mealName: mealName,
      ),
    );
  }
}

// ─── Live attendees dialog ────────────────────────────────────────────────
// Watches rsvpProvider directly so the list rebuilds the instant Firebase
// pushes a change — no need to close and reopen.

class _AttendeesDialog extends ConsumerWidget {
  final String mealKey;
  final String mealName;

  const _AttendeesDialog({required this.mealKey, required this.mealName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the dedicated stream provider — it's a direct Firebase onValue pipe
    // so additions AND removals are reflected instantly without going through
    // the StateNotifier or any optimistic/cached state.
    final attendeesAsync = ref.watch(attendeesStreamProvider(mealKey));
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attending $mealName',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      attendeesAsync.when(
                        data: (attendees) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            '${attendees.length} student${attendees.length == 1 ? '' : 's'}',
                            key: ValueKey(attendees.length),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                const _LiveDot(),
              ],
            ),

            const SizedBox(height: 16),

            // ── List ─────────────────────────────────────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: attendeesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: TextStyle(color: cs.error)),
                ),
                data: (attendees) => attendees.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No one yet — be the first!',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: attendees.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                  itemBuilder: (context, index) {
                    final a = attendees[index];
                    return Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              a.name.isNotEmpty
                                  ? a.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                              if (a.email.isNotEmpty)
                                Text(
                                  a.email.split('@')[0],
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Subtle live indicator ────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _opacity,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'Live',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
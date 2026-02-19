import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_data.dart';
import '../providers/meal_provider.dart';
import '../providers/auth_provider.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PHYSICS DROP-IN
// Entrance animation: widget starts at [initialScale] + [verticalOffset] above
// its rest position, then slams into place driven by a SpringSimulation.
// Opacity is 1.0 the entire time — no fade whatsoever.
// ═════════════════════════════════════════════════════════════════════════════

class PhysicsDropIn extends StatefulWidget {
  final Widget child;

  /// Spring stiffness — higher = faster snap. Try 80 (lazy) → 400 (snappy).
  final double tension;

  /// Damping — higher = fewer bounces. Try 8 (rubbery) → 30 (firm thud).
  final double friction;

  /// Scale the widget starts at. 2.0 reads as "thrown from above".
  final double initialScale;

  /// How far above its rest position the widget starts (in logical pixels).
  /// null = automatically use the full screen height so the widget begins
  /// completely off-screen above the top edge.
  final double? verticalOffset;

  /// Fire HapticFeedback.heavyImpact() at the perceptual "landing" moment.
  final bool haptic;

  /// Optional delay for staggering multiple widgets.
  final Duration delay;

  const PhysicsDropIn({
    super.key,
    required this.child,
    this.tension = 200.0,
    this.friction = 16.0,
    this.initialScale = 2.0,
    this.verticalOffset,   // null → auto full-screen height
    this.haptic = true,
    this.delay = Duration.zero,
  });

  @override
  State<PhysicsDropIn> createState() => _PhysicsDropInState();
}

class _PhysicsDropInState extends State<PhysicsDropIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _dy;
  bool _hasFiredHaptic = false;

  @override
  void initState() {
    super.initState();

    // upperBound > 1.0 so spring overshoot isn't clamped.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      upperBound: 1.5,
    );

    final spring = SpringDescription(
      mass: 1.0,
      stiffness: widget.tension,
      damping: widget.friction,
    );

    _scale = _controller
        .drive(Tween<double>(begin: widget.initialScale, end: 1.0));

    // _dy is initialised in didChangeDependencies once we have MediaQuery.
    _dy = _controller.drive(Tween<double>(begin: 0.0, end: 0.0));

    _controller.addListener(() {
      if (!widget.haptic || _hasFiredHaptic) return;
      if (_controller.value >= 0.88) {
        _hasFiredHaptic = true;
        HapticFeedback.heavyImpact();
      }
    });

    Future.delayed(widget.delay, () {
      if (mounted) _controller.animateWith(SpringSimulation(spring, 0.0, 1.0, 0.0));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve the start offset now that we have MediaQuery.
    // We use the full screen height so the widget genuinely begins above the
    // top edge regardless of where it is positioned on screen.
    final screenH = MediaQuery.of(context).size.height;
    final offset  = -(widget.verticalOffset ?? screenH);
    _dy = _controller.drive(Tween<double>(begin: offset, end: 0.0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0.0, _dy.value),
        child: ScaleTransition(scale: _scale, child: child),
      ),
      child: widget.child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRESS-SCALE WRAPPER
// Squeezes to 93% on press, springs back on release. Listener-based so it
// never steals tap events from child buttons.
// ═════════════════════════════════════════════════════════════════════════════

class _TapScale extends StatefulWidget {
  final Widget child;
  const _TapScale({required this.child});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 380),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeIn,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      HapticFeedback.lightImpact();
      _ctrl.forward();
    },
    onPointerUp: (_) => _ctrl.reverse(),
    onPointerCancel: (_) => _ctrl.reverse(),
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
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

// ═════════════════════════════════════════════════════════════════════════════
// DASHBOARD
// ═════════════════════════════════════════════════════════════════════════════

class MealDashboard extends ConsumerStatefulWidget {
  const MealDashboard({super.key});

  @override
  ConsumerState<MealDashboard> createState() => _MealDashboardState();
}

class _MealDashboardState extends ConsumerState<MealDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double> _headerScale;
  late Animation<double> _headerDy;
  bool _headerHapticFired = false;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      upperBound: 1.5,
    );

    // Softer spring than the cards — feels like a separate, lighter layer.
    final spring = SpringDescription(mass: 1.0, stiffness: 160.0, damping: 18.0);

    _headerScale = _headerCtrl.drive(Tween<double>(begin: 1.35, end: 1.0));
    // _headerDy resolved in didChangeDependencies once MediaQuery is available.
    _headerDy    = _headerCtrl.drive(Tween<double>(begin: 0.0, end: 0.0));

    _headerCtrl.addListener(() {
      if (!_headerHapticFired && _headerCtrl.value >= 0.88) {
        _headerHapticFired = true;
        HapticFeedback.mediumImpact();
      }
    });

    _headerCtrl.animateWith(SpringSimulation(spring, 0.0, 1.0, 0.0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenH = MediaQuery.of(context).size.height;
    _headerDy = _headerCtrl.drive(Tween<double>(begin: -screenH, end: 0.0));

  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  @override
  Widget build(BuildContext context) {
    final mealScheduleState = ref.watch(mealProvider);
    final authState = ref.watch(authStateProvider);
    final now      = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr  = DateFormat('EEEE, MMM d').format(now);
    final cs       = Theme.of(context).colorScheme;

    final userName = authState.whenOrNull(
      data: (user) => user?.displayName ?? user?.email?.split('@')[0],
    ) ?? 'Please Sign In';

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [

          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            title: AnimatedBuilder(
              animation: _headerCtrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _headerDy.value * 0.5),
                child: ScaleTransition(scale: _headerScale, child: child),
              ),
              child: Text(
                'Anusha Mess',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: AnimatedBuilder(
                    animation: _headerCtrl,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _headerDy.value),
                      child: ScaleTransition(scale: _headerScale, child: child),
                    ),
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
                          userName,
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
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Current meal — snappiest drop, first in.
                if (mealScheduleState.currentMeal != null) ...[
                  PhysicsDropIn(
                    tension: 220,
                    friction: 18,
                    initialScale: 2.0,
                    delay: const Duration(milliseconds: 60),
                    child: _CurrentMealCard(meal: mealScheduleState.currentMeal!),
                  ),
                  const SizedBox(height: 12),
                ],

                // Up Next — slightly softer, cascades after current.
                if (mealScheduleState.currentMeal == null &&
                    mealScheduleState.nextMeal != null) ...[
                  PhysicsDropIn(
                    tension: 200,
                    friction: 16,
                    initialScale: 2.0,
                    delay: const Duration(milliseconds: 60),
                    child: _UpNextMealCard(
                      meal: mealScheduleState.nextMeal!,
                      showRsvp: true,
                    ),
                  ),
                ] else if (mealScheduleState.currentMeal != null &&
                    mealScheduleState.nextMeal != null) ...[
                  PhysicsDropIn(
                    tension: 200,
                    friction: 16,
                    initialScale: 2.0,
                    delay: const Duration(milliseconds: 170),
                    child: _UpNextMealCard(
                      meal: mealScheduleState.nextMeal!,
                      showRsvp: false,
                    ),
                  ),
                ],

                // Coming Up — lightest card, smallest drop, longest delay.
                if (mealScheduleState.nextToNextMeal != null) ...[
                  const SizedBox(height: 12),
                  PhysicsDropIn(
                    tension: 180,
                    friction: 15,
                    initialScale: 1.7,
                    delay: const Duration(milliseconds: 280),
                    child: _ComingUpCard(meal: mealScheduleState.nextToNextMeal!),
                  ),
                ],

                // Empty state.
                if (mealScheduleState.currentMeal == null &&
                    mealScheduleState.nextMeal == null) ...[
                  const SizedBox(height: 40),
                  PhysicsDropIn(
                    tension: 160,
                    friction: 14,
                    initialScale: 1.8,
                    delay: const Duration(milliseconds: 60),
                    child: const _EmptyStateCard(),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CURRENT MEAL CARD
// ═════════════════════════════════════════════════════════════════════════════

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(
              text: 'NOW SERVING',
              icon: Icons.restaurant_rounded,
              color: cs.onPrimaryContainer.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 6),
            Text(
              meal.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: cs.onPrimaryContainer.withValues(alpha: 0.10), height: 1),
            const SizedBox(height: 8),
            ...meal.items.map((item) => _MealItemRow(item: item)),
            const SizedBox(height: 4),
            _RsvpSection(mealInfo: meal),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UP NEXT CARD
// ═════════════════════════════════════════════════════════════════════════════

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
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 6),
            Text(
              meal.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 8),
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

// ═════════════════════════════════════════════════════════════════════════════
// COMING UP CARD
// ═════════════════════════════════════════════════════════════════════════════

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

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════════════════════

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

// ═════════════════════════════════════════════════════════════════════════════
// COUNTDOWN CHIP
// ═════════════════════════════════════════════════════════════════════════════

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
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTimeLeft());
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_timeLeft),
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
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RSVP SECTION
// ═════════════════════════════════════════════════════════════════════════════

class _RsvpSection extends ConsumerWidget {
  final MealInfo mealInfo;
  static const totalStudents = 600;

  const _RsvpSection({required this.mealInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealKey  = createMealKey(mealInfo);
    final rsvpState = ref.watch(rsvpProvider(mealKey));
    final authState = ref.watch(authStateProvider);
    final cs        = Theme.of(context).colorScheme;

    return authState.when(
      data: (user) {
        final isSignedIn = user != null;

        final String actionKey;
        if (!isSignedIn)                              actionKey = 'sign-in';
        else if (rsvpState.isLoading)                 actionKey = 'loading';
        else if (rsvpState.userSelection == RsvpOption.none) actionKey = 'buttons';
        else                                          actionKey = 'sel-${rsvpState.userSelection}';

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

              // Action area crossfades between: prompt / spinner / buttons / pill.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(actionKey),
                  child: !isSignedIn
                      ? _buildSignInPrompt(context, cs)
                      : rsvpState.isLoading
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                      : rsvpState.userSelection == RsvpOption.none
                      ? _buildButtons(context, ref, user, mealKey, cs)
                      : _buildSelectionState(context, ref, user, mealKey, rsvpState, cs),
                ),
              ),

              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),
              const SizedBox(height: 8),

              // Count flips vertically on change.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.5),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      '${rsvpState.yesCount} attending',
                      key: ValueKey(rsvpState.yesCount),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    'of $totalStudents students',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Progress bar smoothly fills.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: rsvpState.yesCount / totalStudents),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (ctx, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ),

              if (rsvpState.yesCount > 0) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showAttendeesDialog(context, mealInfo.name),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Sign in to RSVP',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
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
          child: _TapScale(
            child: FilledButton.icon(
              onPressed: () => ref
                  .read(rsvpProvider(mealKey).notifier)
                  .updateAttendance(true, user.uid, user.displayName ?? 'User', user.email ?? ''),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text("I'm in"),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TapScale(
            child: OutlinedButton.icon(
              onPressed: () => ref
                  .read(rsvpProvider(mealKey).notifier)
                  .updateAttendance(false, user.uid, user.displayName ?? 'User', user.email ?? ''),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Skipping'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
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
        // Confirmation pill bounces in with elasticOut; key re-triggers on toggle.
        TweenAnimationBuilder<double>(
          key: ValueKey(rsvpState.userSelection),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 550),
          curve: Curves.elasticOut,
          builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isYes ? cs.primaryContainer : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon pops in with easeOutBack overshoot.
                TweenAnimationBuilder<double>(
                  key: ValueKey(rsvpState.userSelection),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
                  child: Icon(
                    isYes ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 15,
                    color: isYes ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isYes ? "You're going!" : 'Skipping this one',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isYes ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        _TapScale(
          child: TextButton(
            onPressed: () =>
                ref.read(rsvpProvider(mealKey).notifier).removeAttendance(user.uid),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              textStyle: const TextStyle(fontSize: 12),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('Change my response'),
          ),
        ),
      ],
    );
  }

  void _showAttendeesDialog(BuildContext context, String mealName) {
    showDialog(
      context: context,
      builder: (context) => _AttendeesDialog(
        mealKey: createMealKey(mealInfo),
        mealName: mealName,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LIVE ATTENDEES DIALOG
// ═════════════════════════════════════════════════════════════════════════════

class _AttendeesDialog extends ConsumerWidget {
  final String mealKey;
  final String mealName;
  const _AttendeesDialog({required this.mealKey, required this.mealName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attending $mealName',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      attendeesAsync.when(
                        data: (attendees) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            '${attendees.length} student${attendees.length == 1 ? '' : 's'}',
                            key: ValueKey(attendees.length),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
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

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: attendeesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: TextStyle(color: cs.error)),
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
                    return _FadeSlideIn(
                      delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                if (a.email.isNotEmpty)
                                  Text(
                                    a.email.split('@')[0],
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _TapScale(
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FADE + SLIDE-UP
// Gentle entrance for list items inside dialogs — fades in while rising ~14px.
// ═════════════════════════════════════════════════════════════════════════════

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _dy;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _dy = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)
        .drive(Tween(begin: 14.0, end: 0.0));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, child) => Opacity(
      opacity: _opacity.value,
      child: Transform.translate(
        offset: Offset(0, _dy.value),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// LIVE DOT
// ═════════════════════════════════════════════════════════════════════════════

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
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
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
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
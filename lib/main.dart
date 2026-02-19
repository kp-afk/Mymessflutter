import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/meal_dashboard.dart';
import 'screens/history_screen.dart';
import 'screens/wastage_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyMessApp()));
}

class MyMessApp extends StatelessWidget {
  const MyMessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Mess',
      debugShowCheckedModeBanner: false,

      // ── Light Theme ─────────────────────────────────────────────────────
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE07B35),
          brightness: Brightness.light,
          surface: const Color(0xFFFFF8F4),
        ),
        useMaterial3: true,

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),

        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0.5,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),

        navigationBarTheme: NavigationBarThemeData(
          height: 64,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
            }
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500);
          }),
        ),

        dividerTheme: const DividerThemeData(space: 0, thickness: 1),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),

        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
      ),

      // ── Dark Theme ──────────────────────────────────────────────────────
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE07B35),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,

        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),

        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0.5,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
        ),

        navigationBarTheme: NavigationBarThemeData(
          height: 64,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
            }
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500);
          }),
        ),

        dividerTheme: const DividerThemeData(space: 0, thickness: 1),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),

        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
      ),

      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}

// ─── Main scaffold ─────────────────────────────────────────────────────────
//
// Key insight: screens are NOT in an IndexedStack.
// Instead, only the active screen is rendered, with a ValueKey composed of
// (tabIndex + visitCount). Every time you switch to a tab the visitCount
// increments → new key → Flutter tears down and rebuilds the widget tree →
// initState fires again → every PhysicsDropIn spring replays from scratch.

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // How many times each tab has been visited.
  // Bump on every switch so the screen gets a fresh key and rebuilds.
  final Map<int, int> _visitCount = {0: 0, 1: 0, 2: 0, 3: 0};

  // Spring-drives the whole body from 0.92 → 1.0 on each tab switch,
  // reinforcing the "lands into place" feel.
  late AnimationController _tabCtrl;
  late Animation<double> _tabScale;

  @override
  void initState() {
    super.initState();
    _tabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      upperBound: 1.5,
      value: 1.0, // start settled; first screen handles its own spring.
    );
    _tabScale = _tabCtrl.drive(Tween<double>(begin: 0.92, end: 1.0));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();

    setState(() {
      _currentIndex = index;
      // New visit count → new ValueKey → screen fully rebuilds → animations replay.
      _visitCount[index] = (_visitCount[index] ?? 0) + 1;
    });

    // Body springs into place.
    _tabCtrl.value = 0.0;
    _tabCtrl.animateWith(
      SpringSimulation(
        SpringDescription(mass: 1.0, stiffness: 300.0, damping: 22.0),
        0.0, 1.0, 0.0,
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const MealDashboard();
      case 1: return const HistoryScreen();
      case 2: return const WastageScreen();
      case 3: return const ProfileScreen();
      default: return const MealDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: ScaleTransition(
        scale: _tabScale,
        // ValueKey changes on every tab switch → fresh rebuild → springs replay.
        child: KeyedSubtree(
          key: ValueKey('tab-$_currentIndex-${_visitCount[_currentIndex]}'),
          child: _buildScreen(_currentIndex),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          onDestinationSelected: _onTabSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.delete_outline_rounded),
              selectedIcon: Icon(Icons.delete_rounded),
              label: 'Wastage',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
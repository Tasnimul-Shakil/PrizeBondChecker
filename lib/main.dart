import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/matching_engine.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/draws/draws_screen.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/settings/rules_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'services/draw_service.dart';
import 'services/locale_service.dart';
import 'services/wallet_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B192C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final matchingEngine = MatchingEngine();
  final drawService = DrawService(engine: matchingEngine);
  final walletService = WalletService();
  final localeService = LocaleService();

  // Initialize offline services and load cached data
  await drawService.initialize();
  await walletService.initialize();
  await localeService.initialize();

  runApp(
    PrizeBondApp(
      matchingEngine: matchingEngine,
      drawService: drawService,
      walletService: walletService,
    ),
  );
}

class PrizeBondApp extends StatelessWidget {
  final MatchingEngine matchingEngine;
  final DrawService drawService;
  final WalletService walletService;

  const PrizeBondApp({
    super.key,
    required this.matchingEngine,
    required this.drawService,
    required this.walletService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bangladesh Prize Bond Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B192C),
        primaryColor: const Color(0xFF006A4E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF006A4E),
          secondary: Color(0xFFD4AF37),
          surface: Color(0xFF131D2A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B192C),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: MainNavigationShell(
        matchingEngine: matchingEngine,
        drawService: drawService,
        walletService: walletService,
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final MatchingEngine matchingEngine;
  final DrawService drawService;
  final WalletService walletService;

  const MainNavigationShell({
    super.key,
    required this.matchingEngine,
    required this.drawService,
    required this.walletService,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final LocaleService _locale = LocaleService();

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ScannerScreen(
          walletService: widget.walletService,
          matchingEngine: widget.matchingEngine,
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  Future<bool> _showExitConfirmationDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.exit_to_app, color: Color(0xFFD4AF37), size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _locale.t('exit_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          _locale.t('exit_msg'),
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              _locale.t('stay'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006A4E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_locale.t('exit_btn')),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        walletService: widget.walletService,
        drawService: widget.drawService,
        matchingEngine: widget.matchingEngine,
        onOpenScanner: _openScanner,
        onOpenWallet: () => setState(() => _currentIndex = 1),
        onOpenDraws: () => setState(() => _currentIndex = 2),
      ),
      WalletScreen(
        walletService: widget.walletService,
        matchingEngine: widget.matchingEngine,
        onOpenScanner: _openScanner,
      ),
      DrawsScreen(drawService: widget.drawService),
      const RulesScreen(),
    ];

    return AnimatedBuilder(
      animation: _locale,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_currentIndex != 0) {
              setState(() {
                _currentIndex = 0;
              });
              return;
            }
            final shouldExit = await _showExitConfirmationDialog();
            if (shouldExit) {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            floatingActionButton: FloatingActionButton(
              backgroundColor: const Color(0xFF006A4E),
              foregroundColor: const Color(0xFFFFF176),
              elevation: 6,
              onPressed: _openScanner,
              child: const Icon(Icons.qr_code_scanner, size: 28),
            ),
            bottomNavigationBar: BottomAppBar(
              color: const Color(0xFF131D2A),
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavTab(icon: Icons.dashboard, label: _locale.t('nav_home'), index: 0),
                  _buildNavTab(icon: Icons.account_balance_wallet, label: _locale.t('nav_wallet'), index: 1),
                  const SizedBox(width: 48), // Space for floating scanner button
                  _buildNavTab(icon: Icons.emoji_events, label: _locale.t('nav_draws'), index: 2),
                  _buildNavTab(icon: Icons.menu_book, label: _locale.t('nav_guide'), index: 3),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavTab({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

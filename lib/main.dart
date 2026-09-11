import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/matching_engine.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/draws/draws_screen.dart';
import 'features/scanner/scanner_screen.dart';
import 'features/settings/rules_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'services/draw_service.dart';
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

  // Initialize offline services and load cached data
  await drawService.initialize();
  await walletService.initialize();

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
          background: Color(0xFF0B192C),
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

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ScannerScreen(
          walletService: widget.walletService,
          matchingEngine: widget.matchingEngine,
        ),
      ),
    ).then((_) {
      // Re-trigger build on returning from scanner
      setState(() {});
    });
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

    return Scaffold(
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
            _buildNavTab(icon: Icons.dashboard, label: 'Home', index: 0),
            _buildNavTab(icon: Icons.account_balance_wallet, label: 'Wallet', index: 1),
            const SizedBox(width: 48), // Space for floating scanner button
            _buildNavTab(icon: Icons.emoji_events, label: 'Draws', index: 2),
            _buildNavTab(icon: Icons.info_outline, label: 'Guide', index: 3),
          ],
        ),
      ),
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

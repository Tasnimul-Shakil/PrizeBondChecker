import 'package:flutter/material.dart';

/// Screen explaining Bangladesh Bank Prize Bond rules, draw schedule,
/// taxation, and claim procedure.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B192C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B192C),
        elevation: 0,
        title: const Text(
          'Prize Bond Rules & Claim Guide',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            icon: Icons.calendar_today,
            title: 'Draw Schedule',
            description:
                'Draws are held quarterly by Bangladesh Bank four times a year on:\n'
                '• 31st January\n'
                '• 30th April\n'
                '• 31st July\n'
                '• 31st October\n\n'
                'If any draw date falls on a public holiday, the draw is held on the following working day.',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.timer,
            title: '2-Year Claim Validity',
            description:
                'Prize money can be claimed within 2 years from the date of the respective draw.\n\n'
                'After 2 years, any unclaimed prize money lapses and is deposited into the Government treasury.',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.category,
            title: 'Series Agnostic Matching',
            description:
                'Bangladesh Bank draws are series-agnostic. All existing series (e.g. কখ, গঘ, চছ, etc.) '
                'bearing the winning 7-digit number receive the prize.\n\n'
                'The prefix denotes the batch, but the 7-digit integer is the primary winning key.',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.emoji_events,
            title: 'Prize Structure (Per Series)',
            description:
                '• 1st Prize: ৳6,00,000 (1 winner)\n'
                '• 2nd Prize: ৳3,25,000 (1 winner)\n'
                '• 3rd Prize: ৳1,00,000 (2 winners)\n'
                '• 4th Prize: ৳50,000 (2 winners)\n'
                '• 5th Prize: ৳10,000 (40 winners)\n\n'
                'Total: 46 prizes per series in each draw.',
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.receipt_long,
            title: 'Taxation & How to Claim',
            description:
                '• Under Bangladesh Income Tax rules, a 20% source tax is deducted from all prize bond winnings.\n'
                '• You can submit prize claims at any branch of Bangladesh Bank, National Savings Bureau, or authorized commercial banks.\n'
                '• Required documents: Original physical bond, NID copy, Bank account details, and the official claim form.',
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Text(
                  'Bangladesh Prize Bond Scanner',
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'v1.0.3 (Build 4)',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF172333),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF006A4E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFFFF176), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

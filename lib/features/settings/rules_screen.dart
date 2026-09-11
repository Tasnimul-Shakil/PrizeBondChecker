import 'package:flutter/material.dart';
import '../../services/locale_service.dart';

/// Screen explaining Bangladesh Bank Prize Bond rules, draw schedule,
/// taxation, and claim procedure with bilingual Bangla/English support.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = LocaleService();

    return AnimatedBuilder(
      animation: locale,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B192C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B192C),
            elevation: 0,
            title: Text(
              locale.t('guide_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: const [
              LanguageToggleButton(),
              SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // App Brand Header Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006A4E), Color(0xFF131D2A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF006A4E)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.stars, color: Color(0xFFD4AF37), size: 48),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locale.t('app_name'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            locale.t('guide_bb_title'),
                            style: const TextStyle(
                              color: Color(0xFFFFF176),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildInfoCard(
                icon: Icons.info_outline,
                title: locale.t('rule_1_title'),
                description: locale.t('rule_1_desc'),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.calendar_today,
                title: locale.t('rule_2_title'),
                description: locale.t('rule_2_desc'),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.timer,
                title: locale.t('rule_3_title'),
                description: locale.t('rule_3_desc'),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.receipt_long,
                title: locale.t('rule_4_title'),
                description: locale.t('rule_4_desc'),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.category,
                title: locale.t('rule_5_title'),
                description: locale.t('rule_5_desc'),
              ),
              const SizedBox(height: 24),

              Center(
                child: Column(
                  children: [
                    Text(
                      locale.t('app_name'),
                      style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        'v1.0.7 (Build 8)',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131D2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/digit_normalizer.dart';

enum AppLanguage { bangla, english }

class LocaleService extends ChangeNotifier {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  static const String _prefKey = 'app_language_preference';
  AppLanguage _currentLanguage = AppLanguage.bangla; // Default to Bangla as requested

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isBangla => _currentLanguage == AppLanguage.bangla;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_prefKey);
      if (savedLang != null) {
        _currentLanguage = savedLang == 'en' ? AppLanguage.english : AppLanguage.bangla;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language == AppLanguage.english ? 'en' : 'bn');
    } catch (_) {}
  }

  void toggleLanguage() {
    if (_currentLanguage == AppLanguage.bangla) {
      setLanguage(AppLanguage.english);
    } else {
      setLanguage(AppLanguage.bangla);
    }
  }

  /// Converts number to Bengali digits if current language is Bangla, otherwise keeps English digits.
  String formatNumber(dynamic value) {
    final str = value.toString();
    return isBangla ? DigitNormalizer.toBengaliDigits(str) : DigitNormalizer.toEnglishDigits(str);
  }

  /// Formats currency with ৳ symbol and localized digits
  String formatCurrency(double amount) {
    final formatted = DigitNormalizer.formatCurrencyBDT(amount);
    return isBangla ? DigitNormalizer.toBengaliDigits(formatted) : formatted;
  }

  /// Dictionary of translations
  static final Map<String, Map<AppLanguage, String>> _translations = {
    // Navigation
    'nav_home': {
      AppLanguage.english: 'Home',
      AppLanguage.bangla: 'হোম',
    },
    'nav_wallet': {
      AppLanguage.english: 'Wallet',
      AppLanguage.bangla: 'ওয়ালেট',
    },
    'nav_draws': {
      AppLanguage.english: 'Draws',
      AppLanguage.bangla: 'ড্র ফলাফল',
    },
    'nav_guide': {
      AppLanguage.english: 'Guide',
      AppLanguage.bangla: 'নির্দেশিকা',
    },

    // App Headers
    'app_name': {
      AppLanguage.english: 'Prize Bond Scanner',
      AppLanguage.bangla: 'প্রাইজ বন্ড স্ক্যানার',
    },
    'app_subtitle': {
      AppLanguage.english: 'BD Prize Bond Checker & Scanner',
      AppLanguage.bangla: 'বাংলাদেশ প্রাইজ বন্ড চেকার ও স্ক্যানার',
    },

    // Dashboard
    'total_bonds': {
      AppLanguage.english: 'Total Bonds',
      AppLanguage.bangla: 'মোট প্রাইজ বন্ড',
    },
    'total_investment': {
      AppLanguage.english: 'Total Investment',
      AppLanguage.bangla: 'মোট বিনিয়োগ',
    },
    'winning_bonds': {
      AppLanguage.english: 'Winning Bonds',
      AppLanguage.bangla: 'বিজয়ী বন্ড',
    },
    'total_won': {
      AppLanguage.english: 'Total Won',
      AppLanguage.bangla: 'মোট বিজয়ী টাকা',
    },
    'latest_draw': {
      AppLanguage.english: 'Latest Official Draw',
      AppLanguage.bangla: 'সর্বশেষ অফিসিয়াল ড্র',
    },
    'draw_no': {
      AppLanguage.english: 'Draw #',
      AppLanguage.bangla: 'ড্র নং ',
    },
    'draw_date': {
      AppLanguage.english: 'Draw Date',
      AppLanguage.bangla: 'ড্রয়ের তারিখ',
    },
    'quick_actions': {
      AppLanguage.english: 'Quick Actions',
      AppLanguage.bangla: 'দ্রুত সেবা',
    },
    'scan_bonds_action': {
      AppLanguage.english: 'Scan Bonds',
      AppLanguage.bangla: 'বন্ড স্ক্যান',
    },
    'scan_bonds_sub': {
      AppLanguage.english: 'Camera / Gallery',
      AppLanguage.bangla: 'ক্যামেরা ও গ্যালারি',
    },
    'add_bond_action': {
      AppLanguage.english: 'Add Bond',
      AppLanguage.bangla: 'বন্ড যোগ',
    },
    'add_bond_sub': {
      AppLanguage.english: '7-Digit Serial',
      AppLanguage.bangla: 'নম্বর লিখুন',
    },
    'draw_results_action': {
      AppLanguage.english: 'Draw Results',
      AppLanguage.bangla: 'ড্র তালিকা',
    },
    'draw_results_sub': {
      AppLanguage.english: '8 Quarters',
      AppLanguage.bangla: '৮টি অফিসিয়াল ড্র',
    },
    'check_all_bonds': {
      AppLanguage.english: 'Check All Bonds For Wins',
      AppLanguage.bangla: 'সব বন্ডের ফলাফল যাচাই করুন',
    },
    'recent_bonds': {
      AppLanguage.english: 'Recent Bonds in Wallet',
      AppLanguage.bangla: 'ওয়ালেটের সাম্প্রতিক বন্ড',
    },
    'see_all': {
      AppLanguage.english: 'See All',
      AppLanguage.bangla: 'সব দেখুন',
    },
    'no_bonds_dash': {
      AppLanguage.english: 'No prize bonds in wallet yet.',
      AppLanguage.bangla: 'ওয়ালেটে এখনও কোনো প্রাইজ বন্ড যোগ করা হয়নি।',
    },
    'no_bonds_dash_sub': {
      AppLanguage.english: 'Scan with camera or enter 7-digit serial numbers to check for prizes.',
      AppLanguage.bangla: 'পুরস্কার মেলাতে ক্যামেরা দিয়ে স্ক্যান করুন অথবা ৭ ডিজিট নম্বর লিখুন।',
    },

    // Results Modal
    'modal_winning_title': {
      AppLanguage.english: 'Winning Prize Bond Found!',
      AppLanguage.bangla: 'অভিনন্দন! বিজয়ী প্রাইজ বন্ড!',
    },
    'modal_no_win_title': {
      AppLanguage.english: 'No Winning Matches',
      AppLanguage.bangla: 'কোনো পুরস্কার মেলেনি',
    },
    'modal_checked_msg': {
      AppLanguage.english: 'Checked against the last 8 official draws (2 years eligibility).',
      AppLanguage.bangla: 'বাংলাদেশ ব্যাংকের গত ৮টি ড্রয়ের (২ বছর মেয়াদী) সাথে মেলানো হয়েছে।',
    },
    'modal_better_luck': {
      AppLanguage.english: 'Better luck in the upcoming quarterly draw!',
      AppLanguage.bangla: 'পরবর্তী ড্রয়ে আপনার জন্য শুভকামনা রইল!',
    },
    'prize_amount': {
      AppLanguage.english: 'Prize Amount',
      AppLanguage.bangla: 'পুরস্কারের পরিমাণ',
    },
    'tax_20': {
      AppLanguage.english: 'Source Tax (20%)',
      AppLanguage.bangla: 'উৎস কর (২০%)',
    },
    'net_receivable': {
      AppLanguage.english: 'Net Receivable',
      AppLanguage.bangla: 'প্রাপ্য নিট টাকা',
    },
    'close': {
      AppLanguage.english: 'Close',
      AppLanguage.bangla: 'বন্ধ করুন',
    },

    // Wallet Screen
    'my_bonds': {
      AppLanguage.english: 'My Prize Bonds',
      AppLanguage.bangla: 'আমার প্রাইজ বন্ডসমূহ',
    },
    'search_bonds': {
      AppLanguage.english: 'Search 7-digit serial number...',
      AppLanguage.bangla: '৭-সংখ্যার বন্ড নম্বর খুঁজুন...',
    },
    'filter_all': {
      AppLanguage.english: 'All Bonds',
      AppLanguage.bangla: 'সকল বন্ড',
    },
    'filter_winning': {
      AppLanguage.english: 'Winning Only',
      AppLanguage.bangla: 'শুধু বিজয়ী',
    },
    'empty_wallet_title': {
      AppLanguage.english: 'Your Wallet is Empty',
      AppLanguage.bangla: 'আপনার ওয়ালেট খালি',
    },
    'empty_wallet_sub': {
      AppLanguage.english: 'Scan paper bonds with your camera or add serial numbers manually.',
      AppLanguage.bangla: 'কাগজের প্রাইজ বন্ড ক্যামেরা দিয়ে স্ক্যান করুন অথবা নম্বর লিখে যোগ করুন।',
    },
    'manual_add_title': {
      AppLanguage.english: 'Add Prize Bond Number',
      AppLanguage.bangla: 'প্রাইজ বন্ড নম্বর যোগ করুন',
    },
    'manual_add_hint': {
      AppLanguage.english: 'Enter 7 digits (e.g. 0123456)',
      AppLanguage.bangla: '৭ সংখ্যার নম্বর দিন (যেমন: ০১২৩৪৫৬)',
    },
    'manual_add_btn': {
      AppLanguage.english: 'Add to Wallet',
      AppLanguage.bangla: 'ওয়ালেটে যোগ করুন',
    },
    'cancel': {
      AppLanguage.english: 'Cancel',
      AppLanguage.bangla: 'বাতিল',
    },
    'invalid_serial_msg': {
      AppLanguage.english: 'Please enter a valid 7-digit number.',
      AppLanguage.bangla: 'দয়া করে সঠিক ৭ ডিজিটের নম্বর দিন।',
    },
    'duplicate_bond_msg': {
      AppLanguage.english: 'This bond serial already exists in your wallet.',
      AppLanguage.bangla: 'এই বন্ড নম্বরটি ইতিমধ্যে ওয়ালেটে আছে।',
    },
    'bond_added_msg': {
      AppLanguage.english: 'Bond added successfully!',
      AppLanguage.bangla: 'বন্ড সফলভাবে ওয়ালেটে যোগ করা হয়েছে!',
    },
    'delete_confirm_title': {
      AppLanguage.english: 'Delete Bond?',
      AppLanguage.bangla: 'বন্ড মুছে ফেলবেন?',
    },
    'delete_confirm_msg': {
      AppLanguage.english: 'Are you sure you want to remove bond serial',
      AppLanguage.bangla: 'আপনি কি নিশ্চিত যে এই বন্ডটি মুছে ফেলতে চান:',
    },
    'delete': {
      AppLanguage.english: 'Delete',
      AppLanguage.bangla: 'মুছুন',
    },
    'attached_photo': {
      AppLanguage.english: 'Attached Photo',
      AppLanguage.bangla: 'সংযুক্ত ছবি',
    },
    'tap_to_view_photo': {
      AppLanguage.english: 'Tap to view full image',
      AppLanguage.bangla: 'বড় করে দেখতে চাপুন',
    },
    'winning_draw_info': {
      AppLanguage.english: 'Winning Draw Details:',
      AppLanguage.bangla: 'বিজয়ী ড্রয়ের তথ্য:',
    },
    'no_win_in_8': {
      AppLanguage.english: 'No winning matches in recent 8 draws (2 years).',
      AppLanguage.bangla: 'সাম্প্রতিক ৮টি ড্রয়ে কোনো পুরস্কার মেলেনি।',
    },

    // Scanner Screen
    'scanner_title': {
      AppLanguage.english: 'Scan Prize Bonds',
      AppLanguage.bangla: 'প্রাইজ বন্ড স্ক্যানার',
    },
    'scanner_hint': {
      AppLanguage.english: 'Align 7-digit serial number within frame',
      AppLanguage.bangla: 'ফ্রেমে ৭ ডিজিট নম্বরটি স্থিরভাবে ধরুন',
    },
    'pick_gallery': {
      AppLanguage.english: 'Gallery Photos',
      AppLanguage.bangla: 'গ্যালারি ছবি',
    },
    'selected_photos': {
      AppLanguage.english: 'Selected Photos',
      AppLanguage.bangla: 'বাছাইকৃত ছবি',
    },
    'scanned_bonds': {
      AppLanguage.english: 'Detected Bonds',
      AppLanguage.bangla: 'চিহ্নিত বন্ডসমূহ',
    },
    'save_to_wallet': {
      AppLanguage.english: 'Save to Wallet',
      AppLanguage.bangla: 'ওয়ালেটে সংরক্ষণ',
    },
    'clear_all': {
      AppLanguage.english: 'Clear',
      AppLanguage.bangla: 'মুছুন',
    },
    'no_bonds_scanned': {
      AppLanguage.english: 'No serial numbers detected yet',
      AppLanguage.bangla: 'এখনও কোনো বন্ড নম্বর পাওয়া যায়নি',
    },
    'bonds_saved_msg': {
      AppLanguage.english: 'Bonds saved to wallet!',
      AppLanguage.bangla: 'বন্ডগুলো সফলভাবে ওয়ালেটে সংরক্ষিত হয়েছে!',
    },

    // Draws Screen
    'draws_title': {
      AppLanguage.english: 'Official Draw Results',
      AppLanguage.bangla: 'অফিসিয়াল ড্র ফলাফল',
    },
    'select_draw': {
      AppLanguage.english: 'Select Draw Number',
      AppLanguage.bangla: 'ড্র নম্বর নির্বাচন করুন',
    },
    'official_bb_source': {
      AppLanguage.english: 'Official Data: Bangladesh Bank (100 Taka Bond)',
      AppLanguage.bangla: 'অফিসিয়াল তথ্যসূত্র: বাংলাদেশ ব্যাংক (১০০ টাকা বন্ড)',
    },
    'prize_1st': {
      AppLanguage.english: '1st Prize - ৳16,00,000 (1 per series)',
      AppLanguage.bangla: '১ম পুরস্কার - ১৬,০০,০০০ টাকা (প্রতি সিরিজে ১টি)',
    },
    'prize_2nd': {
      AppLanguage.english: '2nd Prize - ৳3,25,000 (1 per series)',
      AppLanguage.bangla: '২য় পুরস্কার - ৩,২৫,০০০ টাকা (প্রতি সিরিজে ১টি)',
    },
    'prize_3rd': {
      AppLanguage.english: '3rd Prize - ৳1,00,000 (2 per series)',
      AppLanguage.bangla: '৩য় পুরস্কার - ১,০০,০০০ টাকা (প্রতি সিরিজে ২টি)',
    },
    'prize_4th': {
      AppLanguage.english: '4th Prize - ৳50,000 (2 per series)',
      AppLanguage.bangla: '৪র্থ পুরস্কার - ৫০,০০০ টাকা (প্রতি সিরিজে ২টি)',
    },
    'prize_5th': {
      AppLanguage.english: '5th Prize - ৳10,000 (40 per series)',
      AppLanguage.bangla: '৫ম পুরস্কার - ১০,০০০ টাকা (প্রতি সিরিজে ৪০টি)',
    },

    // Guide Screen
    'guide_title': {
      AppLanguage.english: 'Rules & Guidelines',
      AppLanguage.bangla: 'নীতিমালা ও নির্দেশিকা',
    },
    'guide_bb_title': {
      AppLanguage.english: 'Bangladesh Bank Prize Bond Rules',
      AppLanguage.bangla: 'বাংলাদেশ ব্যাংক প্রাইজ বন্ড নিয়মাবলী',
    },
    'rule_1_title': {
      AppLanguage.english: '1. What is a ৳100 Prize Bond?',
      AppLanguage.bangla: '১. ১০০ টাকার প্রাইজ বন্ড কী?',
    },
    'rule_1_desc': {
      AppLanguage.english: 'Bangladesh ৳100 Prize Bond is a government lottery bond issued by the Internal Resources Division under Ministry of Finance. It never expires as capital.',
      AppLanguage.bangla: 'বাংলাদেশ ১০০ টাকার প্রাইজ বন্ড হলো অর্থ মন্ত্রণালয়ের অভ্যন্তরীণ সম্পদ বিভাগের অধীন ইস্যুকৃত সরকারি সঞ্চয় বন্ড। মূল অর্থ কখনো নষ্ট হয় না।',
    },
    'rule_2_title': {
      AppLanguage.english: '2. Quarterly Draw Schedule',
      AppLanguage.bangla: '২. ড্রয়ের সময়সূচি (ত্রৈমাসিক)',
    },
    'rule_2_desc': {
      AppLanguage.english: 'Draws are conducted 4 times a year: 31 January, 30 April, 31 July, and 31 October. If a draw date falls on a public holiday, it takes place on the next working day.',
      AppLanguage.bangla: 'বছরে ৪ বার ড্র অনুষ্ঠিত হয়: ৩১ জানুয়ারি, ৩০ এপ্রিল, ৩১ জুলাই এবং ৩১ অক্টোবর। ছুটির দিন হলে পরবর্তী কার্যদিবসে অনুষ্ঠিত হয়।',
    },
    'rule_3_title': {
      AppLanguage.english: '3. 2-Year Claim Validity Period',
      AppLanguage.bangla: '৩. পুরস্কার দাবির সময়সীমা (২ বছর)',
    },
    'rule_3_desc': {
      AppLanguage.english: 'Prize money must be claimed within 2 years (8 consecutive draws) from the date of the draw announcement. Unclaimed prizes lapse to the government treasury.',
      AppLanguage.bangla: 'ড্র ঘোষণার তারিখ থেকে ২ বছরের মধ্যে (সর্বমোট ৮টি ড্র) পুরস্কারের টাকা দাবি করতে হয়। ২ বছর পার হলে দাবি তামাদি হয়ে যায়।',
    },
    'rule_4_title': {
      AppLanguage.english: '4. Source Tax Deduction (20%)',
      AppLanguage.bangla: '৪. উৎসে আয়কর কর্তন (২০%)',
    },
    'rule_4_desc': {
      AppLanguage.english: 'As per National Board of Revenue (NBR) rules, 20% source tax is deducted from all prize amounts at the time of payment.',
      AppLanguage.bangla: 'জাতীয় রাজস্ব বোর্ডের (NBR) নিয়মানুযায়ী সকল পুরস্কারের অর্থ থেকে ২০% হারে উৎসে আয়কর কেটে রাখা হয়।',
    },
    'rule_5_title': {
      AppLanguage.english: '5. Series Agnostic Winning',
      AppLanguage.bangla: '৫. সিরিজ নিরপেক্ষ ফলাফল',
    },
    'rule_5_desc': {
      AppLanguage.english: 'Winning 7-digit numbers apply across all issued series (e.g. কক, কখ, গঘ, etc.). If your 7-digit serial matches, you win regardless of series prefix.',
      AppLanguage.bangla: 'ঘোষিত প্রতিটি ৭ ডিজিট নম্বর সকল সক্রিয় সিরিজের জন্য সমানভাবে প্রযোজ্য (যেমন: কক, কখ ইত্যাদি)। নম্বর মিললেই যেকোনো সিরিজে পুরস্কার পাবেন।',
    },
    'app_version': {
      AppLanguage.english: 'App Version',
      AppLanguage.bangla: 'অ্যাপ সংস্করণ',
    },

    // Exit Dialog
    'exit_title': {
      AppLanguage.english: 'Exit Application?',
      AppLanguage.bangla: 'অ্যাপ থেকে বের হতে চান?',
    },
    'exit_msg': {
      AppLanguage.english: 'Are you sure you want to close Prize Bond Scanner?',
      AppLanguage.bangla: 'আপনি কি প্রাইজ বন্ড স্ক্যানার অ্যাপটি বন্ধ করতে চান?',
    },
    'stay': {
      AppLanguage.english: 'Stay',
      AppLanguage.bangla: 'থাকুন',
    },
    'exit_btn': {
      AppLanguage.english: 'Exit App',
      AppLanguage.bangla: 'বের হন',
    },
  };

  /// Translate a given key
  String t(String key) {
    final entry = _translations[key];
    if (entry == null) return key;
    return entry[_currentLanguage] ?? entry[AppLanguage.english] ?? key;
  }
}

/// A sleek, modern Top-Right Language Switcher Button
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = LocaleService();
    return AnimatedBuilder(
      animation: locale,
      builder: (context, _) {
        final isBn = locale.isBangla;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: InkWell(
            onTap: locale.toggleLanguage,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF131D2A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBn ? const Color(0xFF006A4E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'বাং',
                      style: TextStyle(
                        color: isBn ? const Color(0xFFFFF176) : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: !isBn ? const Color(0xFF006A4E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'EN',
                      style: TextStyle(
                        color: !isBn ? const Color(0xFFFFF176) : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

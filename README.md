# Bangladesh ৳100 Prize Bond Scanner & Result Checker

A mobile utility application designed for **Android & iOS** (built with Flutter) that allows users to scan physical Bangladesh ৳100 prize bonds using their smartphone camera, automatically extract 7-digit serial numbers via on-device OCR (with full Bengali and English digit support), and cross-reference them in $O(1)$ time against official Bangladesh Bank winning draw results over the legal 2-year window.

---

## 🌟 Core Features & Architecture

### 1. Camera Scanner & On-Device ML Kit OCR
- **Guided Viewfinder**: Gold-accented bounding box positioned directly over the serial number area of physical ৳100 prize bonds.
- **On-Device OCR**: Offline, zero-latency text extraction powered by Google ML Kit (`google_mlkit_text_recognition`).
- **Torch & Camera Flip**: Seamless flash/torch toggle and lens switching.
- **Two Scanning Modes**:
  - **Single Scan**: Detects serial, freezes stream, and presents a verification modal with instant prize notification.
  - **Continuous Batch Scan**: Scan 20–30+ bonds consecutively without leaving the viewfinder. Features haptic vibration, click audio feedback, automatic deduplication, and an expandable bottom tray to review and save the entire batch in one tap.

### 2. Bengali & English Digit Normalizer
- Automatic bidirectional conversion:
  - Bengali numerals (`০, ১, ২, ৩, ৪, ৫, ৬, ৭, ৮, ৯`) $\leftrightarrow$ ASCII digits (`0, 1, 2, 3, 4, 5, 6, 7, 8, 9`).
- Regex serial number extraction: `\b\d{7}\b` with leading zero-padding support.
- Series prefix extraction: Targets prefixes preceding or adjacent to the serial (e.g., `সিরিজ কখ` or `কখ 0123456`, `KA 0123456`).
- BDT Currency formatting with Bangladeshi Lakh and Crore grouping (`৳ 6,00,000`, `৳ 3,25,000`, etc.).

### 3. $O(1)$ Winning Number Matching Engine
- **Series-Agnostic Rules**: In accordance with Bangladesh Bank regulations, all existing series sharing a drawn 7-digit number are prize winners.
- **Inverted Index ($O(1)$ Lookups)**: Re-indexes all official draws into a Hash Map `Map<String, List<PrizeMatchResult>>` on app launch. Evaluating 1 bond or 10,000 bonds occurs in microseconds.
- **2-Year Legal Window**: Automatically applies the 2-year cutoff (last 8 quarterly draws: Jan 31, Apr 30, Jul 31, Oct 31). Draws older than 2 years are marked expired.
- **Full Prize Breakdown & Tax Calculation**:
  - **1st Prize**: ৳6,00,000 (1 winner)
  - **2nd Prize**: ৳3,25,000 (1 winner)
  - **3rd Prize**: ৳1,00,000 (2 winners)
  - **4th Prize**: ৳50,000 (2 winners)
  - **5th Prize**: ৳10,000 (40 winners)
  - Automatic calculation of **20% NBR source tax** and net payable prize money.

### 4. Local Bond Wallet & Sequential Range Entry
- **Local Persistence**: Zero-cloud dependency for bond records.
- **Sequential Range Generator**: Enter start and end serials (e.g. `0154201` to `0154250`) to instantly generate up to 500 consecutive bonds with custom tags.
- **Search & Filters**: Filter by Winner status, by Series, or search by tags and numbers.
- **Export / Import Backup**: Export and restore wallet collections via JSON.

### 5. Official Draws Archive & Remote Sync
- **Bundled Offline Database**: Ships with historical draw records (`assets/data/draws_history.json`) for the last 8 quarters (Draws 112 through 119).
- **Remote Sync Service**: Checks hosted JSON endpoints (GitHub Raw / Supabase / REST) with local caching and offline fallback.

---

## 📁 Project Structure

```
PriceBondChecker/
├── android/
│   └── app/src/main/AndroidManifest.xml       # Camera & ML Kit permissions
├── assets/
│   └── data/draws_history.json                # Official 2-year winning draws DB
├── lib/
│   ├── core/
│   │   ├── digit_normalizer.dart              # Bengali/English normalizer & regex
│   │   └── matching_engine.dart               # High-speed O(1) hash table matcher
│   ├── features/
│   │   ├── dashboard/dashboard_screen.dart    # Portfolio analytics & winning alerts
│   │   ├── draws/draws_screen.dart            # Official draw browser & search
│   │   ├── scanner/
│   │   │   ├── batch_scanner_tray.dart        # Continuous scanning tray & counter
│   │   │   ├── preview_edit_modal.dart        # OCR confirmation & instant winner alert
│   │   │   └── scanner_screen.dart            # Live Camera & ML Kit OCR viewfinder
│   │   ├── settings/rules_screen.dart         # Bangladesh Bank claim guide & tax info
│   │   └── wallet/
│   │       ├── range_input_modal.dart         # Sequential serial generator
│   │       └── wallet_screen.dart             # Bond list, filters & claim details
│   ├── models/
│   │   ├── bond.dart                          # Bond domain model
│   │   └── draw.dart                          # Draw, PrizeTier & Match models
│   ├── services/
│   │   ├── draw_service.dart                  # Draw loader, cache & remote sync
│   │   └── wallet_service.dart                # Local wallet CRUD & JSON backup
│   └── main.dart                              # Entry point, theme & navigation
├── scripts/
│   └── verify_engine.js                       # Node.js validation test script
├── test/
│   ├── dart_test_runner.dart                  # Pure Dart integration test suite
│   ├── digit_normalizer_test.dart             # Unit tests for DigitNormalizer
│   ├── matching_engine_test.dart              # Unit tests for MatchingEngine
│   └── range_generator_test.dart              # Unit tests for Range generator
└── pubspec.yaml                               # Flutter dependencies & assets config
```

---

## 🧪 Verification & Testing

### Running the Dart Integration Test Suite:
```powershell
dart test/dart_test_runner.dart
```

### Running the Algorithmic Test Suite in Node.js:
```powershell
node scripts/verify_engine.js
```

---

## 🚀 Running on Mobile (Android / iOS)

1. Ensure Flutter is installed (`flutter doctor`).
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run on connected device or emulator:
   ```bash
   flutter run
   ```

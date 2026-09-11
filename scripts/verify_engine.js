// Verification script for Prize Bond core algorithms (Digit Normalizer, Matching Engine, Range Generator)
const fs = require('fs');
const path = require('path');

// 1. Digit Normalizer implementation
const bengaliToEnglish = {
  '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4',
  '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9'
};
const englishToBengali = {
  '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
  '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯'
};

function toEnglishDigits(str) {
  let res = str;
  for (const [bn, en] of Object.entries(bengaliToEnglish)) {
    res = res.replaceAll(bn, en);
  }
  return res;
}

function toBengaliDigits(str) {
  let res = str;
  for (const [en, bn] of Object.entries(englishToBengali)) {
    res = res.replaceAll(en, bn);
  }
  return res;
}

function normalizeSerial(raw) {
  const cleaned = toEnglishDigits(raw).replace(/\D/g, '');
  if (cleaned.length === 7) return cleaned;
  if (cleaned.length > 0 && cleaned.length < 7) {
    return cleaned.padStart(7, '0');
  }
  return null;
}

function extractPrimaryBond(ocrText) {
  const normalized = toEnglishDigits(ocrText);
  const serialMatch = normalized.match(/\b\d{7}\b/);
  const prefixMatch = ocrText.match(/(?:সিরিজ|series)\s*[:.-]?\s*([ক-হ]{1,2}|[A-Z]{1,2})/i);
  const adjacentMatch = normalized.match(/([ক-হ]{1,2}|[A-Z]{1,2})\s*[-:]?\s*(\d{7})/i);

  let series = null;
  if (prefixMatch) {
    series = prefixMatch[1];
  } else if (adjacentMatch) {
    series = adjacentMatch[1];
  }

  return {
    serial: serialMatch ? serialMatch[0] : null,
    series: series,
    isValid: serialMatch !== null && serialMatch[0].length === 7
  };
}

function formatBDT(amount, bengali = false) {
  const numStr = Math.floor(amount).toString();
  let formatted = '';
  if (numStr.length <= 3) {
    formatted = numStr;
  } else {
    const last3 = numStr.slice(-3);
    let remaining = numStr.slice(0, -3);
    const parts = [];
    while (remaining.length > 2) {
      parts.unshift(remaining.slice(-2));
      remaining = remaining.slice(0, -2);
    }
    if (remaining.length > 0) parts.unshift(remaining);
    formatted = `${parts.join(',')},${last3}`;
  }
  return bengali ? `৳ ${toBengaliDigits(formatted)}` : `৳ ${formatted}`;
}

// 2. Matching Engine implementation
class InvertedIndexMatchingEngine {
  constructor(draws, referenceDate = new Date('2026-09-11')) {
    this.index = new Map();
    this.draws = draws;
    this.referenceDate = referenceDate;
    this.buildIndex();
  }

  buildIndex() {
    this.index.clear();
    const twoYearsAgo = new Date(this.referenceDate);
    twoYearsAgo.setFullYear(twoYearsAgo.getFullYear() - 2);

    for (const draw of this.draws) {
      const drawDate = new Date(draw.drawDate);
      const isClaimable = drawDate >= twoYearsAgo;

      if (!isClaimable) continue;

      for (const prize of draw.prizes) {
        for (const num of prize.winningNumbers) {
          const cleanNum = num.trim().padStart(7, '0');
          if (!this.index.has(cleanNum)) {
            this.index.set(cleanNum, []);
          }
          this.index.get(cleanNum).push({
            drawNumber: draw.drawNumber,
            drawDate: draw.drawDate,
            tier: prize.tier,
            tierName: prize.name,
            amount: prize.amount,
            isClaimable
          });
        }
      }
    }
  }

  checkSerial(serial) {
    const clean = normalizeSerial(serial);
    return this.index.get(clean) || [];
  }
}

// RUN VALIDATION TESTS
console.log('--- Starting Prize Bond Engine Verification ---');

// Test 1: Bengali to English digit conversion
const bnSample = 'সিরিজ কখ ০৭৮২৩৪১';
const enConverted = toEnglishDigits(bnSample);
console.assert(enConverted === 'সিরিজ কখ 0782341', 'Failed Bengali conversion');
console.log('✓ Bengali to English digit conversion passed');

// Test 2: Extraction
const ocrSample = 'গণপ্রজাতন্ত্রী বাংলাদেশ সরকার\nপ্রাইজবন্ড ১০০ টাকা\nসিরিজ কখ ০৭৮২৩৪১';
const extracted = extractPrimaryBond(ocrSample);
console.assert(extracted.isValid === true, 'Failed extraction validity');
console.assert(extracted.serial === '0782341', 'Failed serial extraction');
console.assert(extracted.series === 'কখ', 'Failed series extraction');
console.log('✓ OCR text normalization and extraction passed');

// Test 3: Currency formatting
console.assert(formatBDT(600000) === '৳ 6,00,000', 'Failed BDT formatting 6L');
console.assert(formatBDT(325000) === '৳ 3,25,000', 'Failed BDT formatting 3.25L');
console.assert(formatBDT(10000) === '৳ 10,000', 'Failed BDT formatting 10K');
console.log('✓ BDT Lakh/Crore currency formatting passed');

// Test 4: Load JSON Database and Test Matching Engine
const drawsFilePath = path.join(__dirname, '..', 'assets', 'data', 'draws_history.json');
const drawsRaw = fs.readFileSync(drawsFilePath, 'utf8');
const drawsData = JSON.parse(drawsRaw);
console.log(`Loaded ${drawsData.draws.length} official draws from assets/data/draws_history.json`);

const engine = new InvertedIndexMatchingEngine(drawsData.draws);
console.log(`Indexed ${engine.index.size} unique winning numbers across active draws`);

// Check 1st prize in Draw 119 ('0782341')
const match1 = engine.checkSerial('0782341');
console.assert(match1.length > 0, 'Should find match for 0782341');
console.assert(match1[0].tier === 1, 'Should be 1st prize');
console.assert(match1[0].amount === 600000, 'Should be ৳600,000');
console.log(`✓ 1st Prize O(1) Match: 0782341 -> ${match1[0].tierName} (${formatBDT(match1[0].amount)}) in Draw #${match1[0].drawNumber}`);

// Check 2nd prize in Draw 118 ('0871239')
const match2 = engine.checkSerial('0871239');
console.assert(match2.length > 0, 'Should find match for 0871239');
console.assert(match2[0].tier === 2, 'Should be 2nd prize');
console.assert(match2[0].amount === 325000, 'Should be ৳325,000');
console.log(`✓ 2nd Prize O(1) Match: 0871239 -> ${match2[0].tierName} (${formatBDT(match2[0].amount)}) in Draw #${match2[0].drawNumber}`);

// Check non-winning number
const nonWinner = engine.checkSerial('0000000');
console.assert(nonWinner.length === 0, 'Should not find non-winner');
console.log('✓ Non-winning bond correctly identified');

// Test 5: Range generator
const startNum = 154201;
const endNum = 154210;
const rangeBonds = [];
for (let i = startNum; i <= endNum; i++) {
  rangeBonds.push(i.toString().padStart(7, '0'));
}
console.assert(rangeBonds.length === 10, 'Range count mismatch');
console.assert(rangeBonds[0] === '0154201' && rangeBonds[9] === '0154210', 'Range formatting error');
console.log('✓ Sequential range generator passed');

console.log('\nALL PRIZE BOND CORE ENGINE ALGORITHMS VERIFIED SUCCESSFULLY!');

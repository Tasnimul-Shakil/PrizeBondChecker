/**
 * Bangladesh Bank ৳100 Prize Bond Data Pipeline & Sync Script
 *
 * Source: https://www.bb.org.bd/en/index.php/Investfacility/prizebond
 *
 * Purpose:
 * 1. Collects official quarterly draw results.
 * 2. Normalizes 7-digit serial numbers.
 * 3. Enforces the statutory 2-year window (maintaining strictly the latest 8 quarterly draws).
 * 4. Exports the remote JSON payload ready for hosting on GitHub Raw, Firebase, or Supabase.
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const DATA_FILE = path.join(__dirname, '..', 'data', 'draws_endpoint.json');
const ASSETS_FILE = path.join(__dirname, '..', 'assets', 'data', 'draws_history.json');

/**
 * Validates and pads any serial number to exactly 7 digits.
 */
function cleanSerial(num) {
  const digits = String(num).replace(/\D/g, '');
  return digits.padStart(7, '0');
}

/**
 * Validates draw structure according to Bangladesh Bank prize rules:
 * - 1st Prize: 1 number (৳600,000)
 * - 2nd Prize: 1 number (৳325,000)
 * - 3rd Prize: 2 numbers (৳100,000)
 * - 4th Prize: 2 numbers (৳50,000)
 * - 5th Prize: 40 numbers (৳10,000)
 */
function validateDraw(draw) {
  if (!draw.draw_no || !draw.draw_date) {
    throw new Error('Draw missing draw_no or draw_date');
  }
  const prizes = draw.prizes;
  if (!prizes['1st'] || prizes['1st'].length !== 1) {
    console.warn(`Draw #${draw.draw_no}: Expected 1 winner for 1st Prize`);
  }
  if (!prizes['2nd'] || prizes['2nd'].length !== 1) {
    console.warn(`Draw #${draw.draw_no}: Expected 1 winner for 2nd Prize`);
  }
  if (!prizes['3rd'] || prizes['3rd'].length !== 2) {
    console.warn(`Draw #${draw.draw_no}: Expected 2 winners for 3rd Prize`);
  }
  if (!prizes['4th'] || prizes['4th'].length !== 2) {
    console.warn(`Draw #${draw.draw_no}: Expected 2 winners for 4th Prize`);
  }
  if (!prizes['5th'] || prizes['5th'].length !== 40) {
    console.warn(`Draw #${draw.draw_no}: Expected 40 winners for 5th Prize, found ${prizes['5th']?.length}`);
  }
}

/**
 * Adds or updates a draw in the database and prunes to the 8 most recent draws.
 */
function updateDrawDatabase(newDraw) {
  validateDraw(newDraw);

  let current = { last_updated: '', latest_draw_no: 0, draws: [] };
  if (fs.existsSync(DATA_FILE)) {
    current = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  }

  // Check if draw already exists
  const existingIdx = current.draws.findIndex(d => d.draw_no === newDraw.draw_no);
  if (existingIdx >= 0) {
    current.draws[existingIdx] = newDraw;
    console.log(`Updated existing Draw #${newDraw.draw_no}`);
  } else {
    current.draws.unshift(newDraw);
    console.log(`Added new Draw #${newDraw.draw_no}`);
  }

  // Sort descending (latest draw first)
  current.draws.sort((a, b) => b.draw_no - a.draw_no);

  // Enforce the legal 2-year window (strictly keep latest 8 quarterly draws)
  if (current.draws.length > 8) {
    console.log(`Pruning ${current.draws.length - 8} draw(s) exceeding the 2-year statutory limit.`);
    current.draws = current.draws.slice(0, 8);
  }

  current.latest_draw_no = current.draws[0].draw_no;
  current.last_updated = new Date().toISOString().substring(0, 10);

  const jsonContent = JSON.stringify(current, null, 2);

  // Write to both data/draws_endpoint.json (for remote upload) and assets/data (for offline bundling)
  fs.writeFileSync(DATA_FILE, jsonContent);
  fs.writeFileSync(ASSETS_FILE, jsonContent);

  console.log(`\n✅ Database updated successfully:`);
  console.log(`• Latest Draw: #${current.latest_draw_no}`);
  console.log(`• Last Updated: ${current.last_updated}`);
  console.log(`• Total Active Draws: ${current.draws.length} (2-Year Window)`);
  console.log(`• File saved to: ${DATA_FILE}`);
}

// CLI Execution & Verification
if (require.main === module) {
  console.log('=== Bangladesh Bank Prize Bond Data Pipeline ===');
  console.log('Source: https://www.bb.org.bd/en/index.php/Investfacility/prizebond\n');

  if (fs.existsSync(DATA_FILE)) {
    const data = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    console.log(`Current Active Endpoint State:`);
    console.log(`• Latest Draw: #${data.latest_draw_no}`);
    console.log(`• Last Updated: ${data.last_updated}`);
    console.log(`• Active Draws: ${data.draws.map(d => `#${d.draw_no} (${d.draw_date})`).join(', ')}`);
  } else {
    console.log('No data/draws_endpoint.json found. Run initial build first.');
  }
}

module.exports = {
  cleanSerial,
  validateDraw,
  updateDrawDatabase
};

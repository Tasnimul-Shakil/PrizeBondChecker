const fs = require('fs');
const path = require('path');

const drawsConfig = [
  { draw_no: 124, date: '2026-08-02' },
  { draw_no: 123, date: '2026-04-30' },
  { draw_no: 122, date: '2026-01-31' },
  { draw_no: 121, date: '2025-10-31' },
  { draw_no: 120, date: '2025-07-31' },
  { draw_no: 119, date: '2025-04-30' },
  { draw_no: 118, date: '2025-02-02' },
  { draw_no: 117, date: '2024-10-31' },
];

function extractDraw(drawNo, date) {
  const textPath = path.join(__dirname, `${drawNo}_text.txt`);
  const text = fs.readFileSync(textPath, 'utf8');

  // 1st prize
  const p1Match = text.match(/1g\s*cyi¯‹vi[^\n\r]*?(\d{7})/);
  if (!p1Match) throw new Error(`Draw ${drawNo}: 1st prize not found`);
  const firstPrize = [p1Match[1]];

  // 2nd prize
  const p2Match = text.match(/2q\s*cyi¯‹vi[^\n\r]*?(\d{7})/);
  if (!p2Match) throw new Error(`Draw ${drawNo}: 2nd prize not found`);
  const secondPrize = [p2Match[1]];

  // Sections
  const p3Index = text.search(/3q\s*cyi¯‹vi/);
  const p4Index = text.search(/4_©\s*cyi¯‹vi/);
  const p5Index = text.search(/5g\s*cyi¯‹vi/);

  if (p3Index === -1 || p4Index === -1 || p5Index === -1) {
    throw new Error(`Draw ${drawNo}: Prize sections not found`);
  }

  const p3Text = text.substring(p3Index, p4Index);
  const p4Text = text.substring(p4Index, p5Index);
  const p5Text = text.substring(p5Index);

  // Extract 7-digit numbers
  const thirdPrize = [...p3Text.matchAll(/\b\d{7}\b/g)].map(m => m[0]);
  const fourthPrize = [...p4Text.matchAll(/\b\d{7}\b/g)].map(m => m[0]);
  const allP5Numbers = [...p5Text.matchAll(/\b\d{7}\b/g)].map(m => m[0]);

  // 5th prize has exactly 40 numbers
  const fifthPrize = allP5Numbers.slice(0, 40);

  if (thirdPrize.length !== 2) {
    throw new Error(`Draw ${drawNo}: Expected 2 3rd prizes, got ${thirdPrize.length}`);
  }
  if (fourthPrize.length !== 2) {
    throw new Error(`Draw ${drawNo}: Expected 2 4th prizes, got ${fourthPrize.length}`);
  }
  if (fifthPrize.length !== 40) {
    throw new Error(`Draw ${drawNo}: Expected 40 5th prizes, got ${fifthPrize.length}`);
  }

  return {
    draw_no: drawNo,
    draw_date: date,
    prizes: {
      "1st": firstPrize,
      "2nd": secondPrize,
      "3rd": thirdPrize,
      "4th": fourthPrize,
      "5th": fifthPrize
    }
  };
}

const draws = drawsConfig.map(cfg => extractDraw(cfg.draw_no, cfg.date));

const outputData = {
  last_updated: '2026-08-02',
  latest_draw_no: 124,
  draws: draws
};

const drawsEndpointPath = path.join(__dirname, '..', 'data', 'draws_endpoint.json');
const drawsHistoryPath = path.join(__dirname, '..', 'assets', 'data', 'draws_history.json');

fs.writeFileSync(drawsEndpointPath, JSON.stringify(outputData, null, 2), 'utf8');
fs.writeFileSync(drawsHistoryPath, JSON.stringify(outputData, null, 2), 'utf8');

console.log('SUCCESS: Generated official Bangladesh Bank draws data!');
console.log(`Updated: ${drawsEndpointPath}`);
console.log(`Updated: ${drawsHistoryPath}`);
console.log(`Total draws: ${draws.length}`);
draws.forEach(d => {
  console.log(`Draw #${d.draw_no} (${d.draw_date}): 1st: ${d.prizes['1st'][0]}, 2nd: ${d.prizes['2nd'][0]}, 3rd: ${d.prizes['3rd'].length}, 4th: ${d.prizes['4th'].length}, 5th: ${d.prizes['5th'].length}`);
});

const fs = require('fs');
const { execSync } = require('child_process');
const { PDFParse } = require('./node_modules/pdf-parse');

const drawsConfig = [
  { draw_no: 124, url: 'https://www.bb.org.bd/investfacility/prizebond/124thdraw.pdf', date: '2026-08-02' },
  { draw_no: 123, url: 'https://www.bb.org.bd/investfacility/prizebond/123rddraw.pdf', date: '2026-04-30' },
  { draw_no: 122, url: 'https://www.bb.org.bd/investfacility/prizebond/122nddraw.pdf', date: '2026-01-31' },
  { draw_no: 121, url: 'https://www.bb.org.bd/investfacility/prizebond/121stdraw.pdf', date: '2025-10-31' },
  { draw_no: 120, url: 'https://www.bb.org.bd/investfacility/prizebond/120thdraw.pdf', date: '2025-07-31' },
  { draw_no: 119, url: 'https://www.bb.org.bd/investfacility/prizebond/119thdraw.pdf', date: '2025-04-30' },
  { draw_no: 118, url: 'https://www.bb.org.bd/investfacility/prizebond/118thdraw.pdf', date: '2025-02-02' },
  { draw_no: 117, url: 'https://www.bb.org.bd/investfacility/prizebond/117thdraw.pdf', date: '2024-10-31' },
];

async function downloadAndParse() {
  const allDraws = [];

  for (const item of drawsConfig) {
    const pdfPath = `./scripts/${item.draw_no}thdraw.pdf`;
    console.log(`\n========================================`);
    console.log(`Downloading Draw #${item.draw_no} from ${item.url}...`);
    try {
      execSync(`curl.exe -k -s "${item.url}" -o "${pdfPath}"`, { stdio: 'inherit' });
    } catch (e) {
      console.error(`Failed to download ${item.url}:`, e.message);
      continue;
    }

    const buf = fs.readFileSync(pdfPath);
    const parser = new PDFParse({ data: buf });
    const res = await parser.getText();
    const text = res.text;
    fs.writeFileSync(`./scripts/${item.draw_no}_text.txt`, text);

    console.log(`Extracting numbers for Draw #${item.draw_no}... (text length: ${text.length})`);
    
    // Let's inspect the text structure
    const lines = text.split(/\r?\n/);
    console.log(`Sample lines (first 25):`);
    console.log(lines.slice(0, 25).join('\n'));
  }
}

downloadAndParse().catch(console.error);

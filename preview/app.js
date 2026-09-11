// Live Interactive Prize Bond App Simulation & Logic Engine
(function() {
  // Digit Maps
  const bnToEn = { '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4', '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9' };
  const enToBn = { '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪', '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯' };

  function toEnglishDigits(str) {
    if (!str) return '';
    let res = str.toString();
    for (const [bn, en] of Object.entries(bnToEn)) res = res.replaceAll(bn, en);
    return res;
  }

  function toBengaliDigits(str) {
    if (!str) return '';
    let res = str.toString();
    for (const [en, bn] of Object.entries(enToBn)) res = res.replaceAll(en, bn);
    return res;
  }

  function formatBDT(amount, bn = false) {
    const num = Math.floor(amount || 0);
    const numStr = num.toString();
    let formatted = '';
    if (numStr.length <= 3) {
      formatted = numStr;
    } else {
      const last3 = numStr.slice(-3);
      let rem = numStr.slice(0, -3);
      const parts = [];
      while (rem.length > 2) {
        parts.unshift(rem.slice(-2));
        rem = rem.slice(0, -2);
      }
      if (rem.length > 0) parts.unshift(rem);
      formatted = `${parts.join(',')},${last3}`;
    }
    return bn ? `৳ ${toBengaliDigits(formatted)}` : `৳ ${formatted}`;
  }

  // App State
  let drawsData = [];
  let userBonds = [];
  const winningIndex = new Map(); // O(1) Inverted Index: '0782341' -> [{drawNumber, tier, amount, etc.}]
  let activeScanMode = 'single'; // 'single' | 'batch'
  let batchCaptured = [];
  let mediaStream = null;
  let activeWalletFilter = 'all';

  // Clock in status bar
  function updateClock() {
    const now = new Date();
    const clockEl = document.getElementById('status-clock');
    if (clockEl) {
      clockEl.textContent = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
  }
  setInterval(updateClock, 1000);
  updateClock();

  // Load User Bonds from LocalStorage
  function loadLocalBonds() {
    try {
      const saved = localStorage.getItem('prize_bonds_v1');
      if (saved) {
        userBonds = JSON.parse(saved);
      } else {
        // Seed with realistic demo bonds if empty
        userBonds = [
          { id: 'b1', serial: '0782341', series: 'কখ', tags: ['Demo Winner'], date: '2026-08-01' },
          { id: 'b2', serial: '0421890', series: 'গঘ', tags: ['Family'], date: '2026-08-02' },
          { id: 'b3', serial: '0154201', series: 'কখ', tags: ['Bank Range'], date: '2026-08-03' },
          { id: 'b4', serial: '0154202', series: 'কখ', tags: ['Bank Range'], date: '2026-08-03' },
        ];
        saveLocalBonds();
      }
    } catch (e) {
      userBonds = [];
    }
  }

  function saveLocalBonds() {
    try {
      localStorage.setItem('prize_bonds_v1', JSON.stringify(userBonds));
    } catch (e) {}
  }

  // Build O(1) Inverted Hash Table Index
  function buildWinningIndex(draws) {
    winningIndex.clear();
    const referenceDate = new Date('2026-09-11');
    const twoYearsAgo = new Date(referenceDate);
    twoYearsAgo.setFullYear(twoYearsAgo.getFullYear() - 2);

    for (const draw of draws) {
      const dDate = new Date(draw.drawDate);
      const isClaimable = dDate >= twoYearsAgo;

      for (const prize of draw.prizes) {
        for (const num of prize.winningNumbers) {
          const cleanNum = num.toString().trim().padStart(7, '0');
          if (!winningIndex.has(cleanNum)) {
            winningIndex.set(cleanNum, []);
          }
          winningIndex.get(cleanNum).push({
            drawNumber: draw.drawNumber,
            drawDate: draw.drawDate,
            tier: prize.tier,
            tierName: prize.name,
            tierNameBn: prize.nameBn,
            amount: prize.amount,
            isClaimable
          });
        }
      }
    }
  }

  // Check Bond in O(1)
  function checkBond(serial) {
    const clean = toEnglishDigits(serial).replace(/\D/g, '').padStart(7, '0');
    return winningIndex.get(clean) || [];
  }

  // Load Draws Data from Server JSON
  async function loadDraws() {
    try {
      const res = await fetch('/assets/data/draws_history.json');
      const data = await res.json();
      drawsData = data.draws || [];
      buildWinningIndex(drawsData);
      renderDashboard();
      renderDraws();
      renderWallet();
    } catch (e) {
      console.error('Failed to load draws JSON:', e);
    }
  }

  // RENDER DASHBOARD
  function renderDashboard() {
    let totalWon = 0;
    let winningBondsCount = 0;

    userBonds.forEach(b => {
      const matches = checkBond(b.serial);
      if (matches.length > 0) {
        winningBondsCount++;
        matches.forEach(m => totalWon += m.amount);
      }
    });

    const portfolioVal = userBonds.length * 100;
    const netWon = totalWon * 0.80; // 20% NBR tax

    document.getElementById('hero-bonds-count').textContent = `${userBonds.length} Bonds`;
    document.getElementById('hero-won-amount').textContent = formatBDT(totalWon);
    document.getElementById('hero-net-amount').textContent = `Net: ${formatBDT(netWon)} (after 20% NBR tax)`;
    document.getElementById('hero-portfolio-val').textContent = formatBDT(portfolioVal);
    document.getElementById('hero-win-fraction').textContent = `${winningBondsCount} / ${userBonds.length}`;

    // Winner banner
    const winnerCard = document.getElementById('dashboard-winner-card');
    if (winningBondsCount > 0) {
      winnerCard.classList.remove('hidden');
      document.getElementById('winner-alert-msg').textContent =
        `You have ${winningBondsCount} winning bond(s) in active draws!`;
    } else {
      winnerCard.classList.add('hidden');
    }

    // Latest Draw Announcement
    if (drawsData.length > 0) {
      const latest = drawsData[0];
      document.getElementById('announcement-draw-no').textContent =
        `Draw #${latest.drawNumber} Results Active (${latest.drawDate})`;
    }

    // Recent Bonds
    const recentCont = document.getElementById('recent-bonds-container');
    recentCont.innerHTML = '';
    const recent = userBonds.slice(0, 4);

    if (recent.length === 0) {
      recentCont.innerHTML = '<div class="empty-placeholder">No bonds added yet. Tap "Scan Bond" to start.</div>';
      return;
    }

    recent.forEach(bond => {
      const matches = checkBond(bond.serial);
      const isWinner = matches.length > 0;

      const card = document.createElement('div');
      card.className = `bond-card ${isWinner ? 'is-winner' : ''}`;
      card.innerHTML = `
        <div class="bond-avatar">${isWinner ? '🏆' : '🎫'}</div>
        <div class="bond-info">
          <div class="bond-serial-row">
            <span class="bond-name">${bond.series ? bond.series + ' ' : ''}${bond.serial}</span>
            <span class="bond-bn-digits">${toBengaliDigits(bond.serial)}</span>
          </div>
          <div class="bond-sub ${isWinner ? 'bond-winner-sub' : ''}">
            ${isWinner ? `🎉 Won ${formatBDT(matches[0].amount)} (${matches[0].tierName})` : (bond.tags?.[0] || '৳100 Prize Bond')}
          </div>
        </div>
        <div style="color: #666;">›</div>
      `;
      card.onclick = () => openBondDetails(bond);
      recentCont.appendChild(card);
    });
  }

  // RENDER WALLET
  function renderWallet() {
    const cont = document.getElementById('wallet-list-container');
    cont.innerHTML = '';

    const query = document.getElementById('wallet-search')?.value.toLowerCase().trim() || '';

    const filtered = userBonds.filter(b => {
      const matches = checkBond(b.serial);
      if (activeWalletFilter === 'winners' && matches.length === 0) return false;
      if (query) {
        const matchesSerial = b.serial.includes(query);
        const matchesSeries = b.series?.toLowerCase().includes(query);
        const matchesTag = b.tags?.some(t => t.toLowerCase().includes(query));
        if (!matchesSerial && !matchesSeries && !matchesTag) return false;
      }
      return true;
    });

    if (filtered.length === 0) {
      cont.innerHTML = `
        <div class="empty-placeholder">
          <div style="font-size: 36px; margin-bottom: 8px;">📭</div>
          <div style="font-weight: 700; color: #fff;">No Prize Bonds Found</div>
          <div style="margin-top: 4px;">Try scanning or adding a sequential range.</div>
        </div>
      `;
      return;
    }

    filtered.forEach(bond => {
      const matches = checkBond(bond.serial);
      const isWinner = matches.length > 0;

      const card = document.createElement('div');
      card.className = `bond-card ${isWinner ? 'is-winner' : ''}`;
      card.innerHTML = `
        <div class="bond-avatar">${isWinner ? '🏆' : '🎫'}</div>
        <div class="bond-info">
          <div class="bond-serial-row">
            <span class="bond-name">${bond.series ? bond.series + ' ' : ''}${bond.serial}</span>
            <span class="bond-bn-digits">${toBengaliDigits(bond.serial)}</span>
          </div>
          <div class="bond-sub ${isWinner ? 'bond-winner-sub' : ''}">
            ${isWinner ? `🎉 Won ${formatBDT(matches[0].amount)} (${matches[0].tierName} in Draw #${matches[0].drawNumber})` : (bond.tags?.[0] || '৳100 Prize Bond')}
          </div>
        </div>
        <div style="color: #666;">›</div>
      `;
      card.onclick = () => openBondDetails(bond);
      cont.appendChild(card);
    });
  }

  // RENDER DRAWS ARCHIVE
  let selectedDrawIndex = 0;

  function renderDraws() {
    const chipsRow = document.getElementById('draws-selector-row');
    chipsRow.innerHTML = '';

    drawsData.forEach((draw, idx) => {
      const btn = document.createElement('button');
      btn.className = `draw-tab-btn ${idx === selectedDrawIndex ? 'active' : ''}`;
      btn.textContent = `Draw #${draw.drawNumber}`;
      btn.onclick = () => {
        selectedDrawIndex = idx;
        renderDraws();
      };
      chipsRow.appendChild(btn);
    });

    const detailCont = document.getElementById('draw-detail-container');
    detailCont.innerHTML = '';

    const draw = drawsData[selectedDrawIndex];
    if (!draw) return;

    // Draw header
    const head = document.createElement('div');
    head.style.marginBottom = '14px';
    head.innerHTML = `
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <span style="font-size: 16px; font-weight: 800; color: #D4AF37;">Draw #${draw.drawNumber} (${draw.drawDate})</span>
        <span style="background: rgba(255,255,255,0.1); padding: 3px 8px; border-radius: 6px; font-size: 11px;">46 Prizes</span>
      </div>
    `;
    detailCont.appendChild(head);

    draw.prizes.forEach(tier => {
      const card = document.createElement('div');
      card.className = `prize-tier-card ${tier.tier === 1 ? 'tier-1' : ''}`;

      const numsHtml = tier.winningNumbers.map(n => `<span class="draw-num-pill">${n}</span>`).join('');

      card.innerHTML = `
        <div class="prize-tier-head">
          <span class="prize-tier-title">${tier.name} (${tier.nameBn})</span>
          <span class="prize-tier-amount">${formatBDT(tier.amount)}</span>
        </div>
        <div style="font-size: 11px; color: #8E9BAE;">${tier.winningNumbers.length} winning number(s):</div>
        <div class="numbers-wrap">${numsHtml}</div>
      `;
      detailCont.appendChild(card);
    });
  }

  // OPEN BOND DETAILS MODAL
  let currentViewingBond = null;
  function openBondDetails(bond) {
    currentViewingBond = bond;
    const modal = document.getElementById('detail-modal');
    document.getElementById('detail-bond-name').textContent = `${bond.series ? bond.series + ' ' : ''}${bond.serial}`;
    document.getElementById('detail-bond-bn').textContent = `বাংলা: ${bond.series ? bond.series + ' ' : ''}${toBengaliDigits(bond.serial)}`;

    const prizeSec = document.getElementById('detail-prize-section');
    prizeSec.innerHTML = '';

    const matches = checkBond(bond.serial);
    if (matches.length > 0) {
      matches.forEach(m => {
        const item = document.createElement('div');
        item.style.background = 'rgba(0, 106, 78, 0.3)';
        item.style.border = '1px solid #006A4E';
        item.style.borderRadius = '12px';
        item.style.padding = '12px';
        item.style.marginBottom = '8px';
        item.innerHTML = `
          <div style="display: flex; justify-content: space-between; font-weight: 800;">
            <span style="color: #00FF66;">${m.tierName} (${m.tierNameBn})</span>
            <span style="color: #FFF176; font-size: 16px;">${formatBDT(m.amount)}</span>
          </div>
          <div style="font-size: 12px; color: #bbb; margin-top: 4px;">Draw #${m.drawNumber} • ${m.drawDate}</div>
          <div style="font-size: 11px; color: #888; margin-top: 2px;">Net (after 20% source tax): ${formatBDT(m.amount * 0.80)}</div>
        `;
        prizeSec.appendChild(item);
      });
    } else {
      prizeSec.innerHTML = `
        <div style="background: rgba(255,255,255,0.05); padding: 14px; border-radius: 12px; font-size: 12px; color: #8E9BAE; text-align: center;">
          ℹ️ No winning match found in the legal 2-year window (last 8 quarterly draws).
        </div>
      `;
    }

    modal.classList.remove('hidden');
  }

  // DELETE BOND
  document.getElementById('btn-delete-bond')?.addEventListener('click', () => {
    if (!currentViewingBond) return;
    userBonds = userBonds.filter(b => b.id !== currentViewingBond.id);
    saveLocalBonds();
    document.getElementById('detail-modal').classList.add('hidden');
    renderDashboard();
    renderWallet();
  });

  document.getElementById('detail-modal-close')?.addEventListener('click', () => {
    document.getElementById('detail-modal').classList.add('hidden');
  });

  // CAMERA SCANNER CONTROLS
  const scannerOverlay = document.getElementById('scanner-screen');
  const videoEl = document.getElementById('camera-video');

  async function openScanner() {
    scannerOverlay.classList.remove('hidden');
    batchCaptured = [];
    updateBatchTray();

    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        mediaStream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment', width: { ideal: 1280 } },
          audio: false
        });
        videoEl.srcObject = mediaStream;
      }
    } catch (e) {
      console.warn('Camera access unavailable (desktop or permission denied), simulation active');
    }
  }

  function closeScanner() {
    if (mediaStream) {
      mediaStream.getTracks().forEach(track => track.stop());
      mediaStream = null;
    }
    videoEl.srcObject = null;
    scannerOverlay.classList.add('hidden');
  }

  document.getElementById('fab-scan-camera').onclick = openScanner;
  document.getElementById('action-scan-bond').onclick = openScanner;
  document.getElementById('wallet-btn-scan').onclick = openScanner;
  document.getElementById('scanner-btn-close').onclick = closeScanner;

  // Single vs Batch toggle
  const modeSingleBtn = document.getElementById('mode-single');
  const modeBatchBtn = document.getElementById('mode-batch');
  const batchTray = document.getElementById('batch-tray-bar');

  modeSingleBtn.onclick = () => {
    activeScanMode = 'single';
    modeSingleBtn.classList.add('active');
    modeBatchBtn.classList.remove('active');
    batchTray.classList.add('hidden');
  };

  modeBatchBtn.onclick = () => {
    activeScanMode = 'batch';
    modeBatchBtn.classList.add('active');
    modeSingleBtn.classList.remove('active');
    batchTray.classList.remove('hidden');
    updateBatchTray();
  };

  // TRIGGER DETECTION (from camera or simulation)
  function triggerDetection(serial, series = 'কখ') {
    document.getElementById('scanner-detected-label').textContent = `Detected: ${series} ${serial}`;

    if (activeScanMode === 'single') {
      openPreviewModal(serial, series);
    } else {
      // Batch mode
      if (!batchCaptured.some(b => b.serial === serial)) {
        batchCaptured.push({
          id: 'batch_' + Date.now() + '_' + Math.floor(Math.random()*1000),
          serial,
          series,
          tags: ['Batch Scan'],
          date: new Date().toISOString().substring(0, 10)
        });
        updateBatchTray();
      }
    }
  }

  function updateBatchTray() {
    const count = batchCaptured.length;
    document.getElementById('batch-counter-text').textContent = `Batch Mode: ${count} Bonds`;
    document.getElementById('batch-invest-text').textContent = count > 0 ? `Investment: ${formatBDT(count * 100)}` : 'Scan bonds sequentially';

    const chipsCont = document.getElementById('batch-chips-container');
    chipsCont.innerHTML = batchCaptured.map(b => `<span class="batch-chip-item">${b.series} ${b.serial}</span>`).join('');

    const saveBtn = document.getElementById('btn-save-batch');
    saveBtn.disabled = count === 0;
    saveBtn.textContent = count > 0 ? `Save ${count} Bonds to Wallet` : 'Scan Bonds to Begin';
  }

  document.getElementById('btn-save-batch').onclick = () => {
    if (batchCaptured.length === 0) return;
    userBonds = [...batchCaptured, ...userBonds];
    saveLocalBonds();
    closeScanner();
    renderDashboard();
    renderWallet();
    alert(`🎉 Added ${batchCaptured.length} bonds to your wallet!`);
  };

  // Demo simulation buttons
  document.getElementById('sim-btn-1st').onclick = () => triggerDetection('0782341', 'কখ');
  document.getElementById('sim-btn-2nd').onclick = () => triggerDetection('0421890', 'গঘ');
  document.getElementById('sim-btn-reg').onclick = () => triggerDetection('0154289', 'ঘঙ');

  // PREVIEW MODAL (Single Mode)
  const previewModal = document.getElementById('preview-modal');
  const modalSerial = document.getElementById('modal-input-serial');
  const modalSeries = document.getElementById('modal-input-series');
  const modalTag = document.getElementById('modal-input-tag');
  const modalBnPreview = document.getElementById('modal-bengali-preview');
  const modalWinnerBadge = document.getElementById('preview-winner-badge');
  const modalWinnerDesc = document.getElementById('preview-winner-desc');

  function openPreviewModal(serial, series) {
    modalSerial.value = serial;
    modalSeries.value = series || '';
    modalTag.value = '';
    updateModalCheck();
    previewModal.classList.remove('hidden');
  }

  function updateModalCheck() {
    const s = modalSerial.value.trim().padStart(7, '0');
    modalBnPreview.textContent = toBengaliDigits(s);

    const matches = checkBond(s);
    if (matches.length > 0) {
      modalWinnerBadge.classList.remove('hidden');
      modalWinnerDesc.textContent = `${matches[0].tierName} (${matches[0].tierNameBn}) - ${formatBDT(matches[0].amount)}`;
    } else {
      modalWinnerBadge.classList.add('hidden');
    }
  }

  modalSerial.oninput = updateModalCheck;
  document.getElementById('preview-modal-close').onclick = () => previewModal.classList.add('hidden');

  document.getElementById('btn-confirm-save').onclick = () => {
    const raw = modalSerial.value.trim();
    if (raw.length < 5 || raw.length > 7) {
      alert('Please enter a valid 7-digit serial number.');
      return;
    }
    const cleanSerial = raw.padStart(7, '0');
    const series = modalSeries.value.trim();
    const tag = modalTag.value.trim();

    userBonds.unshift({
      id: 'bond_' + Date.now(),
      serial: cleanSerial,
      series: series || null,
      tags: tag ? [tag] : ['Scanned'],
      date: new Date().toISOString().substring(0, 10)
    });
    saveLocalBonds();
    previewModal.classList.add('hidden');
    closeScanner();
    renderDashboard();
    renderWallet();
  };

  // SEQUENTIAL RANGE MODAL
  const rangeModal = document.getElementById('range-modal');
  const rangeStart = document.getElementById('range-input-start');
  const rangeEnd = document.getElementById('range-input-end');
  const rangeSeries = document.getElementById('range-input-series');
  const rangeTag = document.getElementById('range-input-tag');
  const rangePreview = document.getElementById('range-calc-preview');
  const btnConfirmRange = document.getElementById('btn-confirm-range');

  function openRangeModal() {
    rangeStart.value = '';
    rangeEnd.value = '';
    rangeSeries.value = '';
    rangeTag.value = '';
    updateRangeCalc();
    rangeModal.classList.remove('hidden');
  }

  function updateRangeCalc() {
    const s = parseInt(rangeStart.value, 10);
    const e = parseInt(rangeEnd.value, 10);

    if (!isNaN(s) && !isNaN(e) && e >= s) {
      const count = e - s + 1;
      if (count > 500) {
        rangePreview.textContent = '❌ Limit exceeded: Maximum 500 bonds per range allowed.';
        btnConfirmRange.disabled = true;
      } else {
        rangePreview.textContent = `✓ Total: ${count} Bonds (${formatBDT(count * 100)})`;
        btnConfirmRange.disabled = false;
        btnConfirmRange.textContent = `Add ${count} Bonds to Wallet`;
      }
    } else {
      rangePreview.textContent = 'Enter start and end 7-digit numbers';
      btnConfirmRange.disabled = true;
      btnConfirmRange.textContent = 'Add Bonds to Wallet';
    }
  }

  rangeStart.oninput = updateRangeCalc;
  rangeEnd.oninput = updateRangeCalc;
  document.getElementById('action-add-range').onclick = openRangeModal;
  document.getElementById('wallet-btn-add-range').onclick = openRangeModal;
  document.getElementById('range-modal-close').onclick = () => rangeModal.classList.add('hidden');

  btnConfirmRange.onclick = () => {
    const s = parseInt(rangeStart.value, 10);
    const e = parseInt(rangeEnd.value, 10);
    const series = rangeSeries.value.trim() || null;
    const tag = rangeTag.value.trim() || 'Sequential Range';

    const count = e - s + 1;
    const batchId = 'range_' + Date.now();

    for (let i = s; i <= e; i++) {
      userBonds.unshift({
        id: 'range_' + i + '_' + Date.now(),
        serial: i.toString().padStart(7, '0'),
        series,
        batchId,
        tags: [tag],
        date: new Date().toISOString().substring(0, 10)
      });
    }

    saveLocalBonds();
    rangeModal.classList.add('hidden');
    renderDashboard();
    renderWallet();
    alert(`🎉 Successfully added ${count} bonds to your wallet!`);
  };

  // DRAWS QUICK NUMBER SEARCH
  document.getElementById('btn-draw-search').onclick = () => {
    const query = document.getElementById('draws-quick-search').value.trim();
    const fb = document.getElementById('draw-search-feedback');

    if (!query) return;

    const matches = checkBond(query);
    fb.classList.remove('hidden');

    if (matches.length > 0) {
      fb.className = 'search-feedback winner';
      fb.textContent = `🎉 WINNER! ${query} won ${matches[0].tierName} (${formatBDT(matches[0].amount)}) in Draw #${matches[0].drawNumber}!`;
    } else {
      fb.className = 'search-feedback';
      fb.textContent = `❌ ${query} was not drawn in any of the active 8 draws (2-year legal window).`;
    }
  };

  // TAB NAVIGATION
  const navItems = document.querySelectorAll('.nav-item');
  const tabPanes = document.querySelectorAll('.tab-pane');

  function switchTab(tabId) {
    tabPanes.forEach(pane => {
      pane.classList.toggle('active', pane.id === tabId);
    });
    navItems.forEach(item => {
      item.classList.toggle('active', item.dataset.tab === tabId);
    });
  }

  navItems.forEach(item => {
    item.addEventListener('click', () => {
      switchTab(item.dataset.tab);
    });
  });

  document.getElementById('action-view-draws').onclick = () => switchTab('tab-draws');
  document.getElementById('latest-draw-banner').onclick = () => switchTab('tab-draws');
  document.getElementById('btn-see-all-bonds').onclick = () => switchTab('tab-wallet');
  document.getElementById('btn-view-winners').onclick = () => {
    activeWalletFilter = 'winners';
    updateWalletFilterUI();
    switchTab('tab-wallet');
  };

  // WALLET FILTER CHIPS
  const filterChips = document.querySelectorAll('#wallet-filter-chips .chip');
  function updateWalletFilterUI() {
    filterChips.forEach(c => c.classList.toggle('active', c.dataset.filter === activeWalletFilter));
    renderWallet();
  }

  filterChips.forEach(c => {
    c.onclick = () => {
      activeWalletFilter = c.dataset.filter;
      updateWalletFilterUI();
    };
  });

  document.getElementById('wallet-search')?.addEventListener('input', renderWallet);
  document.getElementById('btn-refresh')?.addEventListener('click', () => {
    renderDashboard();
    alert('Refreshed verification across all 8 quarterly draws!');
  });

  // START APP
  loadLocalBonds();
  loadDraws();
})();

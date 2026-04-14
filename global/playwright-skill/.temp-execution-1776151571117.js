const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3458';

const VIEWPORTS = [
  { name: 'mobile-sm', width: 375, height: 812 },
  { name: 'mobile-lg', width: 430, height: 932 },
  { name: 'tablet',    width: 768, height: 1024 },
  { name: 'tablet-lg', width: 1024, height: 1366 },
  { name: 'desktop',   width: 1440, height: 900 },
];

(async () => {
  const browser = await chromium.launch({ headless: false, slowMo: 80 });
  const summary = [];

  for (const vp of VIEWPORTS) {
    console.log(`\n=== ${vp.name} (${vp.width}x${vp.height}) ===`);
    const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
    const page = await context.newPage();

    try {
      await page.goto(TARGET_URL, { waitUntil: 'networkidle', timeout: 20000 });
      await page.waitForTimeout(1500);

      const results = await page.evaluate(() => {
        // 1. Horizontal scroll check (document level — actual scrollable)
        const docW = document.documentElement.scrollWidth;
        const vw = window.innerWidth;
        const hscroll = docW > vw;

        // 2. Touch targets (height is the critical dim for vertical thumbs)
        const touchIssues = [];
        document.querySelectorAll('a, button').forEach(el => {
          const r = el.getBoundingClientRect();
          if (r.width > 0 && r.height > 0 && r.height < 44) {
            touchIssues.push(`${el.tagName.toLowerCase()} "${el.textContent.trim().slice(0,25)}" h=${Math.round(r.height)}px`);
          }
        });

        // 3. Nav state
        const hamburger = document.querySelector('button[aria-label="Open menu"]');
        const hamburgerVisible = hamburger ? hamburger.getBoundingClientRect().width > 0 : false;
        const desktopNav = document.querySelector('.hidden.md\\:flex');
        const desktopNavVisible = desktopNav ? window.getComputedStyle(desktopNav).display !== 'none' : false;

        // 4. Hero height
        const main = document.querySelector('main');
        const heroH = main ? Math.round(main.getBoundingClientRect().height) : 'N/A';

        return { hscroll, docW, vw, touchIssues: touchIssues.slice(0, 8), hamburgerVisible, desktopNavVisible, heroH };
      });

      await page.screenshot({ path: `C:/Users/Toma/AppData/Local/Temp/czdev-final-${vp.name}.png`, fullPage: true });

      const status = results.hscroll ? `HSCROLL (${results.docW}px)` : 'No hscroll';
      console.log(`  Scroll: ${status}`);
      console.log(`  Nav: hamburger=${results.hamburgerVisible}, desktop=${results.desktopNavVisible}`);
      console.log(`  Hero height: ${results.heroH}px`);
      if (results.touchIssues.length) {
        console.log(`  Touch issues:`);
        results.touchIssues.forEach(i => console.log(`    ${i}`));
      } else {
        console.log(`  Touch targets OK`);
      }

      summary.push({ name: vp.name, width: vp.width, hscroll: results.hscroll, touchCount: results.touchIssues.length });
    } catch (err) {
      console.error(`  ERROR: ${err.message}`);
    }

    await context.close();
  }

  console.log('\n====== FINAL SCORECARD ======');
  for (const r of summary) {
    const hFlag = r.hscroll ? ' ❌ HSCROLL' : ' ✓';
    const tFlag = r.touchCount > 0 ? ` ❌ ${r.touchCount} touch` : ' ✓';
    console.log(`${r.name.padEnd(12)} (${r.width}px) — scroll${hFlag} — touch${tFlag}`);
  }
  await browser.close();
})();

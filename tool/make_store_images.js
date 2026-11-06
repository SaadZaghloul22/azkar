const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const uri = (d, f) => 'data:' + (f.endsWith('.ttf') ? 'font/ttf' : 'image/png') + ';base64,' + fs.readFileSync(path.join(d, 'src', f)).toString('base64');
const dir = process.argv[2];
const shots = [
  ['01_home.png', 'حصّن يومك بذكر الله', 'أذكار الصباح والمساء ومواقيت الصلاة في مكان واحد'],
  ['02_reader_morning.png', 'أذكار موثّقة بالتشكيل', 'مع مصدر كل ذكر وفضله وعدّاد بلمسة واحدة'],
  ['overlay_10.png', 'ذكر يظهر تلقائيًا', 'نافذة عائمة تذكّرك بالله أثناء استخدام هاتفك'],
  ['05_tasbih.png', 'مسبحة إلكترونية', 'أهداف ٣٣ و١٠٠ و١٠٠٠ مع سجل يومي وأسبوعي'],
  ['06_prayer.png', 'مواقيت الصلاة والقبلة', 'عدّ تنازلي للصلاة القادمة وتنبيه لكل صلاة'],
  ['04_categories.png', '١١ قسمًا من الأذكار', 'الصباح والمساء والنوم والسفر والأدعية القرآنية والنبوية'],
  ['11_reader_dark.png', 'وضع ليلي مريح', 'قراءة هادئة للعين قبل النوم'],
  ['00b_onboarding_reminders.png', 'بدون إعلانات • بدون إنترنت', 'مجاني بالكامل وبياناتك تبقى على جهازك'],
];
const css = (d) => `
@font-face{font-family:Cairo;src:url(${uri(d,'Cairo_700Bold.ttf')});font-weight:700}
@font-face{font-family:Cairo;src:url(${uri(d,'Cairo_800ExtraBold.ttf')});font-weight:800}
@font-face{font-family:Cairo;src:url(${uri(d,'Cairo_600SemiBold.ttf')});font-weight:600}
*{margin:0;box-sizing:border-box}
body{direction:rtl;font-family:Cairo;overflow:hidden}
.bg{position:absolute;inset:0;background:linear-gradient(160deg,#11785A 0%,#0A5139 70%,#073B29 100%)}
.pat{position:absolute;inset:0;opacity:.08;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='90' height='90'%3E%3Cg fill='none' stroke='white' stroke-width='2'%3E%3Crect x='25' y='25' width='40' height='40' transform='rotate(45 45 45)'/%3E%3Crect x='25' y='25' width='40' height='40'/%3E%3C/g%3E%3C/svg%3E")}
`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  for (let i = 0; i < shots.length; i++) {
    const [img, t, s] = shots[i];
    await p.setContent(`<html><head><style>${css(dir)}
      .t{position:absolute;top:110px;left:60px;right:60px;text-align:center;color:#fff;font-size:76px;font-weight:800;line-height:1.3}
      .s{position:absolute;top:235px;left:80px;right:80px;text-align:center;color:#E9D79A;font-size:40px;font-weight:600;line-height:1.5}
      .ph{position:absolute;left:50%;transform:translateX(-50%);top:400px;width:780px;height:1733px;border-radius:64px;background:#111;padding:18px;box-shadow:0 40px 90px rgba(0,0,0,.45)}
      .ph img{width:100%;height:100%;object-fit:cover;object-position:top;border-radius:48px;display:block}
      </style></head><body><div class=bg></div><div class=pat></div>
      <div class=t>${t}</div><div class=s>${s}</div>
      <div class=ph><img src="${uri(dir,img)}"></div></body></html>`);
    await p.waitForTimeout(400);
    await p.screenshot({ path: path.join(dir, `store_${i + 1}.png`) });
  }
  await p.setViewportSize({ width: 1024, height: 500 });
  await p.setContent(`<html><head><style>${css(dir)}
    .logo{position:absolute;right:70px;top:120px;width:150px;height:150px;border-radius:36px;box-shadow:0 14px 40px rgba(0,0,0,.35)}
    .n{position:absolute;right:70px;top:290px;color:#fff;font-size:64px;font-weight:800}
    .tag{position:absolute;right:72px;top:385px;color:#E9D79A;font-size:28px;font-weight:700}
    .ph{position:absolute;left:90px;top:40px;width:250px;height:556px;border-radius:30px;background:#111;padding:8px;box-shadow:0 20px 50px rgba(0,0,0,.45);transform:rotate(-6deg)}
    .ph img{width:100%;height:100%;object-fit:cover;object-position:top;border-radius:24px}
    .ph2{left:330px;top:80px;transform:rotate(5deg)}
    </style></head><body><div class=bg></div><div class=pat></div>
    <img class=logo src="${uri(dir,'logo.png')}">
    <div class=n>أذكار المسلم</div>
    <div class=tag>بدون إعلانات • يعمل بدون إنترنت</div>
    <div class="ph ph2"><img src="${uri(dir,'02_reader_morning.png')}"></div>
    <div class=ph><img src="${uri(dir,'01_home.png')}"></div>
    </body></html>`);
  await p.waitForTimeout(400);
  await p.screenshot({ path: path.join(dir, 'feature_graphic.png') });
  await b.close();
})();

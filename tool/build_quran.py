#!/usr/bin/env python3
"""Builds assets/data/quran.json from the verified sources in tool/sources/.

- tanzil-quran-uthmani.txt: Tanzil Quran Text (Uthmani 1.1), CC BY 3.0, copied verbatim
  (the copyright block is kept at the end of the file and carried into the asset).
- quran-meta-hafs.json: page / juz / rub / sajda / surah boundaries of the 604-page
  Madinah mushaf (quran-meta, MIT), as 1-based ayah ids (1..6236).
Run: python3 tool/build_quran.py
"""
import json, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
src = root / 'tool' / 'sources'
lines = (src / 'tanzil-quran-uthmani.txt').read_text(encoding='utf-8').splitlines()
notice = '\n'.join(l for l in lines if l.startswith('#'))
ayat = []
for l in lines:
    if not l or l.startswith('#'):
        continue
    s, a, text = l.split('|', 2)
    ayat.append((int(s), int(a), text))
meta = json.loads((src / 'quran-meta-hafs.json').read_text(encoding='utf-8'))

# ---- integrity checks: fail the build rather than ship a broken mushaf ----
assert len(ayat) == 6236, len(ayat)
assert 'CHANGING IT IS NOT ALLOWED' in notice
surahs = meta['surahs']
assert len(surahs) == 114
i = 0
for n, s in enumerate(surahs, 1):
    assert s['start'] == i + 1, (n, s['start'], i + 1)
    for k in range(1, s['ayahs'] + 1):
        assert ayat[i][:2] == (n, k), (n, k, ayat[i][:2])
        i += 1
pages, juz, rub = meta['pages'], meta['juz'], meta['rub']
assert len(pages) == 604 and pages[0] == 1 and pages == sorted(set(pages)) and pages[-1] <= 6236
assert len(juz) == 30 and juz[0] == 1 and juz == sorted(juz)
assert len(rub) == 240 and rub[0] == 1 and rub == sorted(rub)
assert len(meta['sajda']) == 15
assert ayat[pages[2] - 1][:2] == (2, 6)        # page 3 starts at al-Baqarah 6
assert ayat[pages[603] - 1][:2] == (112, 1)    # page 604 starts at al-Ikhlas

out = {
    'notice': notice,
    'source': 'Tanzil Project — https://tanzil.net',
    'meta_source': meta['source'],
    'ayat': [t for _, _, t in ayat],
    'pages': pages,
    'juz': juz,
    'rub': rub,
    'sajda': meta['sajda'],
    'surahs': [[s['name'], s['ayahs'], 1 if s['meccan'] else 0] for s in surahs],
}
dst = root / 'assets' / 'data' / 'quran.json'
dst.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
print('ok', dst, dst.stat().st_size, 'bytes')

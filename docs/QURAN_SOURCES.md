# Mushaf sources

| What | Source | Licence |
|---|---|---|
| Quran text (`tool/sources/tanzil-quran-uthmani.txt`) | Tanzil Quran Text, Uthmani v1.1 — https://tanzil.net (copy from TarteelAI/quran-assets) | CC BY 3.0, verbatim, copyright block kept |
| Page / juz / rub / sajda boundaries (`tool/sources/quran-meta-hafs.json`) | quran-meta 7.0.0, Hafs, 604-page Madinah mushaf | MIT |
| Font (`assets/fonts/AmiriQuran-Regular.ttf`) | Amiri Quran 1.003, google/fonts | SIL OFL 1.1 (`assets/fonts/AmiriQuran-OFL.txt`) |

Verification done before bundling:
- All 6,236 verses were compared letter-by-letter (diacritics stripped, hamza/alef forms
  unified) with the independent King Fahd Complex Hafs text (npm `quran-cloud`): 6,236 / 6,236 match,
  verse counts per surah identical.
- `tool/build_quran.py` asserts verse/surah order, 604 pages, 30 juz, 240 rub, 15 sajda,
  page 3 = al-Baqarah 6, page 604 = al-Ikhlas.
- Amiri Quran covers every character used in the text (checked with fontTools).
- `test/quran_test.dart` re-checks page continuity, juz pages and the basmala split.

The app shows the attribution in «عن التطبيق». Rebuild the asset with `python3 tool/build_quran.py`.

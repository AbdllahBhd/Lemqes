# Algeria geo data: provenance

Seeds `geo_countries` / `geo_regions` / `geo_localities` for `DZ` through
`scripts/geo/build_geo_sql.py` → `supabase/migrations/20261115000110_geo_dz_seed.sql`.
Never edit the seed by hand: change `patches.json` (or re-vendor the dataset) and regenerate.

## Dataset

| | |
|---|---|
| Repository | https://github.com/ihahachi/algeria-cities |
| Pinned commit | `de62dc6229504d6066164ecbabe0c2f0224b29bf` (2026-09-15, "fixed id in sql file #10") |
| File | `json/algeria_cities.json` → `algeria_cities.json` (unchanged) |
| sha256 | `7930b4e467a4ca948e6afae7cf7b0fdb3c677acf0fedbee9a407cb925863b255` |
| Retrieved | 2026-11-14 |
| License | MIT, as stated in the repository README ("## 📜 License — MIT License"). The repository has **no LICENSE file** at the pinned commit, so there is no copyright line to reproduce; credit: ihahachi/algeria-cities contributors. |
| Contents | 1,541 rows, 69 wilaya codes, no empty names, `code_commune` unique |

### Field mapping

| Dataset field | Column |
|---|---|
| `wilaya_code` (int) | `geo_regions.code`, zero-padded to 2 (`'01'`..`'69'`); `geo_localities.region_code` |
| `wilaya_name` / `wilaya_name_fr` | `geo_regions.name_ar` / `name_fr` |
| `code_commune` (int) | `geo_localities.id` (as is) and `official_code` (zero-padded to 4, e.g. `'0703'`) |
| `commune_name` / `commune_name_fr` | `geo_localities.name_ar` / `name_fr` |
| `Lat` / `Long` | `geo_localities.lat` / `lng` |
| `id`, `daira_name*` | not used (`id` is a row counter, not an official code) |

### Known gaps

- Coordinates are per commune (1,539 distinct points), but precision varies: a few are rounded to
  whole degrees on one axis (e.g. 510 Guigba `lng 6`, 116 Tinerkouk `lat 29`) and two pairs share
  a point (Belarbi/Makhda, Ouled Bouachra/Si Mahdjoub). Good enough to sort by distance at wilaya
  scale; not for street-level use. M4 can replace coordinates without changing ids.
- `code_commune` follows the pre-split numbering for communes of the 2019 and 2026 wilayas
  (e.g. Bou Saâda is `2820` in wilaya 68; Tinerkouk is `0116` in wilaya 49), mixed with new
  `55xx` / `56xx` / `58xx` codes for some 2019 wilayas. So the first two digits of
  `official_code` are **not** always the region. Codes are unique, which is what the ids need.
- For wilayas 09, 35, 42 and 47 a handful of codes are assigned to different communes than in
  geoalgeria (e.g. Bou Haroun `4220` here vs `4230` there). Neither source is the ONS code list;
  unresolved (see "Open questions").
- Daïras are not imported.

## Cross-check: geoalgeria 2.4.1 (npm, MIT for names/codes; ODbL for some coordinates)

Compared programmatically against `data/csv/communes.csv` and `data/wilayas.json` of
`geoalgeria-2.4.1.tgz` (published 2026-10-30). Nothing was copied from it.

- Totals agree: 69 wilayas, 1,541 communes.
- Before patches, per-wilaya counts differed for 03, 08, 13, 26, 28, 30, 32, 52, 55, 59, 63,
  67, 68, 69. After the patches below, all 69 per-wilaya counts agree and every commune that
  shares a code with geoalgeria sits in the same wilaya.
- 56 communes carry different codes (geoalgeria renumbers the 2019 wilayas 49-58, e.g. Béni
  Abbès `5201` vs `0807` here, plus the 09/35/42/47 differences above). Ids here keep the
  dataset's codes.
- Name differences left as in the dataset (not verified against an official text): 44
  `عين الدفلة` vs `عين الدفلى`, 46 `عين تيموشنت` vs `عين تموشنت`, 53 `Ain Salah` vs `In Salah`,
  54 `Ain Guezzam` vs `In Guezzam`, 55 `تقرت` vs `توقرت`, 57 `El Meghaier` vs `El M'Ghair`,
  58 `El Menia` vs `El Meniaa`, 59 `أفلو` vs `آفلو` (the JO has `أفلو`, so the dataset is right).

## Official verification of wilayas 59-69: `verified: yes`

All three texts were downloaded from joradp.dz on 2026-11-14 (PDF, text extracted with
pdftotext; Arabic presentation forms normalised with NFKC before comparing):

1. **Décret présidentiel n° 26-206 du 25 mai 2026** completing décret n° 84-79 (names and seats
   of the wilayas), **JORA n° 40 du 3 juin 2026** — French edition
   `https://www.joradp.dz/FTP/JO-FRANCAIS/2026/F2026040.pdf` p. 5; Arabic edition
   `https://www.joradp.dz/FTP/jo-arabe/2026/A2026040.pdf` p. 6-7.
2. **Loi n° 26-06 du 4 avril 2026** amending loi n° 84-09 (territorial division), **JORA n° 25
   du 5 avril 2026**, `https://www.joradp.dz/FTP/JO-FRANCAIS/2026/F2026025.pdf` p. 4-9: art. 3
   (69 wilayas, 1,541 communes), the amended articles for the ten mother wilayas and the new
   art. 52 bis 10 to 52 bis 20 listing the communes of each new wilaya.
3. **Loi n° 19-12 du 11 décembre 2019**, **JORA n° 78 du 18 décembre 2019**,
   `https://www.joradp.dz/FTP/JO-FRANCAIS/2019/F2019078.pdf` (wilayas 49-58; used for the
   Touggourt and Tabelbala patches).

| Code | name_fr (JO 40 FR) | name_ar (JO 40 AR) | Parent (Law 26-06) | Communes (Law 26-06) | Dataset before patch |
|---|---|---|---|---|---|
| 59 | Aflou | أفلو | 03 Laghouat | 12 (art. 52 bis 10) | names ok; 9 communes |
| 60 | Barika | بريكة | 05 Batna | 8 (52 bis 11) | ok |
| 61 | El Kantara | القنطرة | 07 Biskra | 5 (52 bis 12) | ok (Branis code typo) |
| 62 | Bir El Ater | بئر العاتر | 12 Tébessa | 4 (52 bis 13) | ok |
| 63 | El Aricha | العريشة | 13 Tlemcen | 4 (52 bis 14) | names ok; 8 communes |
| 64 | Ksar Chellala | قصر الشلالة | 14 Tiaret | 6 (52 bis 15) | ok |
| 65 | Aïn Ouessara | عين وسارة | 17 Djelfa | 10 (52 bis 16) | name_fr `Ain Oussera` |
| 66 | Messaad | مسعد | 17 Djelfa | 8 (52 bis 17) | ok |
| 67 | Ksar El Boukhari | قصر البخاري | 26 Médéa | 21 (52 bis 18) | names ok; 13 communes |
| 68 | Bou Saâda | بوسعادة | 28 M'Sila | 23 (52 bis 19) | name_fr `Boussaâda`; 14 communes |
| 69 | El Abiodh Sidi Cheikh | الأبيض سيدي الشيخ | 32 El Bayadh | 7 (52 bis 20) | names ok; 8 communes |

Parents are not named outright in the texts: each one is the wilaya whose amended article in
Law 26-06 lost those communes (art. 7 Laghouat, 9 Batna, 11 Biskra, 16 Tébessa, 17 Tlemcen,
18 Tiaret, 21 Djelfa, 30 Médéa, 32 M'Sila, 36 El Bayadh), which also matches the communes'
codes. Every one of 59-69 has communes in the dataset.

Commune *names* were not changed to the law's spelling (e.g. dataset `Azil Abedelkader`, law
`Abdelkader Azil`); only membership was. Wilayas 01-58 names were not checked against décret
84-79 and its amendments.

## Patches (`patches.json`)

Each op asserts the value it replaces, so a re-vendored dataset that already fixed (or changed)
a value makes the build fail instead of being overwritten silently.

- **record** `wilaya_code` 30 → 55 for 5501, 5503-5508, 5510-5513: rows already say
  `wilaya_name: Touggourt`; Law 19-12 art. 52 bis 6 lists them in Touggourt.
- **record** `code_commune` 7003 → 703 (Branis): the only `70xx` code, and `0703` is otherwise
  absent from Biskra's sequence; geoalgeria also has 703.
- **region** name_fr 65 `Ain Oussera` → `Aïn Ouessara`, 68 `Boussaâda` → `Bou Saâda` (JO 40).
- **region** `parent_code` for 59-69 (Law 26-06, see table).
- **locality** `region_code`, to the composition in Law 26-06: 310, 311, 312 (03 → 59);
  1317, 1321, 1335, 1342 (63 → 13); 2603, 2604, 2617, 2618, 2622, 2623, 2625, 2631, 2640, 2641,
  2657, 2658 (26 → 67); 2614, 2628, 2633, 2637 (67 → 26); 2827, 2836-2839, 2841, 2842, 2844,
  2846 (28 → 68); 3214, 3219 (32 → 69); 3204, 3205, 3215 (69 → 32).
- **locality** 812 Tabelbala 08 → 52 (Law 19-12 art. 52 bis 3: Béni Abbès has 10 communes).
- **expected**: 69 / 1,541, plus the per-wilaya counts for the 21 wilayas Law 26-06 lists and for
  08 / 52 (Law 19-12). The build fails if any differs.

## Open questions

- **El Borma (3021)**: Law 19-12 art. 52 bis 6 lists it in Touggourt (14 communes, Ouargla 7),
  but both this dataset and geoalgeria keep it in Ouargla (Ouargla 8, Touggourt 13). A later
  text may have moved it back; none was found, so the dataset's placement is kept.
- **Commune codes in 09, 35, 42, 47** differ from geoalgeria for a few communes; check against
  the ONS code list before anything external (e.g. a delivery API) relies on `official_code`.

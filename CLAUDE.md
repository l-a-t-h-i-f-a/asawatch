# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`asawatch` — a Flutter health-tracking app UI ("AsaWatch") for a smartwatch companion: heart rate, blood sugar, blood pressure, sleep, plus a food-detection camera flow. All user-facing text is **Bahasa Indonesia**, and file/class names follow the Indonesian domain vocabulary (`beranda` = home, `riwayat` = history, `analisis` = analysis, `profil` = profile, `tujuan kesehatan` = health goals, `deteksi makanan` = food detection). Keep new strings and names in Indonesian to match.

Dart SDK `^3.12.0`. Third-party runtime dependencies: `shared_preferences` (profile only),
`provider` (meal-session surfaces only — see below), and `drift`/`drift_flutter` (session history).
`drift_dev` + `build_runner` are dev-only, for the generated `basis_data.g.dart`.

**[docs/rancangan-ui-sesi-makan.md](docs/rancangan-ui-sesi-makan.md) is the binding design doc.**
It restructures the app from continuous monitoring to episodic *meal sessions*, and where it
conflicts with this file it wins (see its §12.7). **All seven steps of its "Urutan pengerjaan"
are done**, so read it before changing any session surface — it explains why each screen is
shaped the way it is.

## Commands

```bash
flutter pub get                      # install deps
flutter run                          # run on the connected device/emulator
flutter run -d chrome                # web — see the note below; the database will not open
dart run build_runner build          # regenerate basis_data.g.dart after changing the drift schema
flutter analyze                      # lint (flutter_lints via analysis_options.yaml)
flutter test                         # all tests
flutter test test/widget_test.dart   # single test file
flutter test --plain-name "some test name"   # single test by name
flutter build apk                    # Android release build
```

**Android is the only supported target.** Since sessions moved into SQLite (drift), running on
web additionally requires `sqlite3.wasm` and `drift_worker.js` in [web/](web/) — they are not
committed, so the page loads and then fails when the database opens. Reviving web support means
fetching both from the drift release matching the pinned version.

## Architecture

**This is a UI prototype with no backend, but no longer without storage.** There is no API layer; there *is* a repository layer ([lib/repositories/](lib/repositories/)) over a local SQLite database, and the only state manager is the single `SesiMakanController` described below. Understanding these three points explains most of the codebase:

1. **Meal-session state is live; everything else is still hardcoded.** Sessions flow through
   `SesiMakanController` ([lib/controllers/](lib/controllers/)) fed by `FakeBleService` and
   `FakeNutrisiService` ([lib/services/](lib/services/)), with models in
   [lib/models/sesi_makan.dart](lib/models/sesi_makan.dart) and fake seed data in
   [lib/models/contoh_sesi.dart](lib/models/contoh_sesi.dart). `FakeBleService(percepatan: 360)`
   compresses the 1-hour sample interval to 10 seconds so a full session is observable.
   **t0 comes from the watch, never from the app**: the app arms the watch (`siapkanSesi`)
   once a photo exists, and the session only starts when the watch reports its button press
   over `selesaiMakanDitekan`, carrying the watch's own clock. There is no `tetapkanT0()` —
   every surface that used to offer "Selesai Makan & Pantau" now shows
   [lib/widgets/petunjuk_tombol_jam.dart](lib/widgets/petunjuk_tombol_jam.dart) instead. Since
   nobody can press a real watch during the UI phase, `FakeBleService` presses its own button
   after a simulated 10 minutes (`otomatisSelesaiMakan`); tests disable that and call
   `tekanSelesaiMakan()` explicitly. The
   screens the redesign did not cover remain literal-driven: [tujuan_kesehatan_page.dart](lib/tujuan_kesehatan_page.dart) (its targets, hence the placeholder [lib/models/target_harian.dart](lib/models/target_harian.dart)), the how-to steps in [menghubungkan_perangkat_page.dart](lib/menghubungkan_perangkat_page.dart), and the auth pages.
   **Pairing is a mock flow, not real BLE**: `BleService.pindai()/sambungkan()/putuskan()` drive
   [lib/pemindaian_perangkat_page.dart](lib/pemindaian_perangkat_page.dart), and `FakeBleService`
   answers from a fixed three-device catalogue (two AsaWatch plus one `didukung: false` stranger)
   on timers scaled by `percepatan`, so a scan finishes in test time. `pindai()` deliberately uses
   a `StreamController` rather than `async*` — cancelling a subscription must stop the scan at
   once, and an `async*` generator would leave its next delay timer pending into the test's
   pending-timer check. `StatusPerangkat.namaPerangkat` is what separates "never paired"
   (`belumDipasangkan`, offer a scan) from "paired but out of range" (offer a reconnect, and keep
   the buffered samples' explanation intact). Cross-session maths lives in [lib/models/analisis_sesi.dart](lib/models/analisis_sesi.dart) (`AnalisisSesi`): scatter points, least-squares trend, spike triggers, recovery tally — all computed, never stored. The three metric detail pages render a real `SesiMakan` (defaulting to the controller's latest) plus cross-session content, though their normal-range boxes are still fixed copy. [riwayat_tab.dart](lib/riwayat_tab.dart) no longer does — it lists `SesiMakan` entries from the controller, grouped by date, filtered by meal time (`waktuMakan`) or response quality (`kualitasRespons`), each opening `RingkasanSesiPage`.
2. **Auth is fake.** [login_page.dart](lib/login_page.dart) and [register_page.dart](lib/register_page.dart) only run `_formKey.currentState!.validate()` and then navigate; no credentials are checked or stored. Logout is `pushNamedAndRemoveUntil('/welcome', ...)`.
3. **Finished sessions are persisted; the active session and calibration are not.** History lives in SQLite via drift — `SesiRepository` ([lib/repositories/sesi_repository.dart](lib/repositories/sesi_repository.dart)) is the seam, `SesiRepositoryDrift` + the schema in [lib/repositories/basis_data.dart](lib/repositories/basis_data.dart) are the real implementation, and `SesiRepositoryMemori` remains as the in-memory one for tests (the same role `FakeBleService` plays). Editing the schema means re-running `build_runner`; `basis_data.g.dart` is generated and committed. Three things are load-bearing there: enums are stored via `textEnum` so **renaming a `StatusSesi`/`StatusSampel` member is a schema change**, derived values (verdict, kualitas respons) have no columns and are recomputed on load, and `onUpgrade` walks one version at a time with a `default` branch that throws, so a bumped `schemaVersion` cannot ship without a written migration (`test/anchor_repository_test.dart` actually drives the v1→v2 upgrade). **The controller's constructor stays synchronous on purpose** — `main()` loads history and passes it as `riwayatAwal`, so no session surface needs a loading state. A **running** session still lives only in memory: restoring one would need the watch's own schedule and buffer, which only exists once real BLE lands (Tahap B). A fresh install now starts genuinely empty — the `contohRiwayatSesi()` seed is gone from the production path, so `contoh_sesi.dart` is test-only fixture data. Two failure paths are handled: the database failing to open shows `AplikasiGagalMulai` instead of a blank screen, and a session that fails to save sets `SesiMakanController.galatPenyimpanan`, which Beranda shows as a persistent warning card (not a SnackBar — the consequence outlives a toast). The schema is at **v2**: v2 added `tabel_anchor_waktu`, which stores the watch's time anchors ([lib/repositories/anchor_repository.dart](lib/repositories/anchor_repository.dart), [lib/models/anchor_waktu.dart](lib/models/anchor_waktu.dart)) — nothing writes to it yet, because the watch has no RTC and the anchors only start arriving with real BLE in Tahap B; see [docs/protokol-jam.md](docs/protokol-jam.md) §4. **Profile persistence is still `SharedPreferences`**, but only ever through `ProfilRepository` ([lib/repositories/profil_repository.dart](lib/repositories/profil_repository.dart)) — which keeps the flat `user_*` string keys (`user_name`, `user_dob`, …) so existing installs keep their data. Two of those keys changed *format* rather than name: `user_dob` now holds ISO `yyyy-MM-dd` (picked via `showDatePicker`, rendered through `formatTanggal`), and `user_height`/`user_weight` hold a bare number with the unit moved into the field's `suffixText`. Old-style values are tolerated on read — units are stripped, and an unparseable date reads as unset so the user picks once more. Adding a profile field now means touching `Profil` and `ProfilRepository` and nothing else; the pages ([informasi_pribadi_page.dart](lib/informasi_pribadi_page.dart), [profil_tab.dart](lib/profil_tab.dart), [beranda_tab.dart](lib/beranda_tab.dart)) never see a key. There are no demo defaults any more: an unset field reads as an empty string, `Profil.kosong` is the blank profile, and surfaces decide what to show — Beranda greets "Halo" without a name, ProfilTab invites you to fill it in. Three consequences worth knowing: the gender and blood-type dropdowns hold `String?` because `DropdownButtonFormField` requires its value to exist in `items`, so "unset" has to be null rather than `''`; every field in `InformasiPribadiPage` is now optional and only its *shape* is validated (requiring them all was invisible while demo defaults pre-filled the form, and became a trap the moment they were removed); and the three Unsplash avatars are gone (they showed a stranger, and never loaded in release builds — the app declares no `INTERNET` permission).

**Navigation.** Named routes exist in [main.dart](lib/main.dart) only for the auth shell: `/welcome`, `/login`, `/register`, `/home`. Everything below the shell uses anonymous `MaterialPageRoute` pushes. Cross-page state refresh is done by popping a result: `InformasiPribadiPage` calls `navigator.pop(true)` after saving, and `ProfilTab` re-runs `_loadProfileData()` when it receives `true`. Follow that pattern rather than introducing a state manager — **except** on the meal-session
surfaces (Beranda's session area, Deteksi Makanan, Sesi Berjalan, Ringkasan Sesi), which read a
single `SesiMakanController` through one `ChangeNotifierProvider` above `MaterialApp`, because BLE
samples can arrive at any time from any tab.

**Reaching the metric detail pages.** They are no longer linked from Beranda (the vital dashboard is gone). `AnalisisTab`'s "Telusuri per Metrik" rows and `RingkasanSesiPage`'s three buttons are the only entry points; the latter passes its own `SesiMakan` so the page shows that session rather than the newest one.

**Shell / tab bar.** `MyHomePage` in [main.dart](lib/main.dart) owns a hand-rolled bottom nav (a `Container` + `Row`, not `BottomNavigationBar`) over an `IndexedStack` of five tabs. Index 2 is special: it is a raised circular button whose meaning follows the session status — idle pushes `DeteksiMakananPage`, any active session (draft or running) pushes `SesiBerjalanPage` — and it always **pushes** instead of switching tabs, so `_tabs[2]` is a never-shown placeholder and the `IndexedStack` index is clamped (`_currentIndex == 2 ? 0 : _currentIndex`). Any change to tab count or ordering must keep that index-2 carve-out consistent.

**Charts are all `CustomPainter`** — no charting package — and every data chart is now drawn from data. One generic painter serves them all: `KurvaSampelPainter` in [lib/widgets/kurva_sampel.dart](lib/widgets/kurva_sampel.dart), configured by `SeriMetrik` values (`seriGulaDarah`, `seriDetakJantung`, `seriSistolik`, `seriDiastolik`) that say which metric to pull off each `Sampel`; `MiniSparklinePainter` in [lib/widgets/sparkline.dart](lib/widgets/sparkline.dart) takes a `List<double>`. The old per-page painters (`SplinePainter`, `BloodSugarSplinePainter`, `BloodPressureSplinePainter`, `DashboardSplinePainter`) are gone — do not reintroduce a hardcoded bezier for data. [lib/widgets/](lib/widgets/) holds the shared widgets; the welcome and login pages define further painters inline for background art. Note `PulseLinePainter` is defined twice, independently, in [welcome_page.dart](lib/welcome_page.dart) and [login_page.dart](lib/login_page.dart).

**Layout style.** Pages are `Scaffold` + `SingleChildScrollView`, one file per screen at `lib/` top level, and styling is inline `TextStyle`/`BoxDecoration` literals with raw hex colors. There is no shared theme extension or constants file — the `ThemeData` in `main.dart` sets only the seed color scheme and `fontFamily`.

### Palette

Repeated as literals throughout; reuse these rather than inventing shades:

| Color | Use |
| --- | --- |
| `0xFF0EAD69` | primary green (brand, active nav, buttons) |
| `0xFF7BE5C4` | secondary |
| `0xFF1E3A34` | primary text / headings |
| `0xFF6B807B`, `0xFF7E9A94`, `0xFF9CB1AC` | secondary text |
| `0xFFF4FAF7` | page background |
| `0xFFE2EBE8`, `0xFFE2F6F0`, `0xFFE8F8F5` | card/border tints |
| `0xFF8FA7A1` | inactive nav item |

## Testing

`test/widget_test.dart` drives the real flow (welcome → login → tabs) rather than testing widgets in isolation. Two things are load-bearing for any test you add:

- **Wrap `BerandaTab` in a `Scaffold`.** It has none of its own (in the app it lives inside `MyHomePage`'s). Pumped bare, its text loses the theme's `fontFamily` — `DefaultTextStyle` outside a `Material` does not carry it — and the layout reports spurious overflows even with the fonts loaded.
- **Clean up running sessions inside the test body.** `flutter_test` asserts on pending timers before `addTearDown` runs, so a test that leaves a session running must call `hentikanSesi(tester, c)` (in [test/helpers.dart](test/helpers.dart)) before it ends.
- **Session screens need the provider.** `pumpHalaman`/`buatControllerUji` in [test/helpers.dart](test/helpers.dart) supply a `SesiMakanController` backed by an accelerated `FakeBleService`; `percepatan: 3600` turns each hour of session schedule into one second of test time. A test session only starts once `tekanTombolJam(tester, c)` fires the watch's button — `buatControllerUji` turns the fake watch's self-press off so timing stays deterministic.
- **Load the fonts first.** `loadMontserrat()` in `setUpAll` registers the bundled faces via `FontLoader`. Without it the harness substitutes its own fixed-width fallback, whose glyphs are much wider than Montserrat's, and the layouts report spurious `RenderFlex` overflows.
- **Use a phone-sized surface.** `pumpApp()` sets a 412x915 viewport; the default 800x600 test window does not match what these layouts assume. Note the bottom nav genuinely overflows below ~370 logical px — that is a real constraint, not a test artifact.

Also: `SharedPreferences.setMockInitialValues(...)` must be called before pumping, and pages roll their own `IconButton` back buttons rather than Material `BackButton`, so `tester.pageBack()` does not work — tap `Icons.arrow_back` instead.

## Gotchas

- **`BerandaTab.build()` calls the async `_loadNama()` on every build.** The equality check inside `_loadNama` is what stops that from becoming an infinite rebuild loop, since `setState` would otherwise schedule the next build, which reloads, and so on. Do not remove it, and do not copy this pattern into other tabs.
- **`ListTile` must not sit inside an opaque `Container`** — it paints ink splashes on the nearest `Material` ancestor, and a `DecoratedBox` in between both hides them and trips a debug assertion. `ProfilTab._buildProfileMenu` shows the working shape: `Material` for the fill, `ListTile.shape` for the border.
- `IndexedStack` builds all five tabs eagerly, so every tab's `initState` runs as soon as the shell mounts — including `ProfilTab`'s loading spinner and its `SharedPreferences` read.

## Assets

Montserrat (weights 400/500/600/700) is bundled under `assets/fonts/` and declared in `pubspec.yaml`; `main()` registers `assets/fonts/OFL.txt` with `LicenseRegistry` to satisfy the SIL Open Font License. Adding a new weight means adding the `.ttf`, the `pubspec.yaml` entry, and the path in the test's `loadMontserrat()`.

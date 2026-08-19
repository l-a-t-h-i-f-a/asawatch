# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`asawatch` — a Flutter health-tracking app UI ("AsaWatch") for a smartwatch companion: heart rate, blood sugar, blood pressure, sleep, plus a food-detection camera flow. All user-facing text is **Bahasa Indonesia**, and file/class names follow the Indonesian domain vocabulary (`beranda` = home, `riwayat` = history, `analisis` = analysis, `profil` = profile, `tujuan kesehatan` = health goals, `deteksi makanan` = food detection). Keep new strings and names in Indonesian to match.

Dart SDK `^3.12.0`. Third-party runtime dependencies: `shared_preferences` (profile + paired-watch
id), `provider` (meal-session surfaces only — see below), `drift`/`drift_flutter` (all local
storage), `flutter_blue_plus` (the watch), `permission_handler` (Bluetooth permissions), and
`flutter_local_notifications` + `timezone` (measurement-point reminders — see
[docs/jadwal-titik-ukur.md](docs/jadwal-titik-ukur.md) §6; since the watch stopped scheduling its own
points, nothing but the app reminds the user).
`drift_dev` + `build_runner` are dev-only, for the generated `basis_data.g.dart`.

**Both BLE-adjacent dependencies are pinned below their latest, for unrelated reasons.**
`flutter_blue_plus` sits at `^1.35.5` because 2.x moved to a licence requiring paid commercial use
and this is a product meant to be sold — upgrading means buying that licence (and passing `license:`
to `connect()`), not just bumping the constraint. `permission_handler` sits at `^12.0.1` because 13.x
pulls `permission_handler_android` 14, which demands `compileSdk 37` while this project's AGP tops
out at 36; the API `IzinBle` uses is identical in both.

**[docs/rancangan-ui-sesi-makan.md](docs/rancangan-ui-sesi-makan.md) is the binding design doc.**
It restructures the app from continuous monitoring to episodic *meal sessions*, and where it
conflicts with this file it wins (see its §12.7). **All seven steps of its "Urutan pengerjaan"
are done**, so read it before changing any session surface — it explains why each screen is
shaped the way it is.

## Commands

```bash
flutter pub get                      # install deps
flutter run                          # run on the connected device/emulator (real watch over BLE)
flutter run --dart-define=PAKAI_JAM_PALSU=true   # …with FakeBleService instead, no hardware needed
flutter run --dart-define=PAKAI_JADWAL_UJI=true   # …with the two-minute session schedule (real watch works too)
flutter run --dart-define=PAKAI_AUTH_PALSU=true  # …with FakeAuthService — the only way in until a backend exists
                                                 # demo account: test@email.com / rahasia123
flutter run --dart-define=BASIS_URL_API=http://10.0.2.2:8080   # point AuthHttpService at a local server
flutter run -d chrome                # web — see the note below; the database will not open
dart run build_runner build          # regenerate basis_data.g.dart after changing the drift schema
flutter analyze                      # lint (flutter_lints via analysis_options.yaml)
flutter test                         # all tests
flutter test test/widget_test.dart   # single test file
flutter test --plain-name "some test name"   # single test by name
flutter build apk                    # Android release build
```

**Android is the only supported target** (`minSdk` follows Flutter's default, currently 24 — above
the 23 where runtime permissions, which the whole pairing flow depends on, begin. Do not hardcode it
in `build.gradle.kts`: `flutter build` runs a migration that rewrites that line back to
`flutter.minSdkVersion` on every build). The iOS side is declared but unbuilt: `Info.plist` carries the
Bluetooth usage strings and `bluetooth-central` background mode, and `IzinBle` branches on platform,
but nobody has run it. Web is further gone: since sessions moved into SQLite (drift), it also
requires `sqlite3.wasm` and `drift_worker.js` in [web/](web/) — they are not committed, so the page
loads and then fails when the database opens.

## Architecture

**There is no backend, but there is real hardware and real storage.** There is no API layer; there *is* a repository layer ([lib/repositories/](lib/repositories/)) over a local SQLite database, a real BLE layer ([lib/services/ble_asli_service.dart](lib/services/ble_asli_service.dart)), and the only state manager is the single `SesiMakanController` described below. Understanding these three points explains most of the codebase:

1. **Meal sessions are driven by the watch; a few screens are still hardcoded.** Sessions flow through
   `SesiMakanController` ([lib/controllers/](lib/controllers/)) fed by a `BleService` and
   `FakeNutrisiService` ([lib/services/](lib/services/)), with models in
   [lib/models/sesi_makan.dart](lib/models/sesi_makan.dart) and fake seed data in
   [lib/models/contoh_sesi.dart](lib/models/contoh_sesi.dart) (test-only).
   **The production `BleService` is `BleAsliService`**, over `flutter_blue_plus`;
   `FakeBleService` lives behind `--dart-define=PAKAI_JAM_PALSU=true`
   ([lib/konfigurasi.dart](lib/konfigurasi.dart)) and is never deleted — it is the test backbone and
   the only way to demo without hardware. `FakeBleService(percepatan: 360)` compresses the 1-hour
   sample interval to 10 seconds so a full session is observable.
   **t0 is always the watch's, but the button exists in both places.** The app arms the watch
   (`siapkanSesi`) once a photo exists, and the session only starts when the watch reports a button
   press over `selesaiMakanDitekan`. There is still no `tetapkanT0()` and the app never computes t0
   — but since v1.2 of the protocol the app has its own "Saya Sudah Selesai Makan" button, which
   works by **pressing the watch's button remotely**: `mulaiSesiDariApp()` sends `MULAI_SESI`
   (opcode `0x09`), whose payload is the `sesiId` and *nothing else*. The watch reads its own
   counter, moves ARMED → RUNNING, and emits `TOMBOL_SELESAI_MAKAN` exactly as if the physical
   button had been pressed, so t0 stays on the watch's timeline and remains comparable with every
   sample's `uptime_s` (§5.3). Putting an epoch in that payload would collapse the whole of §4.
   Three consequences. `mulaiSesiDariApp()` **does not touch `_sesiAktif`** — a watch that takes the
   command and then goes silent leaves the session in `draft`, which is the honest outcome and is
   what `sesi_pages_test.dart` pins. The command is **idempotent** on the firmware side, because a
   lost ACK makes the app retry and two t0s for one session cannot be repaired afterwards. And the
   physical button is still named first in the copy and must not be removed: it is the only one that
   works when the phone is not in hand, which is the common case while eating.
   Both routes converge on
   [lib/widgets/petunjuk_tombol_jam.dart](lib/widgets/petunjuk_tombol_jam.dart), which is the single
   place the button lives — it is rendered on all three surfaces that used to offer "Selesai Makan &
   Pantau" (Beranda's session card, Deteksi Makanan, Sesi Berjalan), so the button, its disabled
   state, and its error copy exist once. `FakeBleService`
   presses its own button after a simulated 10 minutes (`otomatisSelesaiMakan`); tests disable that and call
   `tekanSelesaiMakan()` explicitly, and its `mulaiSesi()` routes through that same method so the
   fake models the remote press rather than shortcutting it. The
   screens the redesign did not cover remain literal-driven: [tujuan_kesehatan_page.dart](lib/tujuan_kesehatan_page.dart) (its targets, hence the placeholder [lib/models/target_harian.dart](lib/models/target_harian.dart)), the how-to steps in [menghubungkan_perangkat_page.dart](lib/menghubungkan_perangkat_page.dart), and the auth pages.
   **Pairing is real BLE now**: `BleService.pindai()/sambungkan()/putuskan()` drive
   [lib/pemindaian_perangkat_page.dart](lib/pemindaian_perangkat_page.dart), which asks for
   permissions first ([lib/services/izin_ble.dart](lib/services/izin_ble.dart)) — three distinct dead
   ends (denied once, permanently denied, Bluetooth off), each with its own copy, because a scan
   without permission does not fail loudly, it just finds nothing.
   **[docs/alur-pemasangan-jam.md](docs/alur-pemasangan-jam.md) is binding for that flow**, and its
   premise is that the user is elderly. Three things it fixes are load-bearing. **Bonding is
   explicit**: `createBond()` runs after `connect()` and *before* `discoverServices()`, because
   Android otherwise triggers it implicitly inside an operation with a tight timeout — the app then
   gives up while the system dialog is still waiting, which is why the first attempt used to "fail"
   and the second always worked. **`sambungkan()` returns `HasilSambung`, not `bool`**, since the
   follow-up differs per cause, and `TahapSambung` is streamed so the UI can tell the one moment that
   waits for a human (`menyandingkan`, which takes over the whole page and has **no app-side
   timeout**) from the two that merely wait for the radio. `HasilSambung.bondBasi` is the only
   failure that never recovers by retrying, so it alone offers `lupakanPenyandingan()` — as the
   *secondary* action, because the app can only guess at a stale key and a wrong guess would destroy
   a healthy pairing. `FakeBleService.penyandingan` models all five behaviours, including the dialog
   that is never answered and the stale key; without it none of that copy is reachable before
   hardware exists. **Unpairing has two routes and they are not the same state.** From inside the
   app, `lupakanPerangkat()` disconnects, removes the bond, and clears `PerangkatRepository` — always
   behind a confirmation, because the samples still sitting in the watch's buffer will never arrive
   once nothing reconnects to it. From system Bluetooth settings, the app finds out by checking
   `bondState` at the top of the reconnect loop: **pairing is never initiated from the background**,
   so the loop stops and raises `StatusPerangkat.penyandinganHilang` instead of popping a system
   pairing dialog at an arbitrary moment. That flag earns its own copy ("Jam Tidak Tersandingkan" /
   "Sandingkan Ulang") because, unlike a plain disconnect, it never resolves on its own. **The scan is filtered to the
   AsaWatch service UUID at the OS level** (`startScan(withServices: …)`), so non-AsaWatch devices
   never reach the app at all — `FakeBleService` mirrors that by filtering its own catalogue, which
   still contains a stranger device so the filter is visibly filtering something. That filtering
   costs the cheap proof that scanning works, so the page says in words that only AsaWatch is being
   looked for; do not remove that copy. It also puts a hard requirement on firmware: the service UUID
   must sit in the advertisement packet, not the scan response, or the watch is invisible (see
   [docs/protokol-jam.md](docs/protokol-jam.md) §2.2, which has the 31-byte budget). `pindai()` deliberately uses
   a `StreamController` rather than `async*` in **both** implementations — cancelling a subscription must stop the scan at
   once, and an `async*` generator would leave its next delay timer pending into the test's
   pending-timer check. `StatusPerangkat.namaPerangkat` is what separates "never paired"
   (`belumDipasangkan`, offer a scan) from "paired but out of range" (offer a reconnect, and keep
   the buffered samples' explanation intact) — which is why the paired device is persisted
   ([lib/repositories/perangkat_repository.dart](lib/repositories/perangkat_repository.dart)). Cross-session maths lives in [lib/models/analisis_sesi.dart](lib/models/analisis_sesi.dart) (`AnalisisSesi`): scatter points, least-squares trend, spike triggers, recovery tally — all computed, never stored. The three metric detail pages render a real `SesiMakan` (defaulting to the controller's latest) plus cross-session content, though their normal-range boxes are still fixed copy. [riwayat_tab.dart](lib/riwayat_tab.dart) no longer does — it lists `SesiMakan` entries from the controller, grouped by date, filtered by meal time (`waktuMakan`) or response quality (`kualitasRespons`), each opening `RingkasanSesiPage`.
2. **Login goes through a real service seam; there is still no backend, and nothing is stored yet.**
   [lib/services/auth_service.dart](lib/services/auth_service.dart) is the contract —
   `AuthHttpService` ([lib/services/auth_http_service.dart](lib/services/auth_http_service.dart)) over
   `package:http` is the production one, `FakeAuthService` is the test backbone and, until a server
   exists, the only way into the app (`--dart-define=PAKAI_AUTH_PALSU=true`, assembled by
   `buatAuthBawaan()` in [lib/konfigurasi.dart](lib/konfigurasi.dart) alongside `izinBleBawaan`).
   Four things are load-bearing. **`masuk()` returns a sealed `HasilMasuk`, not a `bool`** — the same
   lesson as `HasilSambung`: `KredensialSalah`, `TidakAdaJaringan`, `ServerBermasalah`, and
   `WaktuHabis` each demand something different, the copy lives on `PesanHasilMasuk.pesan`, and
   `bisaDiulang` is why only `KredensialSalah` gets no "Coba Lagi" button. **`AuthHttpService` takes
   its `http.Client` through the constructor** rather than calling `http.post()`, which is the only
   reason it can be tested at all: `MockClient` replaces the socket while the real URL building,
   headers, JSON parsing, and status mapping still run
   ([test/auth_http_service_test.dart](test/auth_http_service_test.dart)). **A non-200 that is not
   401/403 is `ServerBermasalah`, never `KredensialSalah`** — telling a user to check a password
   because the server is broken sends them down a dead end. And **`SesiLogin` is returned but not
   persisted anywhere**: token storage (`flutter_secure_storage`, not `SharedPreferences` — a token
   opens health data and preferences are plain XML on Android), the session gate in `main()`
   replacing the hardcoded `initialRoute: '/welcome'`, refresh, and logout clearing the token are all
   still to be written. `RegisterPage` is untouched and still navigates on `validate()` alone.
   **The release manifest has no `INTERNET` permission** (only `android/app/src/debug/` does, added
   by Flutter for hot reload), and Android blocks cleartext HTTP by default, so a plain-`http://`
   dev server also needs a debug-only `network_security_config` — both bite in release builds while
   debug looks fine.
3. **Everything about a session is persisted, including while it is running.** History lives in SQLite via drift — `SesiRepository` ([lib/repositories/sesi_repository.dart](lib/repositories/sesi_repository.dart)) is the seam, `SesiRepositoryDrift` + the schema in [lib/repositories/basis_data.dart](lib/repositories/basis_data.dart) are the real implementation, and `SesiRepositoryMemori` remains as the in-memory one for tests (the same role `FakeBleService` plays). Editing the schema means re-running `build_runner`; `basis_data.g.dart` is generated and committed. Three things are load-bearing there: enums are stored via `textEnum` so **renaming a `StatusSesi`/`StatusSampel` member is a schema change**, derived values (verdict, kualitas respons) have no columns and are recomputed on load, and `onUpgrade` walks one version at a time with a `default` branch that throws, so a bumped `schemaVersion` cannot ship without a written migration (`test/anchor_repository_test.dart` actually drives v1→v4, v2→v4, and v3→v4). **The controller's constructor stays synchronous on purpose** — `main()` loads history and passes it as `riwayatAwal`, so no session surface needs a loading state. The constructor also **splits the active session out of `riwayatAwal`**: a session that was still running when the app closed comes back as `sesiAktif`, with its schedule recomputed from absolute `t0` (never from remaining time), and its `(sesiId, index)` dedup keys restored. Cancelling deletes the row (`SesiRepository.hapus`) — a draft that was abandoned must not come back as an active session. A fresh install starts genuinely empty — `contoh_sesi.dart` is test-only fixture data. Two failure paths are handled: the database failing to open shows `AplikasiGagalMulai` instead of a blank screen, and a session that fails to save sets `SesiMakanController.galatPenyimpanan`, which Beranda shows as a persistent warning card (not a SnackBar — the consequence outlives a toast). The schema is at **v4**: v2 added `tabel_anchor_waktu` ([lib/repositories/anchor_repository.dart](lib/repositories/anchor_repository.dart), [lib/models/anchor_waktu.dart](lib/models/anchor_waktu.dart)); v3 added `tabel_kalibrasi`, `tabel_entri_jam`, and `tabel_sesi.waktu_tidak_pasti` — all three explained in the BLE section below; v4 reshaped calibration into three rounds (`tabel_putaran_kalibrasi` + `tabel_kalibrasi.sisi`, see the calibration section). That v3→v4 step is the one to read before writing another migration: it has to ask SQLite (`PRAGMA table_info`) whether the old columns are actually there, because `m.createTable()` in an *earlier* step creates today's shape, not that version's — a device coming from v2 arrives at the v4 step with a table that is already v4-shaped and empty. **Profile persistence is still `SharedPreferences`**, but only ever through `ProfilRepository` ([lib/repositories/profil_repository.dart](lib/repositories/profil_repository.dart)) — which keeps the flat `user_*` string keys (`user_name`, `user_dob`, …) so existing installs keep their data. Two of those keys changed *format* rather than name: `user_dob` now holds ISO `yyyy-MM-dd` (picked via `showDatePicker`, rendered through `formatTanggal`), and `user_height`/`user_weight` hold a bare number with the unit moved into the field's `suffixText`. Old-style values are tolerated on read — units are stripped, and an unparseable date reads as unset so the user picks once more. Adding a profile field now means touching `Profil` and `ProfilRepository` and nothing else; the pages ([informasi_pribadi_page.dart](lib/informasi_pribadi_page.dart), [profil_tab.dart](lib/profil_tab.dart), [beranda_tab.dart](lib/beranda_tab.dart)) never see a key. There are no demo defaults any more: an unset field reads as an empty string, `Profil.kosong` is the blank profile, and surfaces decide what to show — Beranda greets "Halo" without a name, ProfilTab invites you to fill it in. Three consequences worth knowing: the gender and blood-type dropdowns hold `String?` because `DropdownButtonFormField` requires its value to exist in `items`, so "unset" has to be null rather than `''`; every field in `InformasiPribadiPage` is now optional and only its *shape* is validated (requiring them all was invisible while demo defaults pre-filled the form, and became a trap the moment they were removed); and the three Unsplash avatars are gone (they showed a stranger, and never loaded in release builds — the app declares no `INTERNET` permission).

### The watch (Tahap B)

**[docs/protokol-jam.md](docs/protokol-jam.md) is normative.** If the code and that document
disagree, one of them is a bug.

**Read its §12 v1.3 entry before touching anything below.** The watch cannot stay powered for more
than ~50 minutes while a session runs over two hours, so **v1.3 moves the schedule out of the
firmware and into the app**: `UKUR` is served in all three states, a new `ARM_TITIK` (`0x0A`) lights
the watch's measure button for one point at a time, `t0` becomes an app-side `DateTime`, and the
discard-on-mismatched-`boot_id` rule is gone. v1.3 is **designed, not implemented** — the five points
below still describe the shipped v1.2 code, and the deltas are listed in §12. The app-side half —
the four-point schedule as data rather than literals, the per-point tolerance windows, the
early-vs-late rule, and the `PAKAI_JADWAL_UJI` compressed-schedule test mode — lives in
[docs/jadwal-titik-ukur.md](docs/jadwal-titik-ukur.md), which is normative for the app and has none
of it on the wire. **All eight of its app-side steps are done** (its §8 has the table, plus three
things found while building that are not in any plan); the firmware side is untouched.

Five things carry most of the weight:

- **The watch has no RTC.** It never sends a wall clock — only `uptime_s` and `boot_id`. The app
  holds all knowledge of real time as *anchors* (`ANCHOR_WAKTU` is written on **every** connection,
  before any other command). The conversion formula is in `AnchorWaktu.keWaktu`, and it works for
  entries that happened *before* the anchor was placed — the difference is simply negative. That is
  the case that matters: a watch used all day with the phone left at home.
- **`detikRelatifT0` is a difference of two counters, never of two calendar times.** A wrong anchor
  shifts a session in the calendar but leaves the curve's shape exact — and the shape is the whole
  summary page. `BleAsliService` keeps `(bootId, uptimeS)` of each session's t0, reloaded at startup
  from the inbox (`EntriJamRepository.t0PerSesi`) so this survives a restart.
- **Ack only after the row is committed** (protocol §6): the watch deletes an entry the moment it is
  acked, so `simpan → ack → emit` is the order, and a failed write means *no ack*.
  `tabel_entri_jam` ([lib/repositories/entri_jam_repository.dart](lib/repositories/entri_jam_repository.dart))
  is that store; rows are marked processed inside the same transaction that writes their session, and
  whatever is still unprocessed at startup is replayed onto the same streams. Its `jenis` and
  `kodePeristiwa` columns are **protocol numbers, not `textEnum`** — renaming a Dart enum must not
  change what is in the database.
- **Time can be unknowable.** A boot that never once connected has no anchor and never will
  (§4.3), so `SesiMakan.waktuTidakPasti` marks the session: it is excluded from `sesiHariIni()`,
  its `waktuMakan` is **null** (use `labelWaktuMakan` in UI), and `AnalisisSesi` drops it. It is
  still shown, with an explanation — the measurements are real, only the clock is not. The flag is a
  stored column because once the session ends there is nothing left to derive it from.
- **Sessions now have a deadline.** `SesiMakanController.tenggatSampelTerakhir` (30 min past the
  +2 h point) closes a session as `tidakLengkap`. Before Tahap B the only route there was the user
  pressing "akhiri lebih awal"; with a real watch, a dead battery or a failed sensor would otherwise
  leave a session waiting forever. Disconnecting does **not** end a session — samples wait in the
  watch's buffer, and [sesi_berjalan_page.dart](lib/sesi_berjalan_page.dart) says so in words.
- **`SesiBerjalanPage` has two exits, and the difference is what happens to the data.**
  "Selesaikan Sesi" calls `akhiriLebihAwal()` — arrived samples are kept, the rest are marked
  `terlewat`, and the session is stored as `tidakLengkap` (so it shows in Riwayat and counts in
  `AnalisisSesi`, which admits anything `!sedangAktif && !waktuTidakPasti`). "Batalkan Sesi" calls
  `batalkan()`, which deletes the row. The first exists because the deadline above can be up to
  2.5 h away from t0: a watch that dies mid-session used to leave only "throw the data away" or
  "wait". It is **offered only once `t0` exists** — a session whose watch button was never pressed
  has not started rather than not finished — and it is always confirmed, because
  `akhiriLebihAwal()` sends `batalkanSesi()` to the watch, so anything still in the watch's buffer
  will never join this session. The dialog names how many samples arrived, since that number is the
  one thing that decides whether ending is right and it cannot be read off the button.
  Ending does not pop the page: `sesiAktif` goes null and the body becomes `_SesiSudahBerakhir`,
  which is the door to the summary.

**`UKUR_SEKARANG` has two callers and neither belongs to a session.** Besides the calibration flow,
[lib/pindai_kesehatan_page.dart](lib/pindai_kesehatan_page.dart) lets the user scan on demand,
outside any meal — same opcode, same bytes, so the feature added no wire change (it did bump the doc
to v1.2, since firmware must now serve it in all three states without touching the session
schedule). Three things are load-bearing. `BleAsliService.ukurSekarang()` waits for a sample whose
`sesiId` is **the zero UUID**, not merely the next sample on the stream — the command can be sent
while a session runs and while the watch's buffer is draining, so the next sample may belong to an
entirely different session. `SesiMakanController.pindaiKesehatan()` guards connectivity itself (the
copy differs for never-paired vs. out-of-range) and allows only one scan at a time, since two
waiters would steal each other's reply. And the result is held **in memory only**
(`pindaiTerakhir`), never written to the session tables: a lone reading with no food, no t0, and no
three comparison points is not a session, and storing it there would pollute every `AnalisisSesi`
figure — the page says so on screen rather than letting the user hunt for it in Riwayat tomorrow.
`FakeBleService` models the failure paths (`galatUkurSekarang`, `metrikGagal`) because a real watch
cannot be ordered to fail, and `permintaanUkur` records every `UKUR` because an arriving sample looks
identical whether the app asked for it or the watch scheduled it.

**Blood-pressure calibration follows the repeated-cuff method** used by comparable products
(Samsung Health Monitor), and [lib/kalibrasi_tekanan_darah_page.dart](lib/kalibrasi_tekanan_darah_page.dart)
is a staged procedure — preparation → three rounds → summary — not a form, because the procedure
*is* the method. **The cuff goes on the arm opposite the watch, and both measure at the same time**:
a cuff inflating on the same arm cuts off the blood flow to the wrist below it, so the watch would be
blind during exactly the seconds being measured, and two readings taken minutes apart compare two
different states. Simultaneity has a consequence the page has to carry: the cuff numbers can only be
typed *after* the watch has finished, so **the watch reading stays hidden until they are entered** —
seeing it first makes people "correct" what they type. What used to be protected by locking the
order is now protected by a curtain. Four further rules live on `Kalibrasi` in
[lib/models/sesi_makan.dart](lib/models/sesi_makan.dart), not in the page: **three rounds and the
correction is the median** (one loose cuff reading would otherwise become a permanent offset, and a
mean would be dragged by it); **a 60-second enforced pause between rounds** (`jedaAntarPutaran` — a
cuff re-inflated immediately reads high); **rounds that disagree by more than `sebaranMaksimum` are
refused**, offering only "Ulangi Kalibrasi", since a median of contradictory numbers means nothing;
and **calibration expires after `masaBerlaku` (4 weeks)** and is bound to one wrist (`sisi`). The
watch knows none of this — it still receives only the two offsets (`SET_KALIBRASI`, protocol §5.1),
and it has no clock, so **expiry is the app's judgement, not a change in the watch's behaviour**: an
expired calibration is still being applied, which is exactly why the UI says so instead of going
quiet. `galatReferensiTensimeter()` guards the typed cuff numbers before the watch is ever asked to
measure — a swapped systolic/diastolic pair would otherwise be wrong for four weeks.

Session ids are **UUID v4** (`buatIdSesi()`), because the protocol carries `sesiId` as 16 binary
bytes. Pre-Tahap-B ids (`sesi-<microseconds>`) still load from the database but are never sent to the
watch — `idSesiValid()` is the guard.

[lib/services/protokol_jam.dart](lib/services/protokol_jam.dart) is pure byte ↔ Dart with no I/O,
which is exactly why it exists separately: it is the only part of the BLE work that can be tested
exhaustively without hardware, and [test/protokol_jam_test.dart](test/protokol_jam_test.dart) reads
every offset in the packet tables rather than merely asserting "did not throw".

**Navigation.** Named routes exist in [main.dart](lib/main.dart) only for the auth shell: `/welcome`, `/login`, `/register`, `/home`. Everything below the shell uses anonymous `MaterialPageRoute` pushes. Cross-page state refresh is done by popping a result: `InformasiPribadiPage` calls `navigator.pop(true)` after saving, and `ProfilTab` re-runs `_loadProfileData()` when it receives `true`. Follow that pattern rather than introducing a state manager — **except** on the meal-session
surfaces (Beranda's session area, Deteksi Makanan, Sesi Berjalan, Ringkasan Sesi), which read a
single `SesiMakanController` through one `ChangeNotifierProvider` above `MaterialApp`, because BLE
samples can arrive at any time from any tab.

**All four metrics are measured at every sample point, and the watch says which ones it has.** Every
`Sampel` carries blood glucose, heart rate, systolic/diastolic, and SpO₂ — they arrive in one packet
(protokol §5.2), so nothing extra is requested for the last three, and all four are persisted per
point. They are shown during a running session (the timeline's secondary line), per point in
`RingkasanSesiPage`, and in `PindaiKesehatanPage`; SpO₂ additionally gets its own curve section on
the summary. **`KemampuanPerangkat` (protokol §3, handshake byte 11) decides what appears at all** —
`StatusPerangkat.kemampuan`, filled from the handshake and re-read after the watch reboots. A metric
the watch lacks is *removed*, never rendered as `—`, because `—` means "measured and failed" and
sends people tightening a strap for a sensor that was never fitted. Two rules ride along and both
matter: `kemampuan` is **null until the first handshake and that means "show everything"** (hiding
values already in the database because the app hasn't asked yet is a certain loss for an uncertain
gain), and **a value that exists is never hidden** even when the bit is 0, since an older session may
have been recorded by a different watch. `kemampuan` is also **retained across disconnect**, unlike
`baterai` — a watch does not grow an SpO₂ sensor while out of range. Heart rate has no bit in §3 and
is always assumed present; do not invent one. `FakeBleService(kemampuan: …)` models a watch missing a
sensor, which is distinct from `metrikGagal` (sensor present, reading failed).

**Reaching the metric detail pages.** They are no longer linked from Beranda (the vital dashboard is gone). `AnalisisTab`'s "Telusuri per Metrik" rows and `RingkasanSesiPage`'s three buttons are the only entry points, and both hide the door for a metric the watch lacks — a page that is all `—` is a dead end you have to walk down before finding out; the latter passes its own `SesiMakan` so the page shows that session rather than the newest one.

**Shell / tab bar.** `MyHomePage` in [main.dart](lib/main.dart) owns a hand-rolled bottom nav (a `Container` + `Row`, not `BottomNavigationBar`) over an `IndexedStack` of five tabs. Index 2 is special: it is a raised circular button whose meaning follows the session status — idle pushes `DeteksiMakananPage`, any active session (draft or running) pushes `SesiBerjalanPage` — and it always **pushes** instead of switching tabs, so `_tabs[2]` is a never-shown placeholder and the `IndexedStack` index is clamped (`_currentIndex == 2 ? 0 : _currentIndex`). Any change to tab count or ordering must keep that index-2 carve-out consistent.

**Charts are all `CustomPainter`** — no charting package — and every data chart is now drawn from data. One generic painter serves them all: `KurvaSampelPainter` in [lib/widgets/kurva_sampel.dart](lib/widgets/kurva_sampel.dart), configured by `SeriMetrik` values (`seriGulaDarah`, `seriDetakJantung`, `seriSistolik`, `seriDiastolik`, `seriSpo2`) that say which metric to pull off each `Sampel`; the y-axis is scaled from the data, so each series carries its own `rentangMinimum` floor — 20 for most, **8 for SpO₂**, because healthy SpO₂ moves between 95 and 100 and the wider floor flattens the only thing worth looking at; **every `TextStyle` inside a painter must set `fontFamily: fontPainter`** — `TextPainter` inherits nothing from the widget tree, so a style without it silently falls back to the platform font (Roboto) while the rest of the app is Montserrat, and neither code review nor a golden test shows it (both land on the same fallback); x-axis labels drop to a second row when they would collide, which they do on every session because baseline sits minutes before t0 while the other points are hours apart; `MiniSparklinePainter` in [lib/widgets/sparkline.dart](lib/widgets/sparkline.dart) takes a `List<double>`. The old per-page painters (`SplinePainter`, `BloodSugarSplinePainter`, `BloodPressureSplinePainter`, `DashboardSplinePainter`) are gone — do not reintroduce a hardcoded bezier for data. [lib/widgets/](lib/widgets/) holds the shared widgets; the welcome and login pages define further painters inline for background art. Note `PulseLinePainter` is defined twice, independently, in [welcome_page.dart](lib/welcome_page.dart) and [login_page.dart](lib/login_page.dart).

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

- **Anything that reaches `LoginPage` needs a fake `AuthService`.** Its default is `AuthHttpService`,
  and an HTTP request under `flutter_test` does not fail loudly — it hangs until the timeout. Pass
  `auth: FakeAuthService()`; `MyApp` and `WelcomePage` take the same parameter purely to forward it,
  exactly like `izin:` below. **It checks credentials** — `terimaSemua` defaults to false, so a test
  that walks through login must use `FakeAuthService.akunDemo` (`test@email.com` / `rahasia123`)
  rather than any string; a fake that accepted anything would never reach `KredensialSalah` on its
  own. `FakeAuthService(paksa: ...)` orders any single `HasilMasuk`, which is
  the only way to reach three of the five failure screens — a real server cannot be asked to time out
  or to lose the network on cue. `jumlahPanggilan` proves the busy button actually blocks a second
  request, which is invisible on screen.
- **Anything that reaches `PemindaianPerangkatPage` needs a fake `IzinBle`.** Its default is the real
  `permission_handler`, which has no platform channel under `flutter_test`. Pass
  `izin: IzinBleSelaluBoleh()` — `MenghubungkanPerangkatPage` takes the same parameter purely to
  forward it.
- **`BleAsliService` itself has no unit tests, and that is deliberate.** It is the part that cannot
  be exercised without a radio; everything separable from the radio was moved into
  `protokol_jam.dart`, `EntriJamRepository`, and the controller, which are all tested. The remaining
  proof is the integration checklist in [docs/protokol-jam.md](docs/protokol-jam.md) §11, which needs
  firmware.

Also: `SharedPreferences.setMockInitialValues(...)` must be called before pumping, and pages roll their own `IconButton` back buttons rather than Material `BackButton`, so `tester.pageBack()` does not work — tap `Icons.arrow_back` instead.

## Gotchas

- **`BerandaTab.build()` calls the async `_loadNama()` on every build.** The equality check inside `_loadNama` is what stops that from becoming an infinite rebuild loop, since `setState` would otherwise schedule the next build, which reloads, and so on. Do not remove it, and do not copy this pattern into other tabs.
- **`ListTile` must not sit inside an opaque `Container`** — it paints ink splashes on the nearest `Material` ancestor, and a `DecoratedBox` in between both hides them and trips a debug assertion. `ProfilTab._buildProfileMenu` shows the working shape: `Material` for the fill, `ListTile.shape` for the border.
- `IndexedStack` builds all five tabs eagerly, so every tab's `initState` runs as soon as the shell mounts — including `ProfilTab`'s loading spinner and its `SharedPreferences` read.

## Assets

Montserrat (weights 400/500/600/700) is bundled under `assets/fonts/` and declared in `pubspec.yaml`; `main()` registers `assets/fonts/OFL.txt` with `LicenseRegistry` to satisfy the SIL Open Font License. Adding a new weight means adding the `.ttf`, the `pubspec.yaml` entry, and the path in the test's `loadMontserrat()`.

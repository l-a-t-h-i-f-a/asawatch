# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`asawatch` — a Flutter health-tracking app UI ("AsaWatch") for a smartwatch companion: heart rate, blood sugar, blood pressure, sleep, plus a food-detection camera flow. All user-facing text is **Bahasa Indonesia**, and file/class names follow the Indonesian domain vocabulary (`beranda` = home, `riwayat` = history, `analisis` = analysis, `profil` = profile, `tujuan kesehatan` = health goals, `deteksi makanan` = food detection). Keep new strings and names in Indonesian to match.

Dart SDK `^3.12.0`. Third-party runtime dependencies: `shared_preferences` (profile + paired-watch
id), `provider` (meal-session surfaces only — see below), `drift`/`drift_flutter` (all local
storage), `flutter_secure_storage` (the login token, and nothing else),
`flutter_blue_plus` (the watch), `permission_handler` (Bluetooth permissions),
`camera` + `image_picker` + `path_provider` (the food photo — see below), and
`flutter_local_notifications` + `timezone` (measurement-point reminders — see
[docs/jadwal-titik-ukur.md](docs/jadwal-titik-ukur.md) §6; since the watch stopped scheduling its own
points, nothing but the app reminds the user).
`drift_dev` + `build_runner` are dev-only, for the generated `basis_data.g.dart`.

**Both BLE-adjacent dependencies are pinned below their latest, for unrelated reasons.**
`flutter_blue_plus` sits at `^1.35.5` because 2.x moved to a licence requiring paid commercial use
and this is a product meant to be sold — upgrading means buying that licence (and passing `license:`
to `connect()`), not just bumping the constraint. `camera` in turn has a **floor**, not a ceiling: it must stay at `^0.12.0`, because every earlier
version pulls a `camera_android_camerax` that applies its own Kotlin Gradle Plugin, which Flutter
already warns about and which future Flutter versions will refuse to build (Built-in Kotlin).
`permission_handler` sits at `^12.0.1` because 13.x
pulls `permission_handler_android` 14, which demands `compileSdk 37` while this project's AGP tops
out at 36; the API `IzinBle` uses is identical in both. **`flutter_secure_storage` is pinned to
`^9.2.4` for exactly that reason** — 11.x hits the same `compileSdk 37` wall (the build fails at
`checkDebugAarMetadata`, naming the plugin), and the three calls `SesiLoginRepositoryAman` makes are
the same in both.

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
flutter run --dart-define=PAKAI_JADWAL_UJI=true --dart-define=FAKTOR_JADWAL_UJI=12  # …compressed 12x, not 60x — use this one with real hardware
flutter run --dart-define=PAKAI_KAMERA_PALSU=true # …with KameraPalsuService — no camera is opened at all
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
   fake models the remote press rather than shortcutting it.
   **The food photo is a real photo now.** `DeteksiMakananPage` runs a live `CameraPreview` and its
   shutter takes a picture; the file is copied out of the camera's cache into
   `<documents>/foto_makanan/` before it becomes the session's `fotoPath`, because that path is
   stored in the database and has to stay valid for months while the cache directory may be cleared
   at any time. **Only the nutrition numbers are still fake** (`FakeNutrisiService`) — there is no
   food-detection endpoint to call — and the two are deliberately not one switch. The seam is
   `KameraService` ([lib/services/kamera_service.dart](lib/services/kamera_service.dart)), with
   `KameraAsliService` in production and `KameraPalsuService` as the test backbone, exactly the
   `BleService`/`FakeBleService` arrangement: `flutter_test` has no platform channel for `camera`,
   so without the fake no test could press the shutter. It is threaded down as `kamera:` through
   `MyApp` → `WelcomePage` → `LoginPage` → `MyHomePage`, the same forwarding-only pattern as `auth:`
   and `izin:` — `LoginPage` pushes `MyHomePage` directly rather than through the named route, so
   the chain has to pass through it. Three things ride along. `_siapkanKamera()` **must not open
   with `setState`**: it is first called from `initState`, which runs inside a build. The camera is
   **released on `AppLifecycleState.inactive/paused` and set up again on `resumed`**, because
   Android takes it away from an invisible app and an unreleased preview comes back as a black
   screen with no error at all. The preview is drawn inside an `AspectRatio` fed by `rasioPratinjau()`, because
   `previewSize` is **always reported landscape-first** whatever way the phone is held: stretched to
   fill a 9:19.5 screen it comes out visibly squashed, and only while aiming — the captured file
   comes from the sensor, so it looks fine afterwards and the defect is easy to dismiss as a fluke.
   And a camera that cannot open gets a full screen with a way out
   (`_LayarGalatKamera`), where a denied permission offers *Buka Pengaturan* rather than "Coba
   Lagi" — the system does not ask twice — while the gallery route, which still works without a
   camera, is always offered. `FotoMakanan` gained an `Image.file` branch (a file that has since
   been deleted falls back to the placeholder, never an error screen) and with it a `dart:io`
   import, which costs nothing new: web already cannot run since sessions moved to SQLite. The
   screens the redesign did not cover remain literal-driven: [tujuan_kesehatan_page.dart](lib/tujuan_kesehatan_page.dart) (its targets), the how-to steps in [menghubungkan_perangkat_page.dart](lib/menghubungkan_perangkat_page.dart), and the auth pages.
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
   ([test/auth_http_service_test.dart](test/auth_http_service_test.dart)). **`galat.kode` is read
   before the HTTP status**, and that is not general caution: the backend answers a wrong password
   with **422 `validasi_gagal`**, not 401, so a status-only reading tells the user the *server* is
   broken and leaves them waiting for something that will never improve. `tidak_terautentikasi`,
   `kredensial_salah`, and `validasi_gagal` all map to `KredensialSalah` — on this endpoint they
   mean the same thing to the user — and anything else, status or code, is `ServerBermasalah`,
   never `KredensialSalah`: telling a user to check a password because the server is broken sends
   them down a dead end. **The wire contract is
   [docs/rancangan-api-laravel.md](docs/rancangan-api-laravel.md) §3.1/§4, and it has been verified
   against the running local backend**: `POST {basisUrlApi}/api/v1/auth/masuk` with
   `email`/`kata_sandi`/`nama_perangkat`, success `{"data": {"token", "profil"}}`, failure
   `{"galat": {"kode", "pesan", "detail"}}`. **There is no refresh token** (§4 chose one 30-day
   Sanctum token plus `keluar-semua`), and no expiry is sent at all — `SesiLogin.masaBerlakuToken`
   mirrors `config/sanctum.php` and must be changed with it. `masuk` also returns no email, so
   `SesiLogin.email` is the address that was just submitted — the only one certain to be right,
   since the token was issued for it. **The token is persisted, and the app stays logged in.**
   `SesiLoginRepository` ([lib/repositories/sesi_login_repository.dart](lib/repositories/sesi_login_repository.dart))
   is the seam — `SesiLoginRepositoryAman` over `flutter_secure_storage` in production
   (**not `SharedPreferences`**: this token opens health data, and preferences are plain XML on
   Android), `SesiLoginRepositoryMemori` as the test backbone. Four things are load-bearing.
   **A 401 from any token-bearing endpoint logs the user out** — `PenjagaSesi`
   ([lib/services/penjaga_sesi.dart](lib/services/penjaga_sesi.dart)) clears the token, says why
   ("Sesi Anda sudah berakhir"), and returns to `/welcome`. Before it, a rejected token only made
   each request fail quietly while the app still presented itself as logged in, which is exactly
   what happened on the test phone after the backend database was rebuilt. Three rules: it is wired
   only into `ProfilHttpService`/`SesiHttpService`, **never into `AuthService.masuk`** (wrong
   credentials are also a 401 and must not throw someone out of a login screen); only 401 triggers
   it, never 5xx (a broken server is no reason to sign anyone out); and it is re-entrant-guarded,
   because re-sending the whole history means one stale token is rejected once per session at
   nearly the same moment. It navigates through `MyApp.navigatorKey`, which `main()` owns because
   the controller — and its `SesiHttpService` — is built before `MyApp` exists.
   `main()` **reads the session before `runApp`** and passes it as `MyApp.sesiAwal`, which is the
   only thing that picks `initialRoute` — reading it inside a loading screen instead would flash the
   welcome page at someone who is already logged in. `muat()` **deletes an expired session and
   returns null** rather than handing back a dead token that would be spent once, refused, and leave
   the user guessing. Logging out **revokes the token on the server before clearing it locally**
   (`AuthService.keluar`, §4 `keluar`) — a Sanctum token lives 30 days, so a local-only logout leaves
   a working key behind — but `keluar` swallows its own failures, because logging out on a phone with
   no signal must still work. And `encryptedSharedPreferences: true` is set **now, before any user
   has data**: changing that flag later makes every stored token unreadable, which shows up as every
   user being thrown back to the login screen after one app update. **`RegisterPage` creates a real account** (§4 `daftar`): it used to
   validate the form, show *"Pendaftaran berhasil! Silakan masuk."*, and pop — a sentence that was
   never true, since no request was ever sent and the account never existed; the person found out one
   screen later, when logging in failed. It now calls `AuthService.daftar()`, which returns the same
   `HasilMasuk` as `masuk()` **because the server hands back a token on registration** — so there is
   no "now log in" step, and the flow after success is identical to login (store token → pull profile
   → `pushAndRemoveUntil` to Beranda). Two rules ride along. `EmailSudahDipakai` is a `HasilMasuk`
   variant rather than its own taxonomy, since every other failure sentence is identical between the
   two flows; it is recognised by **`galat.detail` naming the `email` field**, not by a dedicated code
   — the server has none, the form has already checked the address's shape, so a server complaint
   about that field has effectively one meaning. And the failure is rendered **above the button, not
   as a SnackBar**: it says what to change on the form being looked at, and a toast that disappears
   leaves the person with the same form and no hint.
   **`INTERNET` is now declared in the release manifest too** — it used to live only in
   `android/app/src/debug/`, where Flutter adds it for hot reload, which is why everything worked
   while developing and failed wholesale in a release build with no message naming a permission.
   Android also blocks cleartext HTTP, so the plain-`http://` dev server is reached through
   `android/app/src/debug/res/xml/network_security_config.xml`, which whitelists the dev addresses
   **one at a time** (`10.0.2.2` for the emulator, the laptop's LAN IP for a physical phone) rather
   than permitting cleartext globally — a blanket permission would also cover a production URL that
   one day gets mistyped as `http://`. It is debug-only, so release builds still refuse TLS-less
   connections. Symptom to recognise: without it the app reports *"Tidak ada koneksi internet"*
   while the server is plainly reachable from the laptop's browser.
3. **Finished sessions are uploaded to the server, one way only.**
   `SesiServerService` ([lib/services/sesi_server_service.dart](lib/services/sesi_server_service.dart))
   `PUT`s a session to §5.2 when it ends, and `SesiMakanController.kirimRiwayatKeServer()` re-sends
   the whole history at app start, on resume, and right after login. **There is no "sent" column,
   deliberately**: the id is an app-made UUID and the endpoint is an upsert (§2 rule 2), so
   re-sending is free of consequence — while a "sent" flag that is ever wrong would hide a session
   forever. Upload failure is silent (`debugPrint` only), unlike `galatPenyimpanan`: nothing is lost,
   the next open retries, and warning about something that repairs itself teaches people to ignore
   warnings. **Test sessions are uploaded too, carrying `sesi_uji: true`** — an upload path that only
   real sessions can exercise waits 2.5 hours per attempt, which means it is never exercised. The
   flag is stored, returned, and exported, but **the server no longer branches on it** (that rule was
   dropped on 2026-08-20 so the dashboard would show test data during development), so filtering is
   the reader's job. If the exclusion ever comes back it belongs on the server: filtering in the app
   would trade a small gain for an upload path nobody exercises. **The photo goes up too, and the nutrition numbers come back down with it.** At
   shutter time the draft session is uploaded first (`PUT /sesi/{id}` — the photo endpoint rejects a
   session the server has never seen), then the file (`POST /sesi/{id}/foto`, multipart), then the
   analysis is requested (§6). **`SesiHttpService.mintaAnalisis` hides the polling** — §6 answers
   `202` with a job id, and the app backs off 2→4→8s for about a minute — so the controller still
   sees one call that returns nutrition, exactly like `NutrisiService.analisis`; if §6 ever answers
   directly, only that file changes. **Without a token the whole path is skipped and
   `NutrisiService` answers instead**, because the app has to stay whole without an account (§2
   rule 3). Every step may fail without taking the session down: a failure leaves `hasil` null,
   which the UI now states plainly instead of spinning. **Both halves are retried** —
   `kirimRiwayatKeServer()` re-uploads the photo and re-requests analysis for any finished session
   that still has no `hasil` but still has its local file, because the photo used to be sent exactly
   once, at shutter time, and a session photographed with no signal lost its plate and its numbers
   from the account forever. And the result is **applied to the session wherever it is** — active or
   already in `_riwayat` — since a two-minute test session can end long before a slow analysis
   returns, and dropping the answer then is indistinguishable on screen from an analysis that
   failed. **Downloading exists now too, and only downwards**:
   `unduhRiwayatDariServer()` (`GET /sesi`) runs after every upload pass, so a reinstall, a new
   phone, or a second device recovers its history. Three rules keep the network from damaging what
   is already here: a session that exists locally is **never overwritten** (the phone that recorded
   it knows more — the photo only exists there), a session the server reports as still running is
   **skipped** (one active session at a time, §6, is an app-wide rule), and a failed fetch returns
   **null rather than an empty list**, so "don't know" can never be mistaken for "nothing".
   **The baseline's offset is derived on the way back, never trusted from the wire.**
   `sesiDariJson` recomputes sample 0's `detikRelatifT0` as `waktuFoto - t0` — the same formula
   `SesiMakanController._terimaT0` uses locally — falling back to the wire value only when `t0` is
   null. What the server holds for that one sample is *provisional*: the draft is uploaded at
   shutter time, before the watch button is pressed, so index 0 arrives there `terisi` carrying the
   offset it had before t0 existed, and the backend then freezes it (§2 rule 4 — a filled sample is
   never overwritten, and the correction that follows is refused with nothing but a `Log::info`).
   The other three points are left alone; their offsets are measurements. The symptom is not a
   slightly wrong number but a broken chart: `rentangDetik` spans the axis from the smallest
   `detikRelatifT0`, so a baseline that is far off crushes the remaining points into the right edge
   of the card — which is exactly what a `PAKAI_JAM_PALSU` session looked like after an account
   switch, its baseline stuck at `FakeBleService`'s literal `-1500` against points at 0/10/20 s.
   `hasil` is uploaded and parsed on the way back because it is the one part of a session that
   cannot be recomputed from samples — though the backend does not persist it yet. Photos are not
   uploaded at all, so a downloaded session has an empty `fotoPath` and falls back to
   `FotoMakanan`'s placeholder. **Cancelling a session propagates upwards, through a
   tombstone.** The draft is already on the server by the time anyone can cancel — it is uploaded at
   shutter time — so deleting the local row alone leaves a session that never finishes sitting in the
   account, visible on the dashboard and pulled down by the next device. `batalkan()` therefore
   *nisankan*s the row instead: children, nutrition, and the **photo file** are destroyed, and what
   survives is one row carrying an id and `dihapus_pada`. Four rules. The tombstone is **never
   visible** — `SesiRepositoryDrift.muatSemua` filters it in SQL, not in Dart, so no caller can
   forget and resurrect a cancelled session. The **local half is awaited, the network half is
   not**: after `batalkan()` returns there must be no window in which the row still exists, or an app
   launch landing inside it brings the session back as active. `SesiServerService.hapus`
   (`DELETE /sesi/{id}`, soft delete) counts **404 as success**, because the question is "is it still
   there", not "did I delete something" — anything else breeds a tombstone that cannot die. And the
   sweep runs **first** in `kirimRiwayatKeServer()`, ahead of the upload and therefore ahead of the
   download that follows it, or a session cancelled a moment ago is pulled straight back. A phone
   with no account skips all of it and hard-deletes: there is nobody to tell, and a tombstone that
   can never be sent only accumulates. Two holes remain and both are accepted: `hapusDataLokal()`
   wipes pending tombstones on an account switch (they could only be sent with the previous account's
   token, which is gone), and a reinstall before the sweep loses them the same way. The §7 cursor
   sync is still unwritten.
3. **Everything about a session is persisted, including while it is running.** History lives in SQLite via drift — `SesiRepository` ([lib/repositories/sesi_repository.dart](lib/repositories/sesi_repository.dart)) is the seam, `SesiRepositoryDrift` + the schema in [lib/repositories/basis_data.dart](lib/repositories/basis_data.dart) are the real implementation, and `SesiRepositoryMemori` remains as the in-memory one for tests (the same role `FakeBleService` plays). Editing the schema means re-running `build_runner`; `basis_data.g.dart` is generated and committed. Three things are load-bearing there: enums are stored via `textEnum` so **renaming a `StatusSesi`/`StatusSampel` member is a schema change**, derived values (verdict, kualitas respons) have no columns and are recomputed on load, and `onUpgrade` walks one version at a time with a `default` branch that throws, so a bumped `schemaVersion` cannot ship without a written migration (`test/anchor_repository_test.dart` actually drives v1→v4, v2→v4, and v3→v4). **The controller's constructor stays synchronous on purpose** — `main()` loads history and passes it as `riwayatAwal`, so no session surface needs a loading state. The constructor also **splits the active session out of `riwayatAwal`**: a session that was still running when the app closed comes back as `sesiAktif`, with its schedule recomputed from absolute `t0` (never from remaining time), and its `(sesiId, index)` dedup keys restored. Cancelling turns the row into a tombstone (`SesiRepository.nisankan`, or `hapus` outright when there is no account) — a draft that was abandoned must not come back as an active session. A fresh install starts genuinely empty — `contoh_sesi.dart` is test-only fixture data. Two failure paths are handled: the database failing to open shows `AplikasiGagalMulai` instead of a blank screen, and a session that fails to save sets `SesiMakanController.galatPenyimpanan`, which Beranda shows as a persistent warning card (not a SnackBar — the consequence outlives a toast). The schema is at **v7**: v2 added `tabel_anchor_waktu` ([lib/repositories/anchor_repository.dart](lib/repositories/anchor_repository.dart), [lib/models/anchor_waktu.dart](lib/models/anchor_waktu.dart)); v3 added `tabel_kalibrasi`, `tabel_entri_jam`, and `tabel_sesi.waktu_tidak_pasti` — all three explained in the BLE section below; v4 reshaped calibration into three rounds (`tabel_putaran_kalibrasi` + `tabel_kalibrasi.sisi`, see the calibration section); v5 added `tabel_sesi.sesi_uji`; v6 made the nutrition columns nullable and added `tabel_sesi.diperbarui_pada`; **v7 added `tabel_sesi.dihapus_pada`**, the cancellation tombstone described above. That v3→v4 step is the one to read before writing another migration: it has to ask SQLite (`PRAGMA table_info`) whether the old columns are actually there, because `m.createTable()` in an *earlier* step creates today's shape, not that version's — a device coming from v2 arrives at the v4 step with a table that is already v4-shaped and empty. **The profile is synced with the server, and `SharedPreferences` is its offline half.**
   `ProfilRepository` gained an optional `server:`
   ([lib/services/profil_server_service.dart](lib/services/profil_server_service.dart), §5.1
   `GET`/`PUT /api/v1/profil`) and `sesiLogin:` for the token; with neither it behaves exactly as
   before, which is why **Beranda keeps the server-less form** — it loads the name on *every* build,
   and a network call there would make every rebuild wait on a server. **`sinkronSetelahMasuk()` runs once, right after login and before the shell
   opens** — without it a fresh install greets the user as "Halo" with no name and shows an empty
   profile while the account holds all of it, because nothing else fetches until
   `InformasiPribadiPage` happens to be opened. It also handles **two people on one phone**: when
   the account email differs from the stored one it wipes the local profile first, since `email` and
   `telepon` are not in §5.1 and a server sync would never clear them, leaving the previous user's
   contact details on screen. `InformasiPribadiPage` is the
   other surface that calls `muatSegar()`: the newer timestamp wins (the §7.1 rule, using the new
   `user_updated_at` key), and when the *local* copy is newer it is pushed rather than discarded, so
   an edit made with no signal still lands on the next opening of the page. Four things are
   load-bearing. **`email` and `telepon` do not exist in §5.1**, so a server answer never overwrites
   them — merging without that rule wipes both on every fetch. **Empty strings are sent as `null`**,
   because `""` fails the date-format validator while meaning the same thing as "not filled in".
   **`jenis_kelamin` is translated in one place** (`laki-laki` on the wire, `Laki-laki` on screen) —
   a value absent from the dropdown's `items` makes `DropdownButtonFormField` throw. And **saving
   reports what actually happened**: `StatusSimpanProfil.lokalSaja` gets its own sentence instead of
   "berhasil disimpan", because claiming a save reached the account when it did not is how someone
   loses data by changing phones. The backend answers `PUT` with **201, not 200**, so the check is
   the 2xx class, not the number. **Profile storage itself is still `SharedPreferences`**, but only ever through `ProfilRepository` ([lib/repositories/profil_repository.dart](lib/repositories/profil_repository.dart)) — which keeps the flat `user_*` string keys (`user_name`, `user_dob`, …) so existing installs keep their data. Two of those keys changed *format* rather than name: `user_dob` now holds ISO `yyyy-MM-dd` (picked via `showDatePicker`, rendered through `formatTanggal`), and `user_height`/`user_weight` hold a bare number with the unit moved into the field's `suffixText`. Old-style values are tolerated on read — units are stripped, and an unparseable date reads as unset so the user picks once more. Adding a profile field now means touching `Profil` and `ProfilRepository` and nothing else; the pages ([informasi_pribadi_page.dart](lib/informasi_pribadi_page.dart), [profil_tab.dart](lib/profil_tab.dart), [beranda_tab.dart](lib/beranda_tab.dart)) never see a key. There are no demo defaults any more: an unset field reads as an empty string, `Profil.kosong` is the blank profile, and surfaces decide what to show — Beranda greets "Halo" without a name, ProfilTab invites you to fill it in. Three consequences worth knowing: the gender and blood-type dropdowns hold `String?` because `DropdownButtonFormField` requires its value to exist in `items`, so "unset" has to be null rather than `''`; every field in `InformasiPribadiPage` is now optional and only its *shape* is validated (requiring them all was invisible while demo defaults pre-filled the form, and became a trap the moment they were removed); and the three Unsplash avatars are gone (they showed a stranger, and never loaded in release builds, which at the time declared no `INTERNET` permission).

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
- **Sessions now have a deadline, and it yields to a measurement in progress.**
  `SesiMakanController.tenggatSampelTerakhir` (30 min past the +2 h point) closes a session as
  `tidakLengkap` — **unless the watch is measuring at that very second**, in which case the check is
  postponed 30 s and repeated. Closing then would discard a measurement seconds from finishing, and
  its sample would arrive into a session that is no longer active: lost with no symptom at all. What
  holds the deadline off is **proof, not assumption** — `BleService.jamSedangMengukur()` *reads* the
  Status characteristic (bit0), so a watch that is dead or out of range answers false and the
  deadline runs as before, which is the case the deadline exists for. The postponement is capped at
  12 × 30 s = 6 min, deliberately just past the firmware's own 5-minute hard limit: a real
  measurement never reaches the cap, a stuck bit0 always does. This is not a rare edge: under
  `PAKAI_JADWAL_UJI` the whole session lasts two minutes while one real measurement takes tens of
  seconds, which is exactly how it was found. Before Tahap B the only route there was the user
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

**A measurement in progress is proved by a heartbeat, never by the command having been sent
(protocol v1.4, §5.5/§5.6).** The watch now grows its Status packet to 10 bytes (`ukur_persen`,
`ukur_sisa_detik`) and re-sends it **every 2 seconds while measuring even though nothing in it
changed** — the one deliberate exception to "notify only on change". Without it the `sedang
mengukur` bit is a *level*, not a pulse: firmware suppresses unchanged Status packets, so the bit is
sent exactly twice per measurement (start, end), and a watch that dies mid-measurement leaves it lit
forever, indistinguishable from one still working. That is why `ukurSekarang()` no longer has a
single `timeout(60s)`: 60 s never matched anything (firmware waits 90 s with no skin contact and 5
minutes as its hard limit), so a slow pulse — cold wrist, loose strap, ordinary for an elderly user
— was reported as a watch that did not answer, at the exact moment it was working, and its sample
arrived seconds later and was discarded. Now `_PenantiUkur` is reset by each beat and eight distinct
events each get their own sentence (`PesanUkur`): never started, beats stopped, progress frozen
(**not a failure** — the watch is alive and hunting for a pulse, so it keeps waiting and says
"rapatkan jam"), link dropped, `UKUR_GAGAL` with a zero `sesiId`, watch finished but the sample did
not arrive, and the 5-minute ceiling. Three rules ride along. **Silence is never read as death: when the beat
watchdog fires the app reads the Status characteristic before giving up** (it is Read + Notify, and
firmware refreshes it in `onRead`), so a lost notification, a slow connection interval, or a
firmware that never beats at all costs nothing — only a read that *fails* ends the wait. That is
also what covers firmware ≤ v1.3, whose Status packet is 8 bytes and whose progress fields are
therefore **null, not zero**: it never beats, so the 8-second read is its only liveness, and a v1.3
watch that dies mid-measurement is still caught in seconds rather than after five minutes. **A padam bit0 is given 8 seconds of grace**, because the
firmware sends that Status from inside `ukur_selesai()` while the Sampel leaves through the ring
buffer afterwards, so "status first, sample second" is the normal order. And `KemajuanUkur` reaches
every screen through `SesiMakanController.kemajuanUkur`, where **null means the watch is not
measuring** — `PindaiKesehatanPage`, the calibration card, and `PetunjukTombolUkur` derive their copy
from it rather than from elapsed seconds, which is what used to write "Sedang mengukur" at second 8
no matter what the watch was doing. **It is published for every measurement, not only the one a
screen is awaiting**: `_kabarkanUkur` sits beside `_denyutUkur` in `_terimaStatus` and answers a
different question — that one guards a wait, this one reports the watch's state. A session point
(`UKUR`) has no waiter at all, so while the progress rode on `_PenantiUkur` the longest measurement
anyone actually sits through was the only one showing nothing: the button said "Mengukur…" until the
ACK, a fraction of a second, then lit up again while the watch worked on. **The baseline is the same
gap one step earlier** — it is requested at shutter time, before t0 exists and therefore before
`PetunjukTombolUkur` is on screen at all, so `PetunjukTombolJam` carries its own line for it. That
line never disables the "Selesai Makan" button: firmware deliberately omits the `s_ukur_aktif` check
when that button is pressed (§9), because someone who has finished eating must not wait on a sensor. Its own 8-second staleness
check reads Status once before clearing, so a watch that dies mid-measurement stops claiming to
measure without a waiter to notice. `FakeBleService(denyutUkur:, denyutUkurBerhenti:, persenUkurMacet:)`
models the three watch behaviours; a real watch cannot be ordered to die mid-measurement.

**A critical battery is the watch refusing service, not a low number.** §5.5 `flag` bit2 is set
below `AW_BATERAI_KRITIS_PCT` (10%), and under it the firmware `NAK`s `UKUR`, `UKUR_SEKARANG`,
`ARM_SESI`, and `MULAI_SESI`, and its physical button does nothing (§7 code `0x06`). The bit reached
`StatusJam` and stopped there for a long time: the screen said "8%", the user pressed a button that
was certain to be refused, and the reason arrived only afterwards. It now rides on
`StatusPerangkat.bateraiKritis` — **dropped on disconnect like `baterai`, not retained like
`kemampuan`**, since it is a state that changes by the minute — and
`SesiMakanController.alasanJamTidakBisaUkur` is the single sentence four surfaces share
(`PetunjukTombolUkur`, `PetunjukTombolJam`, `PindaiKesehatanPage`, the calibration card). Two rules.
**The threshold is never re-derived from the percentage**: 10% belongs to the firmware, and a copy
in Dart is a second place that must change in step. And the copy names the *consequence*, never the
number alone — "jam menolak mengukur di bawah 10%" — because 8% and 12% look equally low while only
one of them stops the watch working.

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

**Back on Beranda leaves the app.** `LoginPage` uses `pushAndRemoveUntil`, not `pushReplacement`:
the latter only replaced the login route and left the welcome page underneath, so back on Beranda
surfaced the welcome screen again — which reads as being logged out while the session is still
perfectly valid. With the stack emptied, Beranda is the bottom of the app. `MyHomePage` wraps its
scaffold in a `PopScope` whose `canPop` is `_currentIndex == 0`, so back from any other tab returns
to Beranda first; leaving the app from inside Riwayat is a surprise, not the exit that was asked
for. `test/sesi_login_test.dart` pins both halves (`navigator.canPop()` is false at Beranda).

**Shell / tab bar.** `MyHomePage` in [main.dart](lib/main.dart) owns a hand-rolled bottom nav (a `Container` + `Row`, not `BottomNavigationBar`) over an `IndexedStack` of five tabs. Index 2 is special: it is a raised circular button whose meaning follows the session status — idle pushes `DeteksiMakananPage`, any active session (draft or running) pushes `SesiBerjalanPage` — and it always **pushes** instead of switching tabs, so `_tabs[2]` is a never-shown placeholder and the `IndexedStack` index is clamped (`_currentIndex == 2 ? 0 : _currentIndex`). Any change to tab count or ordering must keep that index-2 carve-out consistent.

**A nutrition number can be unknown, and unknown is not zero.** `Nutrisi`'s six fields are
`double?` and `HasilDeteksi.indeksGlikemikPerkiraan`/`keyakinan` are nullable, because the real
detection service answers with nulls: the TKPI table it reads has no sugar column at all, no
glycaemic index, and no row for a dish it has not been taught. Before this, every null silently
became `0` — or `'sedang'` — and the card presented an estimate nobody had made as a fact, in an app
whose whole subject is blood sugar. Four rules carry it. `Nutrisi + Nutrisi` treats unknown as zero
**but null + null stays null**, so a day with no data reads as unknown rather than "you ate
nothing"; `Nutrisi * faktor` keeps unknown unknown, so correcting a portion never turns a missing
number into 0. **`HasilDeteksi.zatTidakLengkap`** (§5.2 `zat_tidak_lengkap`) marks which totals are
*partial sums* — the UI writes `≥ 459` for those, and `—` when a partial total is 0, because zero
there means "not one food was found in the table", not "no calories". `AnalisisSesi` **drops
sessions whose carbohydrate total is unknown or partial** rather than plotting them low and dragging
the trend line, while a null `keyakinan` counts as reliable (the service reports none at all, so
reading it as "low confidence" would empty the analysis silently). Schema **v6** made the six columns
nullable — via `alterTable`, since SQLite cannot relax NOT NULL, with `zat_tidak_lengkap` declared as
a `newColumns` entry or the copy step names a column the old table never had.

**Sessions carry `diperbaruiPada`, stamped by the repository, not the caller.** It is what
`diperbarui_pada` sends (§7.1 last-write-wins). Sending `DateTime.now()` at upload time — which is
what the app did before v6 — makes every re-send claim to be newer than the server even when nothing
changed, so a re-send would overwrite an edit made elsewhere. Every local write is a local change,
and one place that stamps cannot forget the way a dozen callers can. **`SesiRepository.simpan`
returns the stamp it wrote, and the controller must put it back on the in-memory session**
(`_terapkanStempel`). Stamping only the row is how the first version of this failed: a session born
in the running process kept `diperbaruiPada == null` for its whole life, `badanSesi` fell back to
`waktuFoto`, and the server — whose `updated_at` was set when the *draft* was uploaded at shutter
time — rejected every later upload of that session with **409 `konflik_versi`**. Nothing showed on
the phone; it took 43 conflicts in the backend's log to find. Two consequences ride along:
`_selesaikan` saves *and then* sends, sequentially (two racing `unawaited`s were the same bug), and
a downloaded session is added to `_riwayat` as the repository returned it, not as it arrived.

**Photos are downloaded now, and the server's `foto` field is the authority on who still needs
one.** `GET /sesi` returns `foto: {url, kadaluarsa_pada}` — a signed URL that expires in an hour —
so `ambilSemua` returns `SesiUnduhan` (session + URL) rather than a bare `SesiMakan`: the URL is
never stored, only the **file** it fetches. That guards against two things, not one — the signature
is **bound to the host** it was issued for, and the server derives that host from the incoming
request, so a URL signed while the app talked to `10.0.2.2` answers **403** (not 404) once the
phone reaches the same server as `192.168.x.x`. Storing the URL would produce a dead link with a
message that explains nothing, written into the same `foto_makanan/` folder the shutter
uses (`jalurFotoTetap`). Before this, a downloaded session always had an empty `fotoPath`, so the
plate vanished on a second device, after a reinstall, and after an account switch, while the web
showed it. **The signed URL still needs the token**: `GET /api/v1/foto/{sesi}` carries
`signed` *inside* the `auth:sanctum` group, so the signature only proves the address was not
invented — a download with no `Authorization` header is a 401, which looked exactly like the bug it
was meant to fix (full nutrition numbers, no plate, right after switching accounts). A failed
download leaves `fotoPath` empty and the session otherwise intact — curves and
numbers are worth far more than the picture — but it is **retried on the next upload pass**:
`kirimRiwayatKeServer` downloads the photo for any local session whose `fotoPath` is empty and whose
`foto` the server does have. Without that, rule 1 below (a local session is never overwritten) makes
one failed download permanent. `SesiMakanController.jalurFoto` exists purely as a test
seam: `path_provider` has no platform channel under `flutter_test`, so without it only the failure
path would be reachable. The same field fixes the upload direction: `kirimRiwayatKeServer` used to
treat "this session has nutrition numbers" as proof the photo arrived, which is true only when a
token existed at shutter time — **a session photographed before logging in got its numbers from the
local `NutrisiService`, and its photo was then skipped forever**. It now asks the server which
sessions have no photo and retries exactly those; there is deliberately no "sent" column, for the
same reason sessions have none (§2 rule 2). A failed query falls back to the old guard rather than
to either extreme. `ambilSemua` also **follows `meta.next_cursor`** — §5.2 is cursor-paginated with
`per_page` 50, so reading `data` once silently truncated any history past the first page.

**Switching accounts on one phone wipes what belongs to a person, and it must happen before the
first upload.** `ProfilRepository.sinkronSetelahMasuk` detects the change — it owns the
`user_account_email` key, so a second reader elsewhere would be blind to whichever ran first — and
now **returns `gantiAkun` instead of swallowing it**, because the profile was never the only thing
tied to one person. `SesiMakanController.hapusDataLokal()` drops the rest: session history (with
samples, nutrition, items), blood-pressure calibration, the watch's raw inbox, and every in-memory
copy. The paired watch and its time anchors stay — they belong to the hardware, and making an
elderly user re-pair on every account switch buys nothing. The photo **files** go too, not just
their rows — deleting the rows alone leaves the previous person's meals sitting in
`foto_makanan/`, unreferenced but readable. Three things are load-bearing. **The wipe
must complete before `kirimRiwayatKeServer()`**, which both `LoginPage` and `RegisterPage` now chain
rather than fire in parallel: an upload that starts first puts the previous person's meals into the
account that just logged in, where they are indistinguishable from that account's own. **Calibration
is per-person, not per-phone** — a cuff-derived offset is wrong for anyone but the person it came
from, and keeping it silently corrects the new user's blood pressure with someone else's number for
four weeks; note the offsets already written to the watch's flash (§5.1) are *not* cleared by this,
so the new user must calibrate again before that correction is replaced. And **the raw inbox goes
too**: entries left behind are replayed at startup and would rebuild the sessions just deleted, in
someone else's account. Logging out does **not** wipe anything — logging back in as the same person
must not destroy data, and an offline logout would take unsent sessions with it.

**Status names on the wire are snake_case, and `StatusSesi.name` is not.** `statusKeKawat` /
`statusDariKawat` in [lib/services/sesi_server_service.dart](lib/services/sesi_server_service.dart)
are the only translation, pinned to §5.2 by a test over all six values. Sending the Dart names made
every `tidakLengkap` session 422 on upload, and dropped every `tidak_lengkap` /
`menunggu_perangkat` session silently on download — both invisible, because the app swallows every
non-2xx. It no longer swallows them quietly: a rejected `PUT /sesi/{id}` is `debugPrint`ed with its
status code and the head of the body. That is a log line, not a screen — the rule that a failure
which repairs itself must not be shown to the user is unchanged.

**An empty nutrition slot has two meanings and they must not look alike.**
`RingkasanNutrisi` renders the spinner *only* while an analysis request is genuinely in flight
(`SesiMakanController.sedangMenganalisis(id)`, an in-memory set — after a restart nothing is in
flight, so the answer is honestly false). Otherwise `hasil == null` draws a quiet
*"Rincian makanan tidak tersedia"* line. Before this, every empty slot spun forever, which is what
a downloaded session looks like (its photo stayed on the phone that took it, so nothing will ever
analyse it) and what a permanently failed analysis looks like. `_analisisNutrisi` now notifies in a
`finally`, so a failure repaints instead of leaving the last frame up. Related: `sesiDariJson`
**rejects a session with no samples** — `SesiMakan.baseline` reads `sampel[0]` unguarded, so a
malformed row from the server would be a red screen on Ringkasan Sesi rather than a session that
merely looks empty.

**Charts are all `CustomPainter`** — no charting package — and every data chart is now drawn from data. One generic painter serves them all: `KurvaSampelPainter` in [lib/widgets/kurva_sampel.dart](lib/widgets/kurva_sampel.dart), configured by `SeriMetrik` values (`seriGulaDarah`, `seriDetakJantung`, `seriSistolik`, `seriDiastolik`, `seriSpo2`) that say which metric to pull off each `Sampel`; the y-axis is scaled from the data, so each series carries its own `rentangMinimum` floor — 20 for most, **8 for SpO₂**, because healthy SpO₂ moves between 95 and 100 and the wider floor flattens the only thing worth looking at; **every `TextStyle` inside a painter must set `fontFamily: fontPainter`** — `TextPainter` inherits nothing from the widget tree, so a style without it silently falls back to the platform font (Roboto) while the rest of the app is Montserrat, and neither code review nor a golden test shows it (both land on the same fallback); x-axis labels drop to a second row when they would collide, which they do on every session because baseline sits minutes before t0 while the other points are hours apart; `MiniSparklinePainter` in [lib/widgets/sparkline.dart](lib/widgets/sparkline.dart) takes a `List<double>`. The old per-page painters (`SplinePainter`, `BloodSugarSplinePainter`, `BloodPressureSplinePainter`, `DashboardSplinePainter`) are gone — do not reintroduce a hardcoded bezier for data. [lib/widgets/](lib/widgets/) holds the shared widgets; the welcome and login pages define further painters inline for background art. Note `PulseLinePainter` is defined twice, independently, in [welcome_page.dart](lib/welcome_page.dart) and [login_page.dart](lib/login_page.dart).

**The light system-bar style lives in `MyApp`'s `builder`, not only in `main()`.**
`DeteksiMakananPage` is the one dark screen and sets `gayaSistemGelap` through an
`AnnotatedRegion`; when it pops, Flutter searches the tree for the topmost annotation and, finding
none, leaves whatever was last sent to the platform in place — so the navigation bar stayed black
and the status-bar icons white over every light page until the app was restarted. The
`AnnotatedRegion<SystemUiOverlayStyle>` in `builder` wraps the Navigator, so pushed routes are its
descendants: the camera's annotation still wins while it is visible, and this one takes over again
the moment it is gone. `SystemChrome.setSystemUIOverlayStyle` in `main()` stays for the first
frame. `widget_test.dart` asserts `SystemChrome.latestStyle` across the push and the pop; it fails
if the builder is removed.

**Beranda compares today's intake against nothing, deliberately.** `TargetHarian` and its
2000 kcal / 250 g defaults are deleted: nobody ever chose those numbers, so the progress bars
measured a fraction that meant nothing — and the redesign made it worse by promoting one of them
to the largest text on the page. Today's card now shows the totals it actually knows, and no
denominator. Do not reintroduce a default: the comparison comes back only once Tujuan Kesehatan
can hold a calorie target the user set (Tahap F in [docs/rencana-produksi.md](docs/rencana-produksi.md) §8).
The **empty state is now keyed on "no session today", not "no session ever"** — the camera button
in the nav is the only way to start a session and nothing else on Beranda names it, so the
invitation has to return every morning rather than disappearing after the first meal ever
recorded. `_KartuSesiTerakhir` lost its own empty card in exchange, since two empty cards in a row
said the same thing twice.

**A curve's x-axis comes from its samples, never from a literal.** `KurvaSampelPainter` used to
seed its range at `0..7200` — the production `+2 jam` written as a number — which silently stopped
being true once the schedule became per-session data (docs/jadwal-titik-ukur.md §1): a
`PAKAI_JADWAL_UJI` session whose last point is at second 120 was drawn on a two-hour axis, so all
four points piled into the first 1.7% of the width and every x label landed on top of the next.
`rentangDetik()` is split out of the painter purely so this is testable, and it counts samples that
are still `menunggu` — their `detikRelatifT0` is the schedule's nominal value, which is what keeps
a two-point session from being stretched across the full card as though it had finished. The
two-row x-label fallback now checks **both** rows before placing a label; it only ever checked row
0, so a third colliding label was dropped onto row 1 regardless of what already sat there.

**`RingkasanSesiPage` follows one rule: one number, one place.** The page reads as
long-winded when a figure is repeated, not when it has many sections — delta used to appear three
times (the 46 px number, the verdict sentence, the carbs→peak line), baseline three times, and the
measured-point count twice. Supporting copy now says *what* a number is and never repeats *how
much*: the hero subtitle dropped the baseline value, the curve heading lost its subtitle entirely,
and the verdict is rendered **only when there is no number** — for a finished session it restates
the hero plus the Pemulihan box, but for one without a result it is the only thing that speaks.
`_KaitanKarbo` + `_CatatanKeyakinan` collapsed into `_CatatanMakanan`, one line of what is said
nowhere else (carbs · glycaemic index · detection confidence). `test/sesi_pages_test.dart` asserts
the absences, not just the presences.

Three more places the same rule reached. The curve's reference label reads `baseline`, **not**
`baseline 88` — the dashed line shows *where*, the Baseline box above shows *how much*. The header
no longer prints `Makan Siang` beside `12.40`, because `waktuMakan` is derived from that very hour;
the label only appears when the exact time is unknown, which is the one case where it carries
something (`Waktu tidak pasti`). **Blood pressure now has its own curve section on the summary**, directly under the glucose one:
it is measured at all four points and stored since Tahap A, yet its only appearance used to be a
cell in the collapsed detail table — while SpO₂, which does not move on a healthy session, got a
heading and a full curve. Its heading names the **highest** reading, the mirror of SpO₂ naming the
lowest. It hides entirely when `kemampuan.tekananDarah` is false (§3). And **SpO₂ only draws a
curve when the shape means something** —
`_Spo2Sesi` renders one line for readings at or above `ambangSpo2Wajar` (95) and restores the full
section with its curve below it. Drawing it always cost a quarter of the page for a line
`seriSpo2.rentangMinimum` deliberately flattens; a watch with no SpO₂ sensor still renders nothing
at all (§3). The food photo lives **in the nutrition card, not the page header** — every number in
that card is an estimate from that photo, and the line under them says how confident the detector
was; "82% confident" is unjudgeable without seeing what the detector saw, and a portion that is
clearly wrong only looks wrong with the plate on the same screen. In the header it merely
identified the session, which the meal name beside it already did, so it is not shown twice. The
detail section is `_TabelTitik`, one table rather than four stacked cards: metric name and unit
live in the column head, time on the row, so `mg/dL` is written once instead of four times and
comparing one metric across points is a straight glance down. Its §3 rule is unchanged —
an unsupported metric loses its whole column unless stored values exist for it.

**On Beranda's session card the action sits above the timeline, not under the food card.**
`PetunjukTombolUkur` used to close the card — below the timeline, below the photo, and usually
below the fold — while the countdown it acts on led the card. Reading "6 minutes to go" and then
having to guess that something needs pressing is the confusion that moved it. It now follows
`_HeroSesi` directly, in `ringkas: true` mode: the hero already names the point, its schedule and
its remaining time, so the full widget's explanation box would repeat all three within 12 px while
pushing the button back down. Ringkas mode drops the box but **must keep the reason a dead button
is dead** — that copy moves into the caption line under the button. A draft session has no hero and
puts `PetunjukTombolJam` in the same top slot; "Buka Sesi" is the only thing left at the bottom,
and it is now offered for drafts too. `test/tombol_ukur_test.dart` pins the ordering and that the
button lands above 915 px.

**Beranda has two tiers of card, and the difference is the whole hierarchy.**
`_dekorasiUtama` (white, no border, soft shadow derived from the text colour) marks the one
thing that is asking for something — the running session, today's summary, or the empty state
on a fresh install; `_dekorasiSekunder` keeps the old 1.5 px hairline for everything that is
merely available (last session, peak sparkline, the scan door). Before this, every card wore the
same hairline, so nothing was read first. Three rules ride along. Each primary card leads with
**one** hero number (`_gayaHero`, 36 px) under a small spaced label (`_gayaLabelKecil`) — the
countdown to the next measurement point on a running session, calories on the daily summary, the
peak delta on a finished one — and `test/beranda_test.dart` pins that nothing else on the page is
larger. The **draft session has no hero**: what it waits for is a button press, not a time, and
the sentence saying so already stands in `PetunjukTombolJam` a few pixels below — rendering
"Menunggu" above it pushed that button off a 915 px screen, which is how the rule was found.
And `HitungMundur` takes an optional `gaya`/`gayaSelesai` purely so the hero and the timeline row
can share one implementation at two sizes; its `tabularFigures` is applied on top of whatever
style is passed, because a hero-sized digit that changes width every second rocks the whole row.

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
- **Anything that reaches `DeteksiMakananPage` needs a fake `KameraService`.** Its default is
  `KameraAsliService`, whose `availableCameras()` has no platform channel under `flutter_test`, so
  the page settles on its error screen and the shutter is gone. Pass `kamera: KameraPalsuService()`
  — to the page directly, or to `MyApp` for anything that goes through the shell.
  It is also reachable from a real build with `--dart-define=PAKAI_KAMERA_PALSU=true`
  (`buatKameraBawaan()` in [lib/konfigurasi.dart](lib/konfigurasi.dart)) — for an emulator with no
  camera, a device whose camera permission is deliberately denied, or simply to reach the session
  screens without photographing a plate every time; only the camera is faked, the session and the
  whole BLE flow are untouched.
  `KameraPalsuService(jalurFoto: …)` is how a test pins that the session's `fotoPath` comes from the
  shot, and `KameraPalsuService(galat: …)` is the only way to reach the two error screens, since a
  real camera cannot be ordered to fail.
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

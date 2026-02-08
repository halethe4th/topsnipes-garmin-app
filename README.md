# TopSnipes Garmin App

Production Garmin Connect IQ watch app for TopSnipes shot timing.

## Scope
- Device App (watch-app)
- Deterministic session state machine: `READY -> COUNTDOWN -> LISTENING -> COMPLETE`
- Manual split capture + accelerometer-based shot detection
- Local persistence queue using `Application.Storage`
- Firebase sync queue to `garminSessionUpload`
- One-shot GPS tagging for range location
- Activity recording save to Garmin Connect
- FIT contributor fields: shot count, average split, gps verified
- In-app settings editor for countdown/sensitivity/debounce/max shots/haptics
- App glance summary (last total + pending sync count)

## Repository Layout
- `manifest.xml` - app metadata, permissions, products
- `monkey.jungle` - build configuration
- `resources/` - strings, properties/settings, drawables
- `source/TopSnipesApp.mc` - app entry point
- `source/SessionManager.mc` - core session state machine
- `source/ShotDetector.mc` - accelerometer listener and recoil detection
- `source/StorageManager.mc` - session persistence and sync queue storage
- `source/SyncManager.mc` - HTTPS sync worker/backoff
- `source/views/` - app views
- `source/delegates/` - behavior delegates
- `source/tests/` - unit test functions annotated with `(:test)`
- `resources-round-240x240/` - compact string overrides for smaller round displays
- `resources-round-416x416/` - large round display string overrides

## Local Build
Mac/Linux:
```bash
cp local.build.env.example local.build.env
# Set CIQ_SDK_BIN and DEVELOPER_KEY_PATH in local.build.env
./scripts/build.sh
./scripts/run-sim.sh
```

Windows:
```powershell
Copy-Item .\local.build.ps1.example .\local.build.ps1
# Set CIQ_SDK_BIN and DEVELOPER_KEY_PATH in local.build.ps1
.\scripts\build.ps1
.\scripts\run-sim.ps1
```

## Security Notes
- Never commit private signing keys.
- This repo ignores `*.pem`, `*.key`, `developer_key`, and `developer_key.*`.
- Keep signing key local-only; publishing updates requires the same key.

## QA Checklist
- Build with strict type checks (`project.typecheck = strict`)
- Validate controls on simulator:
  - `START/ENTER`: start countdown, stop session, open review
  - `LAP/ESC` while live: split capture
  - `UP/MENU` hold from idle/complete: open settings
  - `START` during countdown: cancel countdown back to `READY`
- Validate no text overlap on `epix2` and `fenix7` simulator targets
- Validate session stop no longer crashes storage serialization
- Validate GPS remains non-blocking (session can start while GPS acquires)

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

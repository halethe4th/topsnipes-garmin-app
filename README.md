# TopSnipes Garmin App

Standalone Garmin Connect IQ app for TopSnipes shot timing and split capture.

## Structure
- `manifest.xml` - Connect IQ manifest
- `monkey.jungle` - build configuration
- `source/` - Monkey C source
- `resources/` - app resources and strings

## Local Build
Use Connect IQ SDK + Monkey C compiler from Garmin.

Mac/Linux secure setup:
```bash
cp local.build.env.example local.build.env
# Edit local.build.env and set DEVELOPER_KEY_PATH to your private .pem
./scripts/build.sh
./scripts/run-sim.sh
```

Windows example:
```powershell
Copy-Item .\local.build.ps1.example .\local.build.ps1
# Edit local.build.ps1 and set DEVELOPER_KEY_PATH to your private .pem
.\scripts\build.ps1
.\scripts\run-sim.ps1
```

## Notes
This repo is intentionally separate from the web app for dedicated Garmin-focused development.
Never commit private keys (`.pem`) to git or GitHub.

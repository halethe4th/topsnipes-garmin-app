# TopSnipes Garmin App

Standalone Garmin Connect IQ app for TopSnipes shot timing and split capture.

## Structure
- `manifest.xml` - Connect IQ manifest
- `monkey.jungle` - build configuration
- `source/` - Monkey C source
- `resources/` - app resources and strings

## Local Build
Use Connect IQ SDK + Monkey C compiler from Garmin.

Example:
```bash
monkeyc -f monkey.jungle -o bin/TopSnipes.prg -y <developer_key>
```

Windows example:
```powershell
& "C:\Program Files\Garmin\ConnectIQ\Sdk\bin\monkeyc.bat" -f .\monkey.jungle -o .\bin\TopSnipes.prg -y C:\path\to\developer_key.pem -d fenix7
```

Simulator run:
```powershell
& "C:\Program Files\Garmin\ConnectIQ\Sdk\bin\monkeydo.bat" .\bin\TopSnipes.prg fenix7
```

## Notes
This repo is intentionally separate from the web app for dedicated Garmin-focused development.

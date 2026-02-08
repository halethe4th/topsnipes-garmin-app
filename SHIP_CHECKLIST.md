# TopSnipes Garmin App Ship Checklist

## Build and Type Safety
- [ ] `./scripts/build.sh` succeeds with `project.typecheck = strict`
- [ ] No `SymbolNotFound`/undefined key symbol errors
- [ ] No unsupported device id warnings in `manifest.xml`

## Control Validation (per device profile)
- [ ] `START/ENTER` starts countdown from `READY`
- [ ] `START/ENTER` during countdown cancels back to `READY`
- [ ] `START/ENTER` stops active session and opens review
- [ ] `LAP` records split during live session
- [ ] `ESC/BACK` fallback records split during live session when mapped
- [ ] `UP/MENU` hold from idle/complete opens settings view
- [ ] Back exits review/history/settings reliably

## Layout Validation
- [ ] No text overlap at `epix2` (round 416x416)
- [ ] No text overlap at `venusq2` (240x240 family)
- [ ] GPS status is tiny/top only and not stacked over timer content
- [ ] Summary/review screens remain readable with 0-shot and 50-shot sessions

## Runtime Robustness
- [ ] Start -> immediate stop does not crash
- [ ] Rapid start/stop cycles do not crash
- [ ] 50-shot session completes and saves
- [ ] Session restore after app relaunch works
- [ ] Storage serialization uses primitive-safe payloads only

## GPS and Sync
- [ ] Session starts without waiting for GPS lock
- [ ] GPS progress bar reaches full only when verified
- [ ] GPS timeout handled gracefully
- [ ] Pending sync queue uploads when phone reconnects
- [ ] Sync retry backoff does not block UI

## Fit + Garmin Connect
- [ ] Activity saves to Garmin Connect
- [ ] FIT fields populated: shot count, avg split, gps verified
- [ ] App glance shows last session total and pending sync count

## Memory and Battery
- [ ] Peak memory under 80 percent in simulator memory view
- [ ] Battery drain spot check on 30-minute live session is acceptable

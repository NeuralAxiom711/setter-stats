# Setter Stats

A very simple one-player iPhone app for tracking a setter during a volleyball game.

## What it tracks

- Sets played, created automatically when a set rating is recorded
- Attacks
- Serves
- Digs
- Errors
- A rating for each set: 1 Perfect, 2 OK, 3 Needs Improvement

Stats are cumulative for the whole game. There is no team tracking and no per-set stat breakdown.

## Open in Xcode

1. On a Mac with Xcode 15 or newer, open `SetterStatsApp/SetterStatsApp.swift` or create a new iOS App project named `SetterStats` and add the files from `SetterStatsApp` and `Sources/SetterStatsCore`.
2. Add `Sources/SetterStatsCore/GameStats.swift` to the app target.
3. Add `Tests/SetterStatsTests/GameStatsTests.swift` to a unit-test target.
4. Choose an iPhone simulator and Run.

The Linux environment used to generate this project does not include Swift or Xcode, so iOS compilation must be performed on macOS/Xcode.

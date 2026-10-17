# Vex Watcher

Vex Watcher runs on your iPhone and sends live VEX competition ratings to your paired Apple Watch.

The iPhone downloads results from RobotEvents. It connects directly to the watch and pushes each team's percent, record, skills, and a short read on what that team can do. The watch does not talk to RobotEvents itself.

Percents compare teams in the same division. An 80% at a local event is only an 80% against that field.

## Install it on your watch

1. Open `VexWatcher.xcodeproj` in Xcode.
2. At the top, next to VexWatcher, choose **Arjun’s iPhone**. Do not choose any destination that says Simulator.
3. In Signing & Capabilities, set your Apple Team for both **VexWatcher** and **VexWatcherWatch**.
4. Unlock that iPhone and keep your real watch on your wrist, nearby. Press Run. Xcode installs Vex Watcher on the iPhone, and the iPhone installs it on the watch paired with it.
5. On the iPhone, tap **Token** and paste a RobotEvents API token from [robotevents.com/api/v2](https://www.robotevents.com/api/v2).
6. Enter your team number, or an event code such as `RE-V5RC-26-1234`.

Leave the event open on the iPhone during a competition. It refreshes about every 45 seconds while the event is live and sends the new ratings to the watch. If the iPhone is not reachable, the watch keeps the last snapshot and says to open Vex Watcher on the iPhone.

## What the percent means

Each team gets a 0–100 score for this event:

- 30% win rate
- 25% rank in the division
- 25% skills (driver plus programming), compared with the other teams
- 20% scoring, from estimated points added to an alliance when match data is there, otherwise average score

85 and up is Elite, 70 is Strong, 55 is Good, 40 is Average, and below that is Developing. Missing data is left out and the other parts are reweighted.

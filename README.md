# Mochy Music for iOS

Native SwiftUI recreation of the requested Mochy core: anonymous song search, AAC streaming, queue controls, background audio, system Now Playing, synchronized LRCLib lyrics, mini/full player, iPod wheel and bedside clock. Targets iOS 17+, Swift 5 language mode with Xcode 15.3+ (Swift 5.10+ compiler). No third party dependencies, account or API key.

## Open and build

Open `Mochy.xcodeproj` on a Mac, select the **Mochy** scheme and an iPhone simulator, then Run. For a physical device, choose your own bundle identifier and signing team in Signing & Capabilities. A free personal team can run builds subject to Apple's provisioning limits.

The current development environment is Windows: an Xcode compilation and device playback validation have not been performed here. The included project and workflow must pass on macOS before treating the app as a validated release.

## IPA

Push this folder into your GitHub repository and run **Build unsigned IPA** in Actions (also runs on pushes to main/master and pull requests). It runs parser checks, archives for a generic iOS device without signing, packages `Payload/MochyMusic.app`, and uploads **MochyMusic-unsigned**. Download and unzip the Actions artifact to obtain `MochyMusic.ipa`.

The IPA is unsigned. AltStore/Sideloadly must sign it for your device. TrollStore installation depends on supported OS/device and its own requirements. An unsigned archive alone is not installable through normal iOS installation, and no certificate or Apple account is embedded.

## Behavior and boundaries

- Home discovery searches for “trending songs”; it is not an official regional chart feed. Search is debounced and cancels stale requests.
- Playback chooses the highest bitrate direct HTTPS AAC/MP4 audio URL exposed by IOS, VISIONOS, then WEB_REMIX clients. It does not feed WebM/Opus to AVPlayer, because native container compatibility differs from Android.
- InnerTube is undocumented and changes. Some songs require tokens, authentication, signature deciphering or are region restricted; this implementation reports those failures and provides retry. It does not fabricate URLs or guarantee anonymous playback for every song. URLs are resolved again whenever a song is selected/retried rather than persisted.
- Lyrics use LRCLib `/api/get`, title/artist and available duration. LRC supports repeated timestamps, fractions, offsets and Unicode. Missing lyrics show a clear state; plain lyrics are supported without false synchronization.
- Playback queue is the current search result set. Shuffle chooses another queued track; repeat repeats the current song. The app has no download/library/account/playlist import implementation; the selected scope was the specified core.
- iPod wheel rotation changes player volume, center switches between volume/seek, side buttons skip, bottom toggles playback. Player volume is separate from the device's hardware volume.
- Bedside mode keeps the screen awake only while visible. Artwork blur uses the image itself to supply background colors. Reduce Motion disables player/lyric transition animation; controls have accessibility labels.
- Now Playing artwork supplies system media surfaces. iOS controls Dynamic Island presentation; this app does not require a Live Activity.
- HTTPS remains enforced by ATS. No broad network exceptions are required.

## Validation on macOS

The workflow executes `Tests/main.swift` against the real parser. For simulator compilation:

```sh
xcodebuild build -project Mochy.xcodeproj -scheme Mochy -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Before release, verify actual songs on a device: search/empty/offline states, rapid track switching, scrubbing and lyric seek, queue end/shuffle/repeat, pause/resume while resolving, lock-screen artwork and position commands, screen lock/background audio, headphone disconnect, call interruption, and bedside idle timer restoration. Verify wheel gestures and VoiceOver at large text sizes. Public-service availability cannot be established by parser tests.

## Reference and attribution

Inspired by [realidkroo/Mochy-Music](https://github.com/realidkroo/Mochy-Music), which is GPL-3.0 licensed. This workspace contains newly written Swift source and no copied Android source or artwork. [LRCLib](https://lrclib.net/docs) supplies lyrics; YouTube Music supplies third-party search/playback responses. Service data and availability remain controlled by those providers. Preserve upstream licensing if importing any upstream code/assets later.

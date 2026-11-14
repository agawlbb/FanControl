# Mission Log phone playback

Task branch: `feature/iphone-podcast-player`, based on `0014a26219e4ec55d0d2969603549f749cf5f36f`.

The iPhone owns the Mission Log feed, private offline MP3s, progress and completion history. Open **Podcast → Mission Log episodes and player** on the phone. Episodes are grouped by Star Trek series and season; films have their own group. Played episodes and partial progress are indicated. Selecting an episode makes it next without starting playback. Regular TV/film discussions follow publication order, excluding supplementals, bonus entries and unrelated specials.

Five episodes (current plus four ahead) are scheduled for Wi-Fi download. When playback starts on the last downloaded episode, its immediate successor is permitted to download over cellular as well. That exception does not authorize downloading the whole window over cellular. Background execution and transfer scheduling remain controlled by iOS. Failed downloads can be retried on the phone. A missing file never causes streaming, skipping, or delayed autoplay.

The watch Podcast page is a permanent swipe tile, initially last. Move it in the phone's existing Tiles list. Its position is synced locally without adding an HA entity or modifying the HA settings schema. The Driving Podcast button opens it and starts/resumes phone playback; swiping to it only displays controls. Playback continues when leaving the page. Play/Pause, ±15 seconds and Mark Complete are live WatchConnectivity commands; unavailable/expired requests are never queued for later execution. Requested controls appear gray; matching phone evidence confirms them. Completing an episode, manually or at its natural end, stops and prepares the next episode without autoplay.

Phone background audio, Now Playing, standard Play/Pause and 15-second skip controls use the same coordinator. Playback uses the current phone audio route and pauses when an output disconnects or an interruption begins. Reconnection does not start playback. No podcast audio is copied to the watch. The existing HA Podcast script is bypassed by the updated app; no HA deployment is needed.

## Validation

Core regressions cover feed parsing/classification, queue/history restoration, completion and new releases, the cellular exception, stale/expired commands and local tile navigation. The branch Core tests workflow also typechecks all phone and watch sources with Apple's SDKs, without app builds or distribution.

Before device distribution, verify on a paired iPhone/watch: starting with the phone locked or suspended; unreachable and force-quit phone behavior; first download and Wi-Fi replenishment; the cellular exception with Wi-Fi off; ±15-second seeking and restored position; end-of-file and manual completion without autoplay; stale/duplicate callbacks; incoming calls and Bluetooth disconnect/reconnect; tile ordering/default-page behavior; and coexistence with exercise audio and HA controls. Automated checks cannot prove car routing, audible playback or physical watch presentation.

The user subsequently authorized app release on November 14, 2026. Version 0.12.0 (28) is prepared for the existing Internal TestFlight group using the configured GitHub workflow. Device installation and merging remain separate. See RELEASE.md for publication evidence.

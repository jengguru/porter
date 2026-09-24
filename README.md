# Porter

A small macOS menu bar app that switches your **default web browser** in one click, or
with a global shortcut. It's built around toggling between two favorites (Chrome ↔ Safari
out of the box), and any other browser you install shows up without code changes.

- Menu bar icon = the browser that is the default **right now**, including changes made in System Settings.
- **Click** the icon to open the menu. **⌥-click** switches straight to the other favorite.
- **⌃⌥⌘B** (you can change it) switches favorites from any app.
- No Dock icon, no network access, no telemetry, no third-party dependencies.

```
✓ Safari
  Google Chrome
  Brave Browser
──────────────
⇄ Switch to Google Chrome   ⌃⌥⌘B
──────────────
Settings…                   ⌘,
Quit Porter                 ⌘Q
```

Requires macOS 13 Ventura or later. Builds as a Universal app (Apple Silicon + Intel).

## Build

You need Xcode 15 or later (or the matching Command Line Tools).

```sh
git clone https://github.com/jengguru/porter.git
cd porter
swift test                  # unit tests
scripts/build-app.sh        # -> dist/Porter.app (Universal, ad-hoc signed)
```

For a quicker, single-architecture build: `ARCHS=arm64 scripts/build-app.sh`.

To work in Xcode, open `Package.swift`. `swift run Porter` also works for a quick try, but
launch at login and notifications need the real `.app` bundle.

Every push is also built and tested by GitHub Actions on macOS (`.github/workflows/ci.yml`).
The run uploads a `Porter.zip` artifact. Building it yourself is preferable, because a downloaded
ad-hoc-signed app is quarantined by Gatekeeper.

## Install

```sh
ditto dist/Porter.app /Applications/Porter.app
open /Applications/Porter.app
```

Then open **Settings… → General → Launch at login**. If macOS asks, allow Porter under
System Settings › General › Login Items.

Because the app is ad-hoc signed, the first launch of a copy that came from somewhere else
(not built on this Mac) needs a right-click → **Open**.

## The confirmation prompt

Whenever an app changes the default browser, macOS asks
*"Do you want to change your default web browser to …?"*. No public API skips this. Porter
handles it like this:

1. **Default:** you click **Use "…"** yourself. If you click **Keep**, the menu bar icon and
   menu show what macOS actually kept, not what you asked for.
2. **Optional auto-confirm** (Settings → Advanced, off by default): Porter presses the button
   for you using the Accessibility API.

### Granting Accessibility (only for auto-confirm)

1. Settings → Advanced → turn on **Confirm the macOS prompt automatically**.
2. Click **Grant Access…** and enable **Porter** in System Settings › Privacy & Security › Accessibility.
3. The status line in Settings turns green when access is in place.

What auto-confirm is allowed to do, and what it isn't:

- It only runs for **8 seconds after you switch from Porter**. It never runs in the background.
- It only looks at windows of Apple's `CoreServicesUIAgent`, the process that shows this prompt.
- It presses a button only if the window has exactly two buttons and exactly one of them names
  the browser you picked. Otherwise, including after a macOS redesign, it does nothing and you click.

macOS ties this permission to the app's signature. An ad-hoc signed build gets a new signature
each time you rebuild, so after a rebuild remove Porter from the Accessibility list and add it again.

## Adding browsers

Nothing to configure. Porter lists every app that registers itself with macOS as able to open
`http`/`https` links. Install the browser, launch it once, and it appears the next time you
open the menu or Settings. Use **Settings → Menu** to hide browsers or drag them into a new order.

Release channels are separate apps with separate bundle IDs (Chrome, Chrome Beta, Chrome Canary),
so each gets its own entry.

To check a browser's bundle ID:

```sh
mdls -name kMDItemCFBundleIdentifier "/Applications/Brave Browser.app"
```

Known IDs: Safari `com.apple.Safari`, Chrome `com.google.Chrome`, Brave `com.brave.Browser`,
DuckDuckGo `com.duckduckgo.macos.browser`, Tor Browser `org.torproject.torbrowser`. Porter
stores favorites by bundle ID, so moving an app to a different folder doesn't break anything.

If a favorite is uninstalled, Settings shows it greyed out as *Not installed* and **Switch** is
disabled until you pick another. Some Tor Browser builds don't register for `http`. Porter then
explains why it can't set it, instead of failing silently.

## Settings

| Tab | Setting | Default |
|---|---|---|
| General | Favorite A / Favorite B | Google Chrome / Safari |
| General | Menu bar icon: app colors or monochrome | App colors |
| General | Launch at login (`SMAppService`) | Off |
| Menu | Browsers shown in the menu, drag to reorder | All shown |
| Shortcut | Global shortcut, can be changed or turned off; conflicting ones are refused | ⌃⌥⌘B |
| Advanced | Also set the `.html` (`public.html`) file handler | Off |
| Advanced | Auto-confirm the macOS prompt (Accessibility) | Off |
| Advanced | Notification after switching | Off |

Settings live in `UserDefaults` (domain `com.jengguru.porter`). Porter validates what it reads back:
a malformed bundle ID or a shortcut without ⌘/⌥/⌃ falls back to the default.

## Security and privacy

- **No network.** Porter only makes local LaunchServices calls. It opens no connections and has
  no analytics, update checks or crash reporting.
- **The shortcut never overrides another one.** A global shortcut beats every app, so Porter
  only accepts one that uses at least two of ⌘ ⌥ ⌃ (⌘-letter, ⌃-letter and ⌥-letter belong to apps,
  Terminal and typing). It must also not be:
  - enabled in System Settings › Keyboard › Keyboard Shortcuts, read with `CopySymbolicHotKeys`;
  - a standard macOS or browser/Finder menu shortcut such as ⌃⌘Q Lock Screen or ⌥⌘B Bookmarks
    (list in `HotkeyValidator`);
  - held by another app's global shortcut. Porter registers it exclusively and backs off if macOS refuses.

  Porter checks when you record a shortcut and again at every launch. If the shortcut is taken, it
  stays off and both the menu and Settings say why. Shortcuts that exist only inside a particular
  third-party app can't be detected. If one stops working, choose another shortcut in Porter.
- **Hotkey without keyboard monitoring.** The shortcut uses the Carbon `RegisterEventHotKey` API,
  so macOS delivers only that one combination to Porter. It needs no Accessibility or Input
  Monitoring permission. While you record a new shortcut, Porter reads keys from its own
  Settings window only.
- **Only real browsers can become the default.** Porter only sets apps that LaunchServices
  reports as `http` handlers. A tampered preference can't make it point links at some other app.
- **Accessibility is opt-in** and limited as described above.
- **Hardened runtime, no entitlements.** The build script signs with `--options runtime`. The app
  isn't sandboxed because the sandbox doesn't allow changing the default browser.

## How it works

```
Sources/
├── PorterCore/                 # Foundation only, unit-tested
│   ├── Models/                 # Browser, Hotkey, Preferences, KnownBrowsers
│   ├── Services/               # WorkspaceProviding (protocol), BrowserDiscovery, DefaultBrowserService
│   └── Logic/                  # SwitchResolver (toggle target), MenuListBuilder (order/visibility)
└── Porter/                     # the app
    ├── App/                    # PorterMain, AppDelegate, AppModel
    ├── Services/               # SystemWorkspace (NSWorkspace), HotkeyService (Carbon),
    │                           # DialogAutoConfirm (AX), LoginItem, Notifier, IconProvider
    └── Views/                  # StatusItemController (NSStatusItem/NSMenu), SwiftUI settings
Resources/                      # Info.plist (LSUIElement), en.lproj/Localizable.strings
Tests/PorterCoreTests/          # toggle logic, switching/verification, discovery, prefs, hotkeys
scripts/build-app.sh
```

- **Switching** calls `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` for `http` and
  `https`. It asks for `https` only if confirming `http` didn't already change it, so you normally
  see one prompt. Porter then reads the default back and reports that. If the prompt is still
  open, Porter keeps checking for 30 seconds.
- **Staying in sync:** macOS sends no notification when the default browser changes. Porter re-reads
  it every 5 seconds (a cheap LaunchServices lookup, with timer tolerance for low power use) and each
  time the menu opens. The browser list is rescanned when the menu or Settings opens.
- **Menu bar:** an AppKit `NSStatusItem` instead of SwiftUI `MenuBarExtra`, because `MenuBarExtra`
  can't tell ⌥-click apart from a normal click and doesn't size colored app icons well. The
  Settings window is SwiftUI.
- **Toggle rule** (`SwitchResolver`): default is A → B; default is B → A; anything else → A.
  If the target isn't installed, Switch is disabled rather than guessing.

### Localization

UI strings are English and use the English text as the key. To add Thai, copy
`Resources/en.lproj/Localizable.strings` to `Resources/th.lproj/`, translate the values, and add
`th` to `CFBundleLocalizations` in `Resources/Info.plist`.

### Later: per-URL rules (Phase 3)

Routing a link to a browser by domain means Porter would have to be the default browser itself and
forward each URL. `DefaultBrowserService`, `BrowserDiscovery` and the `WorkspaceProviding` protocol
already cover choosing a browser and opening an app. A rules engine would be a new `PorterCore` type
plus a URL handler in the app. It isn't implemented yet.

## Acceptance checklist

- [ ] After launch there is an icon in the menu bar and nothing in the Dock.
- [ ] The icon always matches the real default, including after a change in System Settings (within about 5 s).
- [ ] After Switch (and confirming the prompt), links clicked in other apps open in the new browser.
- [ ] Installing Brave makes it appear in Settings with no code changes.
- [ ] Changing favorites in Settings changes what Switch does right away.
- [ ] With Launch at login on, Porter starts after a restart.

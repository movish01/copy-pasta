# CopyPasta

Clipboard history & sync between iPhone and Mac. No accounts, no iCloud — works over Wi-Fi or the internet.

## How It Works

```
Same Wi-Fi:    Mac ←── Bonjour (direct, <100ms) ──→ iPhone
Any network:   Mac ←── WebSocket relay (E2E encrypted) ──→ iPhone
```

- **LAN sync**: Devices auto-discover each other on the same Wi-Fi via Bonjour
- **Relay sync**: Devices connect through a lightweight relay server using a shared passphrase
- **E2E encrypted**: Relay messages are AES-256-GCM encrypted — the server never sees your clipboard
- **No accounts**: Just a passphrase you pick, stored locally in Keychain

## Features

- Clipboard history with search, filter, and pin
- Auto-detect content type (text, URL, code)
- Mac menu bar app with auto clipboard monitoring
- iOS app with Share Extension
- Swipe to send, pin, or delete items
- "Send to device" like AirDrop for text

## Requirements

- **Xcode 15+**
- **macOS 14+** (Sonoma)
- **iOS 17+**
- Free Apple ID (for code signing)

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/movish01/copy-pasta.git
cd copy-pasta
```

### 2. Generate the Xcode project

```bash
brew install xcodegen    # if not installed
xcodegen generate
```

### 3. Open in Xcode

```bash
open CopyPasta.xcodeproj
```

### 4. Run the Mac app

1. Select **CopyPastaMac** scheme from the top bar
2. Set your **Team** in Signing & Capabilities (your Apple ID)
3. Press `Cmd+R`
4. A clipboard icon appears in your **menu bar** — that's the app

### 5. Run the iPhone app

1. Plug your iPhone in via **USB**
2. On iPhone: **Settings → Privacy & Security → Developer Mode** → turn ON
3. In Xcode: select **CopyPastaiOS** scheme
4. Select your **iPhone** from the device dropdown
5. Set your **Team** in Signing & Capabilities
6. Press `Cmd+R`
7. First time: on iPhone go to **Settings → General → VPN & Device Management** → Trust

### 6. Connect devices (relay sync)

This step lets your devices sync from **anywhere** — not just the same Wi-Fi.

**On Mac:**
1. Click the CopyPasta menu bar icon
2. Click the `...` menu → **Settings** → **Network** tab
3. Click **Set Up Relay Sync**
4. Enter a passphrase (e.g. `tiger-ocean-seven-lamp`) or tap **Generate Random Phrase**
5. Click **Connect**

**On iPhone:**
1. Open CopyPasta
2. Go to **Devices** tab
3. Tap **Set Up Relay Sync**
4. Enter the **same passphrase** you used on Mac
5. Tap **Connect**

Both devices are now linked. The passphrase is saved in Keychain and auto-reconnects on future launches.

## Usage

### Copy on Mac → Paste on iPhone

1. `Cmd+C` anything on Mac
2. Mac auto-detects it and sends to iPhone
3. iPhone receives it and auto-copies to clipboard
4. Paste anywhere on iPhone

### Copy on iPhone → Paste on Mac

1. Copy something on iPhone
2. Open CopyPasta app (it auto-captures clipboard on foreground)
3. Or use **Share sheet** from any app → CopyPasta
4. Mac receives it and auto-copies to clipboard
5. `Cmd+V` anywhere on Mac

### Clipboard History

- **Search**: Type in the search bar to find past items
- **Filter**: All / Pinned / Text / URLs / This Device
- **Pin**: Keep important items from being cleared (swipe right on iOS, right-click on Mac)
- **Send**: Swipe right or right-click → "Send to device"
- **Delete**: Swipe left on iOS, right-click on Mac

## Relay Server

The relay server at `copypasta-relay.onrender.com` is a stateless WebSocket forwarder. It:

- Forwards encrypted blobs between devices in the same room
- Never stores or decrypts messages
- Sleeps after 15 min of no connections (free tier) — wakes up in ~30s on reconnect
- Source code is in `relay-server/`

### Self-host the relay

```bash
cd relay-server
npm install
node server.js
```

Or deploy with Docker:

```bash
cd relay-server
docker build -t copypasta-relay .
docker run -p 8080:8080 copypasta-relay
```

To use your own server, update the URL in **Shared/Services/RelayConfig.swift** or set the `relayServerURL` UserDefaults key.

## Project Structure

```
Shared/                          ← Used by both platforms
├── Models/
│   ├── ClipboardItem.swift      ← SwiftData model
│   ├── SyncMessage.swift        ← JSON message for sync
│   └── DeviceInfo.swift         ← Device name/ID helper
├── Services/
│   ├── BonjourSyncService.swift ← LAN discovery + TCP
│   ├── RelaySyncService.swift   ← WebSocket client
│   ├── RelayCrypto.swift        ← AES-256-GCM encryption
│   ├── SyncCoordinator.swift    ← Orchestrates both services
│   ├── KeychainHelper.swift     ← Secure passphrase storage
│   └── RelayConfig.swift        ← Server URL config
├── ViewModels/
│   └── ClipboardHistoryViewModel.swift
└── Views/
    ├── ClipboardItemRow.swift
    ├── FilterBar.swift
    ├── SyncStatusView.swift
    └── RelaySetupView.swift

macOS/                           ← Mac menu bar app
├── CopyPastaMacApp.swift
├── Services/
│   └── MacClipboardMonitor.swift
└── Views/
    ├── MenuBarPopover.swift
    └── SettingsView.swift

iOS/                             ← iPhone app
├── CopyPastaiOSApp.swift
└── Views/
    ├── MainTabView.swift
    ├── ClipboardHistoryView.swift
    ├── ItemDetailView.swift
    ├── DevicesView.swift
    └── iOSSettingsView.swift

ShareExtension/                  ← iOS Share sheet
├── ShareViewController.swift
└── Info.plist

relay-server/                    ← Node.js relay
├── server.js
├── package.json
├── Dockerfile
└── fly.toml
```

## Note on iOS Limitations

iOS does not allow background clipboard access. The iPhone app captures clipboard content when:

- The app comes to the **foreground**
- You use the **Share Extension** from any app
- You tap the **+** button in the app

The Mac app monitors clipboard automatically every 0.5 seconds.

## Free Apple ID Limitation

With a free Apple ID, apps installed on your iPhone expire after **7 days**. You'll need to re-run from Xcode. A paid Apple Developer account ($99/year) removes this limit. Alternatively, use [AltStore](https://altstore.io) to auto-refresh the signing.

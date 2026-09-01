# HDRezka App — Native iOS & iPadOS Streaming Client

A production-grade, cinematic native iOS and iPadOS media streaming client inspired by the visual design language and fluid UX of **Apple TV+**, **Netflix**, and **Hulu**.

Built with **SwiftUI**, **AVFoundation**, **Swift 6 Concurrency**, and zero-cost cloud infrastructure (**Cloudflare Workers**, **Convex Real-Time DB**, and optional **24/7 Mac Mini Companion**).

---

## 📸 Architecture & Features

```
+-----------------------------------------------------------------------------------+
|                        HDREZKA ECOSYSTEM ARCHITECTURE                             |
+-----------------------------------------------------------------------------------+

   +-----------------------------------------------------------------------------+
   |                     NATIVE iOS & iPadOS CLIENT (SwiftUI)                     |
   |                                                                             |
   |  * Apple TV+ / Netflix / Hulu Ultra-Fluid Cinematic Glassmorphic Design     |
   |  * Custom AVPlayer / AVPlayerViewController / AVFoundation Streaming Engine |
   |  * Multi-Track Audio (Translations / Dubs / Voice-Overs)                    |
   |  * Subtitles (VTT/SRT parsing, live sync & custom styling)                  |
   |  * Quality Selector (360p, 480p, 720p, 1080p, 1080p Ultra, 4K, Auto/HLS)   |
   |  * Picture-in-Picture (PiP), Background Audio, AirPlay, Lockscreen Controls |
   |  * Seasons & Episodes Grid, Episode Quick Switcher in Player                |
   |  * Continue Watching with precise progress resume & auto-next episode       |
   |  * Instant Search, Filters (Genre, Year, Rating, Type), Bookmarks/Watchlist |
   |  * Dual Engine Architecture: Direct Scraper Engine + Cloud API Bridge       |
   |  * Offline Cache & History Persistence                                      |
   +-----------------------------------------------------------------------------+
                                   |                 |
          API & Stream Requests    |                 | Real-time Sync & State
                                   v                 v
   +---------------------------------------+   +---------------------------------+
   |      CLOUDFLARE WORKER / VERCEL       |   |       CONVEX CLOUD BACKEND      |
   |        (Zero-Cost Edge Gateway)       |   |        (Zero-Cost DB & Sync)    |
   |                                       |   |                                 |
   | * HDRezka Scraper & Parser Gateway    |   | * User Profiles & Preferences   |
   | * Mirror Rotation & Health Checker    |   | * Watchlist & Favorites Sync    |
   | * Anti-block bypass & Header Spoofing |   | * Continue Watching Progress    |
   | * HLS Stream / M3U8 Rewriter & Proxy  |   | * Cross-device State Sync       |
   | * Stream Decryption & Caching (KV)    |   |   (iPhone <-> iPad <-> Mac)     |
   +---------------------------------------+   +---------------------------------+
                                   ^
                                   | (Optional residential proxy / companion)
   +-----------------------------------------------------------------------------+
   |                  MAC MINI 24/7 COMPANION DAEMON (Optional)                  |
   | * Local Fast Cache & Scraper Node                                           |
   | * Stream Relay & Local Network Proxy                                        |
   | * Automatic Mirror Discovery & 24/7 Background Health Monitor               |
   +-----------------------------------------------------------------------------+
                                   |
                                   v
   +-----------------------------------------------------------------------------+
   |                        HDREZKA ORIGIN & CDNs                                |
   |                     (rezka.ag, mirrors & video CDNs)                        |
   +-----------------------------------------------------------------------------+
```

---

## 🌟 Key Highlights

### 1. Apple TV+ & Netflix Fluid Design Language
- **Cinematic Glassmorphism**: Tailored dark theme (`#0A0D14`, `#141A26`, `#1C2433`) with glowing Rezka Gold (`#F59E0B`) and Neon Cyan (`#06B6D4`) accents.
- **Dynamic Hero Carousel**: Auto-rotating hero header with high-definition backdrops, movie badges (4K HDR, IMDb/KP ratings, age ratings), and instant "Watch Now" action.
- **Interactive Media Details**: Full backdrop header, expandable synopsis, voiceover & audio studio chips, interactive season/episode explorer, and cast & crew pills.
- **Adaptive iOS & iPadOS Layouts**: Bottom TabBar on iPhone, and native `NavigationSplitView` sidebar on iPad and Mac.

### 2. High-Performance AVFoundation Player Engine
- **Custom Player HUD**: Auto-hiding HUD controls with tactile 10s skip gestures, double-tap left/right ripple rewind/forward, smooth scrub bar with buffer progress and remaining time countdown.
- **Instant Audio & Voice-Over Switch**: Switch between Dubbing, LostFilm, Red Head Sound, HDRezka Studio, and Original audio on the fly without interrupting playback.
- **Multi-Resolution Video Selector**: Seamlessly switch between 4K, 1080p Ultra, 1080p, 720p, 480p, 360p, and Auto HLS while preserving exact timestamp position.
- **Live Styled Subtitles**: Integrated WebVTT and SRT subtitle parser with customizable font scale and background opacity.
- **Picture-in-Picture (PiP) & AirPlay**: Native PiP support and background audio session with lock screen Now Playing information.
- **Auto-Play Next Episode**: Smooth countdown banner with "Play Now" and "Cancel" buttons.

### 3. Dual-Engine Architecture
- **Direct Mode**: On-device pure Swift scraper & trash cipher decryptor. Can operate completely standalone without any servers.
- **Edge Cloud Mode**: Free Cloudflare Worker edge gateway for high-speed CDN proxying and ISP bypass.

### 4. Zero-Cost Ecosystem
1. **Cloudflare Worker** (`cloudflare-worker/`): 100,000 requests/day free tier for edge scraping and stream deobfuscation.
2. **Convex Backend** (`convex/`): Free tier real-time reactive sync for Continue Watching, Watchlist, and User Preferences across iPhone, iPad, and Mac.
3. **Mac Mini 24/7 Companion** (`mac-mini-daemon/`): Lightweight `launchd` background service for local proxying and 24/7 mirror health monitoring.

---

## 🛠️ Project Structure

```
hdrezka-app/
├── Package.swift                             # Swift Package configuration
├── Sources/
│   ├── HDRezkaApp/                           # App Executable Target
│   │   └── HDRezkaApp.swift                  # App entry point
│   └── HDRezkaCore/                          # Reusable Core Framework
│       ├── Models/
│       │   └── MediaModels.swift             # Data models (MediaItem, StreamBundle, Season, Episode, etc.)
│       ├── Engine/
│       │   ├── RezkaStreamDecoder.swift      # Pure Swift trash cipher deobfuscator & stream parser
│       │   ├── HDRezkaScraperEngine.swift    # HTML parser, search engine, and stream fetcher
│       │   └── MirrorManager.swift           # Mirror latency testing, failover & persistence
│       ├── Player/
│       │   ├── PlaybackManager.swift         # AVPlayer controller, PiP, lock screen controls
│       │   └── SubtitleManager.swift         # WebVTT / SRT subtitle parser & live timestamp tracker
│       ├── Storage/
│       │   └── LocalStorageManager.swift     # Watch progress, watchlist, and user settings storage
│       ├── Cloud/
│       │   ├── CloudflareClient.swift        # Cloudflare edge gateway client
│       │   └── ConvexClient.swift            # Convex real-time sync manager
│       └── Views/
│           ├── DesignSystem/
│           │   └── Theme.swift               # RezkaTheme colors, glass cards & button styles
│           ├── Components/
│           │   ├── HeroCarouselView.swift    # Apple TV+ style dynamic hero banner
│           │   ├── MediaCardView.swift       # Netflix style poster card with progress bar
│           │   └── MediaRowSectionView.swift # Horizontal scrolling content carousels
│           ├── Detail/
│           │   └── MediaDetailView.swift     # Detailed media view with translation/season picker
│           ├── Player/
│           │   └── CustomPlayerOverlayView.swift # Cinematic video player HUD overlay
│           ├── Search/
│           │   └── SearchView.swift          # Search & discovery with filter chips
│           ├── Library/
│           │   └── LibraryView.swift         # Continue watching, watchlist & history
│           ├── Settings/
│           │   └── SettingsView.swift        # Mirror latency tester, cloud config & player settings
│           ├── Home/
│           │   └── HomeFeedView.swift        # Main home feed with category rows
│           └── Navigation/
│               └── AppRootView.swift         # Responsive iPhone TabView & iPad NavigationSplitView
├── Tests/
│   └── HDRezkaCoreTests/
│       └── RezkaStreamDecoderTests.swift     # Unit tests for decryption & parsing
├── cloudflare-worker/                        # Zero-cost Cloudflare Worker Edge Gateway
│   ├── wrangler.jsonc
│   ├── package.json
│   ├── src/index.ts
│   └── README.md
├── convex/                                   # Zero-cost Convex Real-Time Backend
│   ├── schema.ts
│   ├── progress.ts
│   ├── watchlist.ts
│   ├── package.json
│   └── README.md
└── mac-mini-daemon/                          # 24/7 Mac Mini Companion Service
    ├── server.ts
    ├── com.hdrezka.daemon.plist
    ├── install.sh
    └── README.md
```

---

## 🚀 Getting Started

### 1. Build and Run in Xcode
Open the generated Xcode project directly:
```bash
open HDRezkaApp.xcodeproj
```
Or open via Swift Package Manager:
```bash
open Package.swift
```

To run tests from command line:
```bash
swift test
```

To regenerate the `.xcodeproj` anytime using XcodeGen:
```bash
xcodegen generate
```

### 2. (Optional) Deploy Cloudflare Worker (Free)
```bash
cd cloudflare-worker
npx wrangler deploy
```

### 3. (Optional) Start Convex Real-Time Sync (Free)
```bash
cd convex
npx convex dev
```

### 4. (Optional) Install Mac Mini 24/7 Daemon
```bash
cd mac-mini-daemon
chmod +x install.sh
./install.sh
```

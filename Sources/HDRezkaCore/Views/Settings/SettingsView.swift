import SwiftUI

public struct SettingsView: View {
    @State private var settings = UserSettings()
    @State private var mirrorStatuses: [MirrorStatus] = []
    @State private var isCheckingMirrors: Bool = false
    @State private var customMirrorInput: String = ""
    @State private var edgeEndpointInput: String = ""
    @State private var convexURLInput: String = ""
    @State private var activeMirrorURL: String = ""
    @State private var showResetAlert: Bool = false
    @State private var accountUsername: String = UserDefaults.standard.string(forKey: "rezka_username") ?? ""
    @State private var accountPassword: String = ""
    @State private var manualCookieInput: String = ""
    @State private var isLoggingIn: Bool = false
    @State private var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "rezka_logged_in")
    @State private var loginMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                RezkaTheme.bgDeep.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // HDRezka Account Login Section
                        accountSection
                        
                        // Mirror Management Section
                        mirrorSection
                        
                        // Cloud Ecosystem Section (Cloudflare, Convex, Mac Mini)
                        cloudEcosystemSection
                        
                        // Playback Preferences Section
                        playbackSection
                        
                        // Subtitles & Appearance Section
                        subtitlesSection
                        
                        // Cache & Diagnostics Section
                        cacheAndInfoSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings & Network")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(RezkaTheme.bgDeep, for: .navigationBar)
            #endif
        }
        .task {
            await loadSettings()
        }
    }
    
    // MARK: - HDRezka Account Login
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "HDRezka Account & VIP (Unlocks 1080p/4K)", icon: "person.crop.circle.badge.checkmark")
            
            VStack(spacing: 12) {
                if isLoggedIn {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(RezkaTheme.accentAmber)
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Logged In: \(accountUsername)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("1080p Ultra & 4K Streams Active")
                                .font(.system(size: 12))
                                .foregroundColor(RezkaTheme.accentCyan)
                        }
                        
                        Spacer()
                        
                        Button("Sign Out") {
                            UserDefaults.standard.set(false, forKey: "rezka_logged_in")
                            UserDefaults.standard.removeObject(forKey: "rezka_username")
                            isLoggedIn = false
                            accountPassword = ""
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Log in with your free or VIP HDRezka account to stream full 2+ hour movies and series in 1080p/4K directly without restrictions.")
                            .font(.system(size: 12))
                            .foregroundColor(RezkaTheme.textSecondary)
                        
                        VStack(spacing: 8) {
                            TextField("Username or Email", text: $accountUsername)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(RezkaTheme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .autocorrectionDisabled()
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                #endif
                            
                            SecureField("Password", text: $accountPassword)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(RezkaTheme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        if let msg = loginMessage {
                            Text(msg)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isLoggedIn ? .green : .red)
                        }
                        
                        Button(action: performLogin) {
                            HStack {
                                if isLoggingIn {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "key.fill")
                                    Text("Sign In to HDRezka")
                                }
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RezkaTheme.accentAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isLoggingIn || accountUsername.isEmpty || accountPassword.isEmpty)
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)
                        
                        // Or paste cookie string directly
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Or Import Cookie String (from browser):")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(RezkaTheme.textSecondary)
                            
                            HStack {
                                TextField("dle_user_id=...; dle_password=...", text: $manualCookieInput)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(RezkaTheme.bgCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button("Import") {
                                    if !manualCookieInput.isEmpty {
                                        Task {
                                            await HDRezkaScraperEngine.shared.setManualCookieString(manualCookieInput)
                                            isLoggedIn = true
                                            UserDefaults.standard.set(true, forKey: "rezka_logged_in")
                                            UserDefaults.standard.set("Imported Session", forKey: "rezka_username")
                                            loginMessage = "✅ Cookies imported successfully! 1080p/4K active."
                                            manualCookieInput = ""
                                        }
                                    }
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(RezkaTheme.accentCyan)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }
    
    private func performLogin() {
        guard !accountUsername.isEmpty, !accountPassword.isEmpty else { return }
        isLoggingIn = true
        loginMessage = nil
        
        Task {
            let success = (try? await HDRezkaScraperEngine.shared.login(username: accountUsername, password: accountPassword)) ?? false
            isLoggingIn = false
            if success {
                isLoggedIn = true
                UserDefaults.standard.set(true, forKey: "rezka_logged_in")
                UserDefaults.standard.set(accountUsername, forKey: "rezka_username")
                loginMessage = "✅ Successfully logged in! 1080p/4K streams enabled."
            } else {
                loginMessage = "❌ Invalid username/password or mirror connection error. Try importing cookies or checking active mirror."
            }
        }
    }
    
    // MARK: - Mirror Management
    private var mirrorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Mirror & Connectivity", icon: "network")
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Mirror")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(activeMirrorURL)
                            .font(.system(size: 12))
                            .foregroundColor(RezkaTheme.accentCyan)
                    }
                    
                    Spacer()
                    
                    Button(action: checkMirrors) {
                        if isCheckingMirrors {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Test Latency")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RezkaTheme.accentAmber)
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Mirror Status List
                VStack(spacing: 8) {
                    ForEach(mirrorStatuses) { status in
                        HStack {
                            Circle()
                                .fill(status.isAlive ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(status.url.host ?? status.url.absoluteString)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if let ms = status.latencyMs {
                                Text("\(ms) ms")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(ms < 300 ? .green : .orange)
                            } else {
                                Text("Offline")
                                    .font(.system(size: 12))
                                    .foregroundColor(RezkaTheme.textTertiary)
                            }
                            
                            if status.url.absoluteString == activeMirrorURL {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(RezkaTheme.accentCyan)
                                    .font(.system(size: 14))
                            } else {
                                Button("Select") {
                                    Task {
                                        await MirrorManager.shared.setActiveMirror(status.url)
                                        activeMirrorURL = status.url.absoluteString
                                    }
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(RezkaTheme.accentCyan)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Add Custom Mirror
                HStack {
                    TextField("https://custom-mirror.com", text: $customMirrorInput)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    
                    Button("Add") {
                        if let u = URL(string: customMirrorInput), !customMirrorInput.isEmpty {
                            Task {
                                await MirrorManager.shared.addCustomMirror(u)
                                customMirrorInput = ""
                                await loadSettings()
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RezkaTheme.accentAmber)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }
    
    // MARK: - Zero-Cost Cloud Ecosystem
    private var cloudEcosystemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Zero-Cost Cloud & Edge Setup", icon: "cloud.fill")
            
            VStack(spacing: 14) {
                // Cloudflare Edge Gateway
                Toggle(isOn: $settings.useCloudEdgeProxy) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloudflare Edge Gateway")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Bypasses ISP blocks & optimizes HLS streams")
                            .font(.system(size: 11))
                            .foregroundColor(RezkaTheme.textSecondary)
                    }
                }
                .tint(RezkaTheme.accentAmber)
                .onChange(of: settings.useCloudEdgeProxy) { _, enabled in
                    saveSettings()
                }
                
                if settings.useCloudEdgeProxy {
                    TextField("Worker URL: https://rezka-worker.workers.dev", text: $edgeEndpointInput)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(RezkaTheme.bgCardHover)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onSubmit {
                            settings.customEdgeEndpoint = edgeEndpointInput
                            saveSettings()
                        }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Mac Mini 24/7 Home Node
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mac Mini 24/7 Home Node")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("http://192.168.1.147:7890")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(RezkaTheme.accentCyan)
                        }
                        
                        Spacer()
                        
                        Button("Use Node") {
                            if let u = URL(string: "http://192.168.1.147:7890") {
                                Task {
                                    await MirrorManager.shared.setActiveMirror(u)
                                    activeMirrorURL = u.absoluteString
                                }
                            }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RezkaTheme.accentAmber)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }
    
    // MARK: - Playback Preferences
    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Playback Defaults", icon: "play.circle")
            
            VStack(spacing: 14) {
                // Preferred Quality
                HStack {
                    Text("Default Video Quality")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Picker("Quality", selection: $settings.defaultQuality) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(RezkaTheme.accentAmber)
                    .onChange(of: settings.defaultQuality) { _, _ in
                        saveSettings()
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Auto Play Next Episode
                Toggle(isOn: $settings.autoPlayNextEpisode) {
                    Text("Auto-Play Next Episode")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .tint(RezkaTheme.accentAmber)
                .onChange(of: settings.autoPlayNextEpisode) { _, _ in
                    saveSettings()
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }
    
    // MARK: - Subtitles & Appearance
    private var subtitlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Subtitles & Display", icon: "captions.bubble")
            
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Subtitle Text Size")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1fx", settings.subtitleScale))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(RezkaTheme.accentCyan)
                    }
                    
                    Slider(value: $settings.subtitleScale, in: 0.8...1.6, step: 0.1)
                        .tint(RezkaTheme.accentCyan)
                        .onChange(of: settings.subtitleScale) { _, _ in
                            saveSettings()
                        }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }
    
    // MARK: - Cache & Info
    private var cacheAndInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Storage & Diagnostics", icon: "info.circle")
            
            VStack(spacing: 12) {
                HStack {
                    Text("App Version")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("HDRezka v1.0 (Build 2026)")
                        .font(.system(size: 13))
                        .foregroundColor(RezkaTheme.textSecondary)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                Button(action: {
                    Task {
                        await LocalStorageManager.shared.clearAllHistory()
                        showResetAlert = true
                    }
                }) {
                    HStack {
                        Text("Clear Cache & Playback History")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(RezkaTheme.accentCrimson)
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundColor(RezkaTheme.accentCrimson)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
        .alert("Cache Cleared", isPresented: $showResetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Temporary cache and watch history have been successfully reset.")
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(RezkaTheme.accentAmber)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(RezkaTheme.textSecondary)
                .textCase(.uppercase)
        }
    }
    
    private func loadSettings() async {
        settings = await LocalStorageManager.shared.getSettings()
        activeMirrorURL = (await MirrorManager.shared.getActiveMirror()).absoluteString
        mirrorStatuses = await MirrorManager.shared.getStatuses()
        edgeEndpointInput = settings.customEdgeEndpoint ?? ""
        if mirrorStatuses.isEmpty {
            checkMirrors()
        }
    }
    
    private func checkMirrors() {
        isCheckingMirrors = true
        Task {
            let results = await MirrorManager.shared.checkMirrorsHealth()
            mirrorStatuses = results
            activeMirrorURL = (await MirrorManager.shared.getActiveMirror()).absoluteString
            isCheckingMirrors = false
        }
    }
    
    private func saveSettings() {
        Task {
            await LocalStorageManager.shared.updateSettings(settings)
        }
    }
}

import SwiftUI
import AVKit

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit

public final class AVPlayerLayerView: UIView {
    public override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    public var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

public struct NativePlayerView: UIViewRepresentable {
    public let player: AVPlayer
    
    public init(player: AVPlayer) {
        self.player = player
    }
    
    public func makeUIView(context: Context) -> AVPlayerLayerView {
        let view = AVPlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }
    
    public func updateUIView(_ uiView: AVPlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

public enum OrientationManager {
    public static func enterLandscape() {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
            windowScene.requestGeometryUpdate(geometryPreferences)
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    public static func enterPortrait() {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            windowScene.requestGeometryUpdate(geometryPreferences)
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    
    public static func toggleOrientation(isLandscape: Bool) {
        if isLandscape {
            enterPortrait()
        } else {
            enterLandscape()
        }
    }
}
#elseif os(macOS)
import AppKit

public struct NativePlayerView: NSViewRepresentable {
    public let player: AVPlayer
    
    public init(player: AVPlayer) {
        self.player = player
    }
    
    public func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }
    
    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

public enum OrientationManager {
    public static func enterLandscape() {}
    public static func enterPortrait() {}
    public static func toggleOrientation(isLandscape: Bool) {}
}
#endif

public struct CustomPlayerOverlayView: View {
    @ObservedObject public var playbackManager: PlaybackManager
    
    @State private var areControlsVisible: Bool = true
    @State private var hideControlsTimer: Timer?
    @State private var isScrubbing: Bool = false
    @State private var scrubTime: Double = 0
    @State private var isLandscape: Bool = true
    @State private var rippleSide: String? = nil
    
    public init(playbackManager: PlaybackManager) {
        self.playbackManager = playbackManager
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Direct AVPlayerLayer Video Surface
            NativePlayerView(player: playbackManager.player)
                .ignoresSafeArea()
            
            // Gesture Layer for tap-to-show and double-tap skips
            gesturesLayer
            
            // Live Subtitle Overlay
            if let cue = playbackManager.currentSubtitleCue, !cue.isEmpty {
                VStack {
                    Spacer()
                    Text(cue)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black, radius: 4)
                        .padding(.bottom, areControlsVisible ? 90 : 25)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: cue)
            }
            
            // Controls HUD
            if areControlsVisible {
                VStack {
                    topControlsBar
                    Spacer()
                    centerControlsBar
                    Spacer()
                    bottomControlsBar
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.75), Color.clear, Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .transition(.opacity)
            }
            
            // Auto Next Episode Prompt
            if playbackManager.showNextEpisodePrompt {
                nextEpisodePromptBanner
            }
        }
        .onAppear {
            #if os(iOS)
            OrientationManager.enterLandscape()
            isLandscape = true
            #endif
            scheduleControlsHide()
        }
        .onDisappear {
            #if os(iOS)
            OrientationManager.enterPortrait()
            #endif
        }
        #if os(iOS)
        .statusBarHidden(!areControlsVisible)
        #endif
    }
    
    // MARK: - Gestures Layer
    private var gesturesLayer: some View {
        HStack(spacing: 0) {
            // Left Half (Double tap to rewind 10s)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    playbackManager.skip(seconds: -10)
                    triggerRipple(side: "left")
                    resetControlsTimer()
                }
                .onTapGesture(count: 1) {
                    toggleControls()
                }
            
            // Right Half (Double tap to forward 10s)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    playbackManager.skip(seconds: 10)
                    triggerRipple(side: "right")
                    resetControlsTimer()
                }
                .onTapGesture(count: 1) {
                    toggleControls()
                }
        }
        .overlay(
            Group {
                if rippleSide == "left" {
                    HStack {
                        VStack(spacing: 4) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 28))
                            Text("-10s")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                        .padding(.leading, 32)
                        Spacer()
                    }
                } else if rippleSide == "right" {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 28))
                            Text("+10s")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                        .padding(.trailing, 32)
                    }
                }
            }
        )
    }
    
    // MARK: - Top Controls Bar
    private var topControlsBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                #if os(iOS)
                OrientationManager.enterPortrait()
                #endif
                playbackManager.dismissPlayer()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playbackManager.currentMedia?.title ?? "Playing Media")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let season = playbackManager.currentSeason, let episode = playbackManager.currentEpisode {
                    Text("S\(season.number) E\(episode.episodeNumber): \(episode.title)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(RezkaTheme.textSecondary)
                        .lineLimit(1)
                } else if let tr = playbackManager.currentTranslation {
                    Text(tr.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(RezkaTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Resolution Badge
            Text(playbackManager.currentQuality.rawValue)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(RezkaTheme.accentCyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RezkaTheme.accentCyan.opacity(0.2))
                .clipShape(Capsule())
                .fixedSize()
            
            // Orientation Toggle Button
            #if os(iOS)
            Button(action: {
                isLandscape.toggle()
                OrientationManager.toggleOrientation(isLandscape: !isLandscape)
            }) {
                Image(systemName: isLandscape ? "iphone.landscape" : "iphone")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            #endif
        }
    }
    
    // MARK: - Center Controls Bar
    private var centerControlsBar: some View {
        HStack(spacing: 44) {
            Button(action: {
                playbackManager.skip(seconds: -10)
                resetControlsTimer()
            }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Button(action: {
                playbackManager.togglePlayPause()
                resetControlsTimer()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 64, height: 64)
                    
                    if playbackManager.isBuffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: RezkaTheme.accentAmber))
                            .scaleEffect(1.3)
                    } else {
                        Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: playbackManager.isPlaying ? 0 : 2)
                    }
                }
            }
            
            Button(action: {
                playbackManager.skip(seconds: 10)
                resetControlsTimer()
            }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Bottom Controls Bar
    private var bottomControlsBar: some View {
        VStack(spacing: 8) {
            // Scrubber Bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background Track
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 4)
                        
                        // Buffer Progress
                        if playbackManager.duration > 0 {
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: max(0, min(geo.size.width * CGFloat(playbackManager.bufferedTime / playbackManager.duration), geo.size.width)), height: 4)
                        }
                        
                        // Playback Progress
                        let current = isScrubbing ? scrubTime : playbackManager.currentTime
                        let progress = playbackManager.duration > 0 ? (current / playbackManager.duration) : 0
                        Capsule()
                            .fill(RezkaTheme.accentAmber)
                            .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 4)
                        
                        // Thumb indicator
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.5), radius: 3)
                            .offset(x: max(0, min(geo.size.width * CGFloat(progress) - 6, geo.size.width - 12)))
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isScrubbing = true
                                resetControlsTimer()
                                let fraction = max(0, min(value.location.x / geo.size.width, 1.0))
                                scrubTime = fraction * playbackManager.duration
                            }
                            .onEnded { value in
                                isScrubbing = false
                                playbackManager.seek(to: scrubTime)
                                resetControlsTimer()
                            }
                    )
                }
                .frame(height: 12)
                
                // Timestamp row
                HStack {
                    Text(formatTime(isScrubbing ? scrubTime : playbackManager.currentTime))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(RezkaTheme.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("-\(formatTime(max(playbackManager.duration - (isScrubbing ? scrubTime : playbackManager.currentTime), 0)))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(RezkaTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            // Bottom Buttons (Horizontal scroll / flex row without text wrapping)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Audio / Voiceover Menu
                    if let detail = playbackManager.currentMediaDetail, !detail.translators.isEmpty {
                        Menu {
                            ForEach(detail.translators) { tr in
                                Button(action: {
                                    Task { await playbackManager.changeTranslation(to: tr) }
                                }) {
                                    HStack {
                                        Text(tr.title)
                                        if playbackManager.currentTranslation?.id == tr.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 12))
                                Text("Audio")
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        .fixedSize()
                    }
                    
                    // Video Quality Menu
                    if let bundle = playbackManager.currentStreamBundle {
                        Menu {
                            ForEach(bundle.streams) { stream in
                                Button(action: {
                                    playbackManager.changeQuality(to: stream.quality)
                                }) {
                                    HStack {
                                        Text(stream.quality.rawValue)
                                        if playbackManager.currentQuality == stream.quality {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 12))
                                Text(playbackManager.currentQuality.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        .fixedSize()
                    }
                    
                    // Subtitles Menu
                    if let bundle = playbackManager.currentStreamBundle, !bundle.subtitles.isEmpty {
                        Menu {
                            Button(action: {
                                Task { await playbackManager.selectSubtitleTrack(nil) }
                            }) {
                                HStack {
                                    Text("Off")
                                    if playbackManager.activeSubtitleTrack == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            ForEach(bundle.subtitles) { track in
                                Button(action: {
                                    Task { await playbackManager.selectSubtitleTrack(track) }
                                }) {
                                    HStack {
                                        Text(track.language)
                                        if playbackManager.activeSubtitleTrack?.id == track.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "captions.bubble.fill")
                                    .font(.system(size: 12))
                                Text("Subtitles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(playbackManager.activeSubtitleTrack != nil ? RezkaTheme.accentCyan : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        .fixedSize()
                    }
                    
                    // Playback Speed Menu
                    Menu {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                            Button(action: {
                                playbackManager.changePlaybackSpeed(to: Float(speed))
                            }) {
                                HStack {
                                    Text(String(format: "%.2fx", speed))
                                    if playbackManager.playbackRate == Float(speed) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(String(format: "%.2fx", playbackManager.playbackRate))
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .fixedSize()
                    
                    // Next Episode Button
                    if let _ = playbackManager.currentEpisode {
                        Button(action: {
                            playbackManager.playNextEpisode()
                        }) {
                            HStack(spacing: 4) {
                                Text("Next Ep")
                                    .font(.system(size: 12, weight: .bold))
                                    .lineLimit(1)
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RezkaTheme.accentAmber)
                            .clipShape(Capsule())
                        }
                        .fixedSize()
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - Next Episode Prompt Banner
    private var nextEpisodePromptBanner: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Episode Starting")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Playing in \(playbackManager.nextEpisodeCountdown)s")
                        .font(.system(size: 11))
                        .foregroundColor(RezkaTheme.accentAmber)
                }
                
                Spacer()
                
                Button(action: {
                    playbackManager.showNextEpisodePrompt = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                
                Button(action: {
                    playbackManager.playNextEpisode()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Play Now")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RezkaTheme.accentAmber)
                    .clipShape(Capsule())
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 14)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helpers
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.25)) {
            areControlsVisible.toggle()
        }
        if areControlsVisible {
            scheduleControlsHide()
        }
    }
    
    private func resetControlsTimer() {
        if !areControlsVisible {
            withAnimation(.easeInOut(duration: 0.25)) {
                areControlsVisible = true
            }
        }
        scheduleControlsHide()
    }
    
    private func scheduleControlsHide() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            Task { @MainActor in
                if playbackManager.isPlaying && !isScrubbing {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        areControlsVisible = false
                    }
                }
            }
        }
    }
    
    private func triggerRipple(side: String) {
        rippleSide = side
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if rippleSide == side {
                rippleSide = nil
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let hrs = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}

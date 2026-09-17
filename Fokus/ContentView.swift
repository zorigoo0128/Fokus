import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var timer = TimerModel()
    @StateObject private var videoManager = VideoManager()
    @State private var isDropTargeted = false
    @State private var showPresets = false

    private let presetDurations = [5, 15, 25, 45, 60]

    var body: some View {
        ZStack {
            // MARK: - Looped Background Video
            backgroundLayer

            // Dark vignette overlay for glass contrast and readability
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            // MARK: - Main Content Layout
            VStack(spacing: 0) {
                // Top Toolbar
                topBarView
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Spacer()

                // Center Timer & Progress Ring
                centerTimerView

                Spacer()

                // Bottom Controls Bar
                VStack(spacing: 12) {
                    bottomControlsView

                    if videoManager.currentVideoURL == nil {
                        Button {
                            videoManager.selectVideoOrDirectory()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "film.stack")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Select Looped Video or Folder (⌘O)")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .glassEffect(.clear)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.bottom, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Drag & Drop Indicator Overlay
            if isDropTargeted {
                dropOverlayView
            }
        }
        .frame(minWidth: 680, minHeight: 540)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Background Layer
    @ViewBuilder
    private var backgroundLayer: some View {
        if videoManager.currentVideoURL != nil {
            PlayerContainerView(player: videoManager.queuePlayer)
                .ignoresSafeArea()
        } else {
            AmbientAuroraView()
                .ignoresSafeArea()
        }
    }

    // MARK: - Top Bar
    private var topBarView: some View {
        HStack {
            // Invisible spacer for macOS traffic lights
            Spacer()
                .frame(width: 70)

            // Video / Directory Selector Pill
            videoSelectorPill

            Spacer()

            // Volume Control Slider
            GlassVolumeSlider(
                volume: $videoManager.volume,
                isMuted: $videoManager.isMuted
            )
        }
    }

    // MARK: - Video Selector Pill
    private var videoSelectorPill: some View {
        HStack(spacing: 8) {
            Button {
                videoManager.selectVideoOrDirectory()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: videoManager.activeDirectoryName != nil ? "folder.fill" : (videoManager.currentVideoURL != nil ? "film.fill" : "film.badge.plus"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Text(videoManager.activeDirectoryName ?? (videoManager.currentVideoURL != nil ? videoManager.currentVideoName : "Load Video or Folder (⌘O)"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 180, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
            .help("Choose a video file (.mp4, .mov, etc.) or a folder of videos (⌘O)")

            if videoManager.hasMultipleVideos {
                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.2))

                HStack(spacing: 4) {
                    Button {
                        videoManager.previousVideo()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Previous video")

                    Button {
                        videoManager.nextVideo()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Next video")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.clear)
    }

    // MARK: - Center Timer Display
    private var centerTimerView: some View {
        ZStack {
            // Glass backdrop card
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: 360, height: 360)
                .glassEffect(.clear)
            
            // Circular Progress Ring
            CircularProgressView(progress: timer.progress, size: 320, lineWidth: 10)

            // Center Text Information
            VStack(spacing: 12) {
                // Status Pill
                Text(timer.timerStateText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(timer.hasFinished ? Color.green : Color.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    )

                // Large Digital Time
                Text(timer.formattedTime)
                    .font(.system(size: 68, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .shadow(color: Color.white.opacity(0.25), radius: 10, x: 0, y: 0)

                // Preset Pills
                HStack(spacing: 8) {
                    ForEach(presetDurations, id: \.self) { minutes in
                        let isSelected = Int(timer.totalDuration / 60) == minutes
                        Button {
                            timer.setDuration(minutes: minutes)
                        } label: {
                            Text("\(minutes)m")
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(timer.isRunning)
                    }
                }
                .opacity(timer.isRunning ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: timer.isRunning)
            }
        }
    }

    // MARK: - Bottom Controls Bar
    private var bottomControlsView: some View {
        HStack(spacing: 24) {
            // Repeat Button
            Button {
                timer.toggleRepeat()
            } label: {
                Image(systemName: timer.isRepeatEnabled ? "repeat.1" : "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(GlassButtonStyle())
            .help(timer.isRepeatEnabled ? "Repeat: Enabled" : "Repeat: Disabled")

            // Play / Pause Button
            Button {
                timer.togglePlayPause()
            } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 68, height: 68)
            }
            .buttonStyle(GlassButtonStyle())
            .keyboardShortcut(.space, modifiers: [])
            .help(timer.isRunning ? "Pause (Space)" : "Start (Space)")

            // Stop / Reset Button
            Button {
                timer.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(GlassButtonStyle())
            .help("Reset Timer")
        }
    }

    // MARK: - Drop Indicator Overlay
    private var dropOverlayView: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.6),
                    style: StrokeStyle(lineWidth: 3, dash: [10, 8])
                )
                .padding(32)

            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                Text("Drop video file or folder here")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Drop Handling
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async {
                    self.videoManager.loadURL(url)
                }
            }
        }
        return true
    }
}

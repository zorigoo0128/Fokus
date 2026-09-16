import SwiftUI
import Combine
import AVFoundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Video Manager
@MainActor
final class VideoManager: ObservableObject {
    @Published var currentVideoURL: URL?
    @Published var playlist: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var volume: Double = 0.5 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "fokus_volume")
            updatePlayerVolume()
        }
    }
    @Published var isMuted: Bool = false {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "fokus_is_muted")
            updatePlayerVolume()
        }
    }
    @Published var activeDirectoryName: String?
    @Published var isHoveringControls: Bool = false

    private(set) var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var securityScopedURL: URL?

    init() {
        if UserDefaults.standard.object(forKey: "fokus_volume") != nil {
            self.volume = UserDefaults.standard.double(forKey: "fokus_volume")
        }
        self.isMuted = UserDefaults.standard.bool(forKey: "fokus_is_muted")
        restoreSavedVideo()
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    var currentVideoName: String {
        guard let url = currentVideoURL else { return "No Video Loaded" }
        return url.deletingPathExtension().lastPathComponent
    }

    var hasMultipleVideos: Bool {
        return playlist.count > 1
    }

    func selectVideoOrDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Select Looped Video or Folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .folder,
            .directory,
            UTType.movie,
            UTType.video,
            UTType.quickTimeMovie,
            UTType.mpeg4Movie,
            UTType(filenameExtension: "mp4") ?? .movie,
            UTType(filenameExtension: "mov") ?? .movie,
            UTType(filenameExtension: "m4v") ?? .movie,
            UTType(filenameExtension: "webm") ?? .movie,
            UTType(filenameExtension: "avi") ?? .movie
        ]

        if panel.runModal() == .OK, let selectedURL = panel.url {
            loadURL(selectedURL)
        }
    }

    func loadURL(_ url: URL) {
        // Handle security scoping
        securityScopedURL?.stopAccessingSecurityScopedResource()
        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
        }

        saveBookmark(for: url)

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            loadFromDirectory(url)
        } else {
            loadSingleFile(url)
        }
    }

    func nextVideo() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        playItemAtCurrentIndex()
    }

    func previousVideo() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        playItemAtCurrentIndex()
    }

    func toggleMute() {
        isMuted.toggle()
    }

    private func loadFromDirectory(_ dirURL: URL) {
        activeDirectoryName = dirURL.lastPathComponent
        let supportedExts = Set(["mp4", "mov", "m4v", "webm", "avi"])

        var foundVideos: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if supportedExts.contains(fileURL.pathExtension.lowercased()) {
                    foundVideos.append(fileURL)
                }
            }
        }

        // Sort alphabetically
        foundVideos.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        if !foundVideos.isEmpty {
            playlist = foundVideos
            currentIndex = 0
            playItemAtCurrentIndex()
        }
    }

    private func loadSingleFile(_ fileURL: URL) {
        activeDirectoryName = nil
        playlist = [fileURL]
        currentIndex = 0
        playItemAtCurrentIndex()
    }

    private func playItemAtCurrentIndex() {
        guard playlist.indices.contains(currentIndex) else { return }
        let url = playlist[currentIndex]
        currentVideoURL = url
        setupPlayer(with: url)
    }

    private func setupPlayer(with url: URL) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        // For AVPlayerLooper, do not add templateItem to queuePlayer before looper creation
        let player = AVQueuePlayer()
        player.actionAtItemEnd = .none

        looper = AVPlayerLooper(player: player, templateItem: playerItem)
        queuePlayer = player

        updatePlayerVolume()
        player.play()
    }

    private func updatePlayerVolume() {
        let effVolume = isMuted ? 0.0 : Float(volume)
        queuePlayer?.volume = effVolume
    }

    private func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: "fokus_video_bookmark")
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    private func restoreSavedVideo() {
        guard let data = UserDefaults.standard.data(forKey: "fokus_video_bookmark") else { return }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(for: url)
            }
            loadURL(url)
        } catch {
            print("Failed to restore saved video bookmark: \(error)")
        }
    }
}

// MARK: - AppKit Player View Representable
struct PlayerContainerView: NSViewRepresentable {
    let player: AVQueuePlayer?

    func makeNSView(context: Context) -> NSPlayerViewWrapper {
        let view = NSPlayerViewWrapper()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: NSPlayerViewWrapper, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

final class NSPlayerViewWrapper: NSView {
    override func makeBackingLayer() -> CALayer {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = NSColor.black.cgColor
        return layer
    }

    private var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    var player: AVQueuePlayer? {
        didSet {
            playerLayer.player = player
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
}

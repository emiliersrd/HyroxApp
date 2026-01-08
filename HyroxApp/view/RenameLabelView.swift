// swift
import SwiftUI
import PhotosUI
import AVKit
import Vision
import AVFoundation
import CoreMedia

struct RenameLabelView: View {
    @StateObject private var viewModel = RenameViewModel()
    @State private var newName: String = ""

    // Video selection + playback/analysis state
    @State private var videoURL: URL?
    @State private var showPicker = false
    private let analyzer = SkeletonAnalyzer()
    @State private var player: AVPlayer?
    @State private var showPlayer = false
    @State private var timedObservations: [TimedObservation] = []
    @State private var currentTime: CMTime = .zero
    @State private var timeObserverToken: Any?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var videoSize: CGSize = .zero

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Video selection
                HStack(spacing: 12) {
                    Button("Select video") { showPicker = true }
                        .buttonStyle(.borderedProminent)

                    if let url = videoURL {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No video selected")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                if isAnalyzing {
                    ProgressView("Analyzing...")
                        .padding(.top, 6)
                }
                if let msg = errorMessage {
                    Text(msg).foregroundColor(.red)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        guard let url = videoURL else { return }
                        analyzeAndPlay(url: url)
                    }) {
                        ZStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 10))
                                .offset(x: 12, y: -12)
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Analyze and play")
                    }
                    .disabled(videoURL == nil || isAnalyzing)
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        guard let url = videoURL else { return }
                        play(url: url)
                    }) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .accessibilityLabel("Play")
                    }
                    .disabled(videoURL == nil)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                // Placeholder area (we now present full screen player)
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 300)
                    .overlay(Text("Ready to play"))
                    .padding(.top, 8)

                Spacer()
            }
            .padding(.vertical)
            .onAppear { newName = viewModel.currentName ?? "" }
            .onDisappear { stopPlayback() }
            .sheet(isPresented: $showPicker) {
                VideoPicker(selectedURL: $videoURL)
            }
        }
        .navigationTitle("Rename")
        // Full screen player presented when showPlayer is true
        .fullScreenCover(isPresented: $showPlayer, onDismiss: { stopPlayback() }) {
            FullscreenPlayerView(
                player: $player,
                currentTime: $currentTime,
                observations: timedObservations.map { (time: $0.time, observation: $0.observation) },
                videoSize: videoSize,
                onDismiss: { showPlayer = false }
            )
        }
    }

    // MARK: - Analysis / Playback
    private func analyzeAndPlay(url: URL) {
        isAnalyzing = true
        errorMessage = nil
        timedObservations = []
        videoSize = .zero

        // compute video natural size (preferredTransform aware) when possible
        let asset = AVAsset(url: url)
        if #available(iOS 16.0, *) {
            Task {
                do {
                    let tracks: [AVAssetTrack] = try await asset.load(.tracks)
                    if let track = tracks.first {
                        let natural: CGSize = try await track.load(.naturalSize)
                        let t: CGAffineTransform = try await track.load(.preferredTransform)
                        let isPortrait = abs(t.b) == 1.0 || abs(t.c) == 1.0
                        let computedSize = isPortrait ? CGSize(width: natural.height, height: natural.width) : natural
                        await MainActor.run { self.videoSize = computedSize }
                    }
                } catch {
                    // ignore and leave videoSize as .zero; overlay will fallback
                }
            }
        } else {
            // fallback for older OS: use synchronous access
            let tracks = asset.tracks(withMediaType: .video)
            if let track = tracks.first {
                let natural = track.naturalSize
                let t = track.preferredTransform
                let isPortrait = abs(t.b) == 1.0 || abs(t.c) == 1.0
                let computedSize = isPortrait ? CGSize(width: natural.height, height: natural.width) : natural
                videoSize = computedSize
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            analyzer.analyzeAsset(url: url) { obs in
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.timedObservations = obs
                    self.play(url: url)
                }
            }
        }
    }

    private func play(url: URL) {
        stopPlayback()
        player = AVPlayer(url: url)
        player?.seek(to: .zero)
        // do not add time observer here; fullscreen view will manage it
        showPlayer = true
    }

    private func stopPlayback() {
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        showPlayer = false
        currentTime = .zero
    }

    // MARK: - Fullscreen Player View
    struct FullscreenPlayerView: View {
        @Binding var player: AVPlayer?
        @Binding var currentTime: CMTime
        let observations: [(time: CMTime, observation: VNHumanBodyPoseObservation)]
        let videoSize: CGSize
        let onDismiss: () -> Void

        @Environment(\.presentationMode) var presentation
        @State private var timeObserverToken: Any?

        var body: some View {
            ZStack(alignment: .topTrailing) {
                GeometryReader { geo in
                    ZStack {
                        if let p = player {
                            VideoPlayer(player: p)
                                .ignoresSafeArea()
                                .onAppear { addTimeObserver() }
                                .onDisappear { removeTimeObserver() }

                            SkeletonOverlayView(
                                observations: observations,
                                currentTime: currentTime,
                                videoSize: videoSize
                            )
                            .allowsHitTesting(false)
                            .ignoresSafeArea()
                        } else {
                            Color.black.ignoresSafeArea()
                        }
                    }
                }

                Button(action: {
                    removeTimeObserver()
                    player?.pause()
                    onDismiss()
                }) {
                    Text("Fermer")
                        .padding(10)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                }
            }
        }

        private func addTimeObserver() {
            guard timeObserverToken == nil, let p = player else { return }
            let interval = CMTime(value: 1, timescale: 60)
            timeObserverToken = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                self.currentTime = time
            }
        }

        private func removeTimeObserver() {
            if let token = timeObserverToken, let p = player {
                p.removeTimeObserver(token)
                timeObserverToken = nil
            }
        }
    }
}

// UIKit wrapper for PHPicker to pick a video and copy it to a local URL the app can read
struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.videos])
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        init(_ parent: VideoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let item = results.first else { return }
            let provider = item.itemProvider
            let typeId = "public.movie"
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, error in
                    guard let url = url else { return }
                    // Copy file to app tmp directory to ensure access
                    let fileName = UUID().uuidString + "." + (url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                    let dst = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: dst)
                    do {
                        try FileManager.default.copyItem(at: url, to: dst)
                        DispatchQueue.main.async {
                            self.parent.selectedURL = dst
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.parent.selectedURL = nil
                        }
                    }
                }
            }
        }
    }
}

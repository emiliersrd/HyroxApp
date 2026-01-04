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
                    Button("Analyze & Play") {
                        guard let url = videoURL else { return }
                        analyzeAndPlay(url: url)
                    }
                    .disabled(videoURL == nil || isAnalyzing)
                    .buttonStyle(.borderedProminent)

                    Button("Play (no analysis)") {
                        guard let url = videoURL else { return }
                        play(url: url)
                    }
                    .disabled(videoURL == nil)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                // Player + overlay
                if showPlayer, let player = player {
                    ZStack {
                        VideoPlayer(player: player)
                            .frame(height: 300)
                            .onDisappear { stopPlayback() }

                        if !timedObservations.isEmpty {
                            SkeletonOverlayView(
                                observations: timedObservations.map { (time: $0.time, observation: $0.observation) },
                                currentTime: currentTime
                            )
                            .allowsHitTesting(false)
                            .frame(height: 300)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 300)
                        .overlay(Text("Ready to play"))
                        .padding(.top, 8)
                }

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
    }

    // MARK: - Analysis / Playback
    private func analyzeAndPlay(url: URL) {
        isAnalyzing = true
        errorMessage = nil
        timedObservations = []
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
        player?.play()
        showPlayer = true

        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time
        }
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

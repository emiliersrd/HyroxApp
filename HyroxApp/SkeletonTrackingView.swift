import SwiftUI
import AVKit
@preconcurrency import Vision
import AVFoundation

struct SkeletonTrackingView: View {
    @StateObject private var recorder = VideoRecorder()
    private let analyzer = SkeletonAnalyzer()

    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    // store timed observations (time + observation)
    @State private var timedObservations: [(CMTime, VNHumanBodyPoseObservation)] = []
    @State private var videoSize: CGSize = .zero

    @State private var player: AVPlayer?
    @State private var showPlayer = false
    @State private var currentTime: CMTime = .zero
    @State private var timeObserverToken: Any?
    @State private var showFullScreenLive = false
    @State private var saveResultMessage: String?
    @State private var showSaveAlert = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Skeleton tracking")
                .font(.largeTitle)
                .bold()

            if let layer = previewLayer {
                ZStack {
                    CameraPreviewView(previewLayer: layer)
                        .frame(height: 300)
                        .cornerRadius(12)

                    // overlay uses timedObservations + currentTime and knows videoSize
                    SkeletonOverlayView(
                        observations: timedObservations.map { ($0.0, $0.1) },
                        currentTime: currentTime,
                        videoSize: videoSize
                    )
                    .frame(height: 300)
                }
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .frame(height: 300)
                    .cornerRadius(12)
                    .overlay(
                        Text("Camera preview + overlay")
                            .foregroundColor(.white)
                    )
            }

            HStack(spacing: 16) {
                // Start camera
                Button(action: startSession) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                }

                // Record / stop
                if recorder.isRecording {
                    Button(action: recorder.stopRecording) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                } else {
                    Button(action: recorder.startRecording) {
                        Image(systemName: "record.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }

                // If we have a recording, allow analyze/play/save
                if let url = recorder.recordedURL {
                    Button(action: { analyze(url: url) }) {
                        ZStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 26))
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 10))
                                .offset(x: 12, y: -12)
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Analyze and play")
                    }

                    Button(action: { play(url: url) }) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }

                    Button(action: {
                        recorder.saveToPhotoLibrary { success, error in
                            if success {
                                saveResultMessage = "Saved to Photos"
                            } else if let e = error {
                                saveResultMessage = "Save failed: \(e.localizedDescription)"
                            } else {
                                saveResultMessage = "Save failed or permission denied"
                            }
                            showSaveAlert = true
                        }
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                    }
                }
            }

            if showPlayer, let player = player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .onDisappear { player.pause(); removeTimeObserver() }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Skeleton tracking")
        .onAppear {
            recorder.startSession()
            self.previewLayer = recorder.makePreviewLayer()
        }
        .onDisappear {
            recorder.stopSession()
            removeTimeObserver()
        }
        // Present fullscreen live preview when requested
        .fullScreenCover(isPresented: $showFullScreenLive) {
            FullscreenLiveView(previewLayer: previewLayer, observations: timedObservations.map { (time: $0.0, observation: $0.1) }, videoSize: videoSize) {
                showFullScreenLive = false
            }
        }
        // Present the analyzed recording in full screen with overlay
        .fullScreenCover(isPresented: $showPlayer) {
            FullscreenPlayerView(player: $player, currentTime: $currentTime, observations: timedObservations, videoSize: videoSize, isPresented: $showPlayer)
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text("Save recording"), message: Text(saveResultMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func startSession() {
        recorder.startSession()
        self.previewLayer = recorder.makePreviewLayer()
    }

    private func analyze(url: URL) {
        // Clear previous data
        timedObservations = []
        videoSize = .zero
        currentTime = .zero

        // compute video size (respecting preferredTransform)
        let asset = AVAsset(url: url)

        // Use async loading APIs to avoid deprecated synchronous access
        Task.detached(priority: .userInitiated) {
            do {
                // load tracks asynchronously
                let tracks: [AVAssetTrack] = try await asset.load(.tracks)
                if let track = tracks.first {
                    // load size and transform asynchronously
                    let natural: CGSize = try await track.load(.naturalSize)
                    let t: CGAffineTransform = try await track.load(.preferredTransform)
                    let isPortrait = abs(t.b) == 1.0 || abs(t.c) == 1.0
                    let computedSize = isPortrait ? CGSize(width: natural.height, height: natural.width) : natural

                    DispatchQueue.main.async {
                        self.videoSize = computedSize
                    }
                }

                // Analyze using the faster asset analyzer (samples at sampleFPS)
                // fastAnalyzeAssetUsingReader is main-actor isolated; call it on MainActor
                await MainActor.run {
                    fastAnalyzeAssetUsingReader(url: url, sampleFPS: 15.0, targetSize: CGSize(width: 360, height: 360), maxConcurrentRequests: 2) { timed in
                        // timed is [TimedObservation]
                        DispatchQueue.main.async {
                            let mapped: [(CMTime, VNHumanBodyPoseObservation)] = timed.map { ($0.time, $0.observation) }
                            self.timedObservations = mapped
                            // ensure currentTime stays 0 until user plays (we auto-play)
                            self.currentTime = .zero
                            // Auto-play the analyzed recording for review
                            self.play(url: url)
                        }
                    }
                }
            } catch {
                print("Failed to load asset properties: \(error)")
                // fallback: try to run analysis without size; run analyzer anyway (on MainActor)
                await MainActor.run {
                    fastAnalyzeAssetUsingReader(url: url, sampleFPS: 15.0, targetSize: CGSize(width: 360, height: 360), maxConcurrentRequests: 2) { timed in
                        DispatchQueue.main.async {
                            let mapped: [(CMTime, VNHumanBodyPoseObservation)] = timed.map { ($0.time, $0.observation) }
                            self.timedObservations = mapped
                            self.currentTime = .zero
                            self.play(url: url)
                        }
                    }
                }
            }
        }
    }

    private func play(url: URL) {
        // remove existing observer
        removeTimeObserver()

        player = AVPlayer(url: url)
        // present the video in fullscreen; the FullscreenPlayerView will add a time observer
        showPlayer = true
        player?.play()
    }
}

// Fullscreen player view for analyzed recordings
struct FullscreenPlayerView: View {
    @Binding var player: AVPlayer?
    @Binding var currentTime: CMTime
    let observations: [(CMTime, VNHumanBodyPoseObservation)]
    let videoSize: CGSize
    @Binding var isPresented: Bool

    @State private var timeObserverToken: Any?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let p = player {
                VideoPlayer(player: p)
                    .ignoresSafeArea()
            }

            SkeletonOverlayView(observations: observations.map { ($0.0, $0.1) }, currentTime: currentTime, videoSize: videoSize)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // cleanup observer then dismiss
                        if let token = timeObserverToken, let p = player {
                            p.removeTimeObserver(token)
                            timeObserverToken = nil
                        }
                        player?.pause()
                        player = nil
                        isPresented = false
                        dismiss()
                    }) {
                        Text("Fermer")
                            .padding(10)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            if timeObserverToken == nil, let p = player {
                let interval = CMTimeMake(value: 1, timescale: 30)
                timeObserverToken = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { t in
                    self.currentTime = t
                }
            }
        }
        .onDisappear {
            if let token = timeObserverToken, let p = player {
                p.removeTimeObserver(token)
                timeObserverToken = nil
            }
        }
    }
}

struct SkeletonTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        SkeletonTrackingView()
    }
}

// Minimal fullscreen live preview used by SkeletonTrackingView
struct FullscreenLiveView: View {
    let previewLayer: AVCaptureVideoPreviewLayer?
    let observations: [(time: CMTime, observation: VNHumanBodyPoseObservation)]
    let videoSize: CGSize
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geo in
                ZStack {
                    if let layer = previewLayer {
                        CameraPreviewView(previewLayer: layer)
                            .ignoresSafeArea()

                        SkeletonOverlayView(observations: observations, currentTime: .zero, videoSize: videoSize)
                            .allowsHitTesting(false)
                            .ignoresSafeArea()
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            }

            Button(action: { onDismiss() }) {
                Text("Fermer")
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }
        }
    }
}

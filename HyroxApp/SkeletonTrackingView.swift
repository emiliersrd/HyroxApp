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

            HStack(spacing: 20) {
                Button(action: startSession) {
                    Text("Start camera")
                }

                if recorder.isRecording {
                    Button(action: recorder.stopRecording) {
                        Text("Stop recording")
                            .foregroundColor(.red)
                    }
                } else {
                    Button(action: recorder.startRecording) {
                        Text("Start recording")
                            .foregroundColor(.green)
                    }
                }

                if let url = recorder.recordedURL {
                    Button(action: { analyze(url: url) }) {
                        Text("Analyze last recording")
                    }

                    Button(action: { play(url: url) }) {
                        Text("Play last recording")
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
                // call the existing analyzer helper; it's main-actor isolated so call it on MainActor
                await MainActor.run {
                    fastAnalyzeAssetUsingReader(url: url, sampleFPS: 15.0, targetSize: CGSize(width: 360, height: 360), maxConcurrentRequests: 2) { timed in
                        // timed is [TimedObservation] (TimeObservation.observation is main-actor-isolated)
                        Task { @MainActor in
                            let mapped: [(CMTime, VNHumanBodyPoseObservation)] = timed.map { ($0.time, $0.observation) }
                            self.timedObservations = mapped
                            // ensure currentTime stays 0 until user plays
                            self.currentTime = .zero
                        }
                    }
                }
            } catch {
                print("Failed to load asset properties: \(error)")
                // fallback: try to run analysis without size; run analyzer anyway
                await MainActor.run {
                    fastAnalyzeAssetUsingReader(url: url, sampleFPS: 15.0, targetSize: CGSize(width: 360, height: 360), maxConcurrentRequests: 2) { timed in
                        Task { @MainActor in
                            let mapped: [(CMTime, VNHumanBodyPoseObservation)] = timed.map { ($0.time, $0.observation) }
                            self.timedObservations = mapped
                            self.currentTime = .zero
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
        showPlayer = true
        player?.play()

        // add periodic time observer to sync overlay
        let interval = CMTimeMake(value: 1, timescale: 30) // ~30fps update
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time
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

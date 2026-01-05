// swift
import SwiftUI
import AVKit
import Vision
import AVFoundation
import CoreMedia

struct SkeletonTrackingView: View {
    @StateObject private var recorder = VideoRecorder()
    private let analyzer = SkeletonAnalyzer()

    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var observations: [VNHumanBodyPoseObservation] = []          // live preview observations
    // keep project TimedObservation type so analyzer assignment compiles
    @State private var timedObservations: [TimedObservation] = []              // analyzed observations with timestamps

    @State private var player: AVPlayer?
    @State private var showPlayer = false
    @State private var currentTime: CMTime = .zero
    @State private var timeObserverToken: Any?

    @State private var isAnalyzing: Bool = false
    @State private var analysisError: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                Text("Skeleton tracking")
                    .font(.largeTitle)
                    .bold()

                if let layer = previewLayer {
                    ZStack {
                        CameraPreviewView(previewLayer: layer)
                            .frame(height: 300)
                            .cornerRadius(12)

                        // disable hit testing on the overlay so touches pass through
                        overlayPointsLive()
                            .frame(height: 300)
                            .allowsHitTesting(false)

                        if isAnalyzing {
                            VStack {
                                ProgressView("Analyzing...")
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(8)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(
                            Text("Camera preview + overlay")
                                .foregroundColor(.white)
                        )
                        .padding(.horizontal)
                }

                // adaptive layout so buttons wrap instead of truncating
                let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    Button(action: startSession) {
                        Text("Start camera")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if recorder.isRecording {
                        Button(action: { stopRecordingAndAnalyze() }) {
                            Text("Stop recording")
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isAnalyzing)
                    } else {
                        Button(action: { recorder.startRecording() }) {
                            Text("Start recording")
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isAnalyzing)
                    }

                    // Analyze: runs analysis, stores timedObservations and immediately plays the last video with overlay
                    if let url = recorder.recordedURL {
                        Button(action: { analyzeAndPlay(url: url) }) {
                            Text("Analyze last recording")
                                .font(.headline)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isAnalyzing)

                        // Play: just plays the last recording (no forced analysis)
                        Button(action: { play(url: url, showOverlay: false) }) {
                            Text("Play last recording")
                                .font(.headline)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                if let error = analysisError {
                    Text("Analysis error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                if showPlayer, let player = player {
                    ZStack {
                        VideoPlayer(player: player)
                            .frame(height: 200)
                            .onDisappear { stopPlayback() }

                        // convert project's TimedObservation -> named-tuple expected by overlay
                        if !timedObservations.isEmpty {
                            SkeletonOverlayView(
                                observations: timedObservations.map { (time: $0.time, observation: $0.observation) },
                                currentTime: currentTime
                            )
                            .allowsHitTesting(false)
                            .frame(height: 200)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Skeleton tracking")
        .onAppear {
            recorder.startSession()
            self.previewLayer = recorder.makePreviewLayer()
        }
        .onDisappear {
            recorder.stopSession()
            stopPlayback()
        }
    }

    @ViewBuilder
    private func overlayPointsLive() -> some View {
        GeometryReader { geo in
            ZStack {
                ForEach(observations.indices, id: \.self) { idx in
                    if let point = try? observations[idx].recognizedPoint(.neck),
                       point.confidence > 0.1 {
                        let x = CGFloat(point.x) * geo.size.width
                        let y = (1 - CGFloat(point.y)) * geo.size.height
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 12, height: 12)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }

    private func startSession() {
        recorder.startSession()
        self.previewLayer = recorder.makePreviewLayer()
    }

    // Stop recording and automatically analyze the produced file (robust to recorder API variations).
    private func stopRecordingAndAnalyze() {
        analysisError = nil
        isAnalyzing = true
        timedObservations = []

        // Call stopRecording if available (original code used recorder.stopRecording()).
        recorder.stopRecording()

        // Wait for recorder.recordedURL to become available, up to a timeout.
        DispatchQueue.global(qos: .userInitiated).async {
            let timeout: TimeInterval = 8.0
            let checkInterval: TimeInterval = 0.12
            var waited: TimeInterval = 0
            while waited < timeout {
                if let url = recorder.recordedURL {
                    DispatchQueue.main.async {
                        analyzeAndPlay(url: url)
                    }
                    return
                }
                Thread.sleep(forTimeInterval: checkInterval)
                waited += checkInterval
            }

            // If recordedURL didn't appear, try to fail gracefully
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.analysisError = "Recorded file not available after stopping recording."
            }
        }
    }

    // analyze and then play with overlay
    private func analyzeAndPlay(url: URL) {
        analysisError = nil
        isAnalyzing = true
        timedObservations = []

        DispatchQueue.global(qos: .userInitiated).async {
            analyzer.analyzeAsset(url: url) { timedObs in
                DispatchQueue.main.async {
                    self.timedObservations = timedObs
                    self.isAnalyzing = false
                    self.analysisError = nil
                    // after analysis, play with overlay enabled
                    self.play(url: url, showOverlay: true)
                }
            }
        }
    }

    // play; if showOverlay is true the overlay will be shown when timedObservations exist
    private func play(url: URL, showOverlay: Bool) {
        stopPlayback() // ensure clean state
        player = AVPlayer(url: url)
        player?.seek(to: .zero)
        player?.play()
        showPlayer = true

        // use a tighter update interval for smoother overlay sync
        let interval = CMTime(seconds: 1.0/60.0, preferredTimescale: 600)
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
        // keep timedObservations (they can be reused) — clear if you prefer
    }
}

struct SkeletonTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        SkeletonTrackingView()
    }
}

// swift
import SwiftUI
import AVKit
import Vision

struct SkeletonTrackingView: View {
    @StateObject private var recorder = VideoRecorder()
    private let analyzer = SkeletonAnalyzer()

    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var observations: [VNHumanBodyPoseObservation] = []
    @State private var player: AVPlayer?
    @State private var showPlayer = false

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

                    overlayPoints()
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

            HStack(spacing: 12) {
                Button(action: startSession) {
                    Text("Start camera")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .layoutPriority(1)
                        .padding(.vertical, 10)
                        .frame(minWidth: 0, maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if recorder.isRecording {
                    Button(action: recorder.stopRecording) {
                        Text("Stop recording")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundColor(.red)
                            .layoutPriority(1)
                            .padding(.vertical, 10)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: recorder.startRecording) {
                        Text("Start recording")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundColor(.green)
                            .layoutPriority(1)
                            .padding(.vertical, 10)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let url = recorder.recordedURL {
                    Button(action: { analyze(url: url) }) {
                        Text("Analyze last recording")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .layoutPriority(1)
                            .padding(.vertical, 10)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { play(url: url) }) {
                        Text("Play last recording")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .layoutPriority(1)
                            .padding(.vertical, 10)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)

            if showPlayer, let player = player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .onDisappear { player.pause() }
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
        }
    }

    @ViewBuilder
    private func overlayPoints() -> some View {
        GeometryReader { geo in
            ZStack {
                ForEach(observations.indices, id: \.self) { idx in
                    if let point = try? observations[idx].recognizedPoint(.neck) {
                        if point.confidence > 0.1 {
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
    }

    private func startSession() {
        recorder.startSession()
        self.previewLayer = recorder.makePreviewLayer()
    }

    private func analyze(url: URL) {
        // Analyze in background
        observations = []
        DispatchQueue.global(qos: .userInitiated).async {
            analyzer.analyzeAsset(url: url) { obs in
                DispatchQueue.main.async {
                    self.observations = obs
                }
            }
        }
    }

    private func play(url: URL) {
        player = AVPlayer(url: url)
        player?.play()
        showPlayer = true
    }
}

struct SkeletonTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        SkeletonTrackingView()
    }
}

import SwiftUI
import AVKit
import Vision
import CoreMedia
import CoreGraphics
import AVFoundation
#if os(macOS)
import AppKit
#endif

struct CompareVideosView: View {
    let coachURL: URL?

    @State private var leftURL: URL?
    @State private var rightURL: URL?
    @State private var showLeftPicker = false
    @State private var showRightPicker = false

    @StateObject private var viewModel = CompareViewModel()

    init(coachURL: URL? = nil) {
        self.coachURL = coachURL
        _leftURL = State(initialValue: coachURL)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                HStack {
                    Text("Compare Videos")
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 6)

                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Button("Select Left Video") { showLeftPicker = true }
                            .buttonStyle(.borderedProminent)
                        Text(leftURL?.lastPathComponent ?? "No video selected")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    VStack(alignment: .leading) {
                        Button("Select Right Video") { showRightPicker = true }
                            .buttonStyle(.borderedProminent)
                        Text(rightURL?.lastPathComponent ?? "No video selected")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                if viewModel.isAnalyzing {
                    ProgressView("Analyzing...")
                        .padding(.top, 6)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        guard let l = leftURL, let r = rightURL else { return }
                        viewModel.analyzeBothAndPlay(left: l, right: r)
                    }) {
                        ZStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 10))
                                .offset(x: 14, y: -14)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .disabled(leftURL == nil || rightURL == nil || viewModel.isAnalyzing)
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        guard let l = leftURL, let r = rightURL else { return }
                        viewModel.playBoth(left: l, right: r)
                    }) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                    .disabled(leftURL == nil || rightURL == nil)
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: {
                        guard let l = leftURL, let r = rightURL else { return }
                        viewModel.exportComparison(leftURL: l, rightURL: r)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                    }
                    .disabled(leftURL == nil || rightURL == nil)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                HStack(spacing: 8) {
                    inlinePlayer(player: viewModel.leftPlayer, observations: viewModel.leftObservations, videoSize: viewModel.leftVideoSize)
                    inlinePlayer(player: viewModel.rightPlayer, observations: viewModel.rightObservations, videoSize: viewModel.rightVideoSize)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                let leftPoints = convertToTimedPoints(viewModel.leftObservations)
                let rightPoints = convertToTimedPoints(viewModel.rightObservations)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Combined Skeleton")
                        .font(.headline)
                        .padding(.horizontal)
                    CombinedSkeletonOverlayView(left: leftPoints, right: rightPoints, currentTime: viewModel.currentTime)
                        .frame(height: 160)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Comparison Preview")
                        .font(.headline)
                        .padding(.horizontal)
                    if let player = viewModel.comparisonPlayer {
                        VideoPlayer(player: player)
                            .id(viewModel.comparisonURL?.absoluteString ?? UUID().uuidString)
                            .frame(height: 180)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .onAppear { player.play() }
                    } else {
                        Text("Generated skeleton overlay will appear here after export.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 36) }
        #endif
        .sheet(isPresented: $showLeftPicker) {
            VideoPicker(selectedURL: $leftURL)
        }
        .sheet(isPresented: $showRightPicker) {
            VideoPicker(selectedURL: $rightURL)
        }
        .onDisappear { viewModel.stopPlayback() }
        .fullScreenCover(isPresented: $viewModel.showFullscreenCompare, onDismiss: { viewModel.stopPlayback() }) {
            FullscreenCompareView(leftPlayer: $viewModel.leftPlayer,
                                  rightPlayer: $viewModel.rightPlayer,
                                  leftObservations: viewModel.leftObservations,
                                  rightObservations: viewModel.rightObservations,
                                  leftVideoSize: viewModel.leftVideoSize,
                                  rightVideoSize: viewModel.rightVideoSize,
                                  currentTime: $viewModel.currentTime,
                                  isPresented: $viewModel.showFullscreenCompare)
        }
    }

    private func inlinePlayer(player: AVPlayer?, observations: [TimedObservation], videoSize: CGSize) -> some View {
        ZStack {
            if let p = player {
                VideoPlayer(player: p)
                    .frame(minHeight: 200)
                    .cornerRadius(8)
                    .overlay(
                        SkeletonOverlayView(observations: observations.map { (time: $0.time, observation: $0.observation) }, currentTime: viewModel.currentTime, videoSize: videoSize)
                            .allowsHitTesting(false)
                    )
            } else {
                Rectangle().fill(Color.black.opacity(0.85)).frame(minHeight: 200).overlay(Text("Ready to play").foregroundColor(.white))
            }
        }
    }

    private func convertToTimedPoints(_ timedObs: [TimedObservation]) -> [TimedPoints] {
        let jointOrder: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]

        return timedObs.compactMap { t in
            let pts: [CGPoint] = jointOrder.map { name in
                if let p = try? t.observation.recognizedPoint(name), p.confidence > 0.1 {
                    return CGPoint(x: CGFloat(p.x), y: CGFloat(1.0 - p.y))
                } else {
                    return CGPoint(x: 0.5, y: 0.5)
                }
            }
            return TimedPoints(time: t.time, points: pts)
        }
    }
}

// Fullscreen stacked compare view
struct FullscreenCompareView: View {
    @Binding var leftPlayer: AVPlayer?
    @Binding var rightPlayer: AVPlayer?
    var leftObservations: [TimedObservation]
    var rightObservations: [TimedObservation]
    var leftVideoSize: CGSize
    var rightVideoSize: CGSize
    @Binding var currentTime: CMTime
    @Binding var isPresented: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying: Bool = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                VStack(spacing: 0) {
                    playerBlock(player: leftPlayer, observations: leftObservations, videoSize: leftVideoSize)
                        .frame(width: geo.size.width, height: geo.size.height / 2)
                    Divider().background(Color.white)
                    playerBlock(player: rightPlayer, observations: rightObservations, videoSize: rightVideoSize)
                        .frame(width: geo.size.width, height: geo.size.height / 2)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: togglePlay) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
            }
        }
        .onDisappear { leftPlayer?.pause(); rightPlayer?.pause() }
    }

    private func playerBlock(player: AVPlayer?, observations: [TimedObservation], videoSize: CGSize) -> some View {
        ZStack {
            if let p = player {
                VideoPlayer(player: p)
                    .ignoresSafeArea()
                    .overlay(SkeletonOverlayView(observations: observations.map { (time: $0.time, observation: $0.observation) }, currentTime: currentTime, videoSize: videoSize).allowsHitTesting(false))
            } else {
                Color.black
            }
        }
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying { leftPlayer?.play(); rightPlayer?.play() } else { leftPlayer?.pause(); rightPlayer?.pause() }
    }

    private func close() {
        leftPlayer?.pause(); rightPlayer?.pause(); leftPlayer = nil; rightPlayer = nil; isPresented = false; dismiss()
    }
}

#if os(macOS)
struct VideoPicker: View {
    @Binding var selectedURL: URL?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack {
            Text("Select a video file")
            Button("Open…") { openPanel() }
            Button("Cancel") { presentationMode.wrappedValue.dismiss() }
        }
        .frame(width: 320, height: 120)
        .onAppear { DispatchQueue.main.async { openPanel() } }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mov", "mp4", "m4v"]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { resp in
            if resp == .OK {
                selectedURL = panel.url
            }
            presentationMode.wrappedValue.dismiss()
        }
    }
}
#endif

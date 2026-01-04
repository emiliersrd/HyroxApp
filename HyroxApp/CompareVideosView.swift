// swift
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
    @State private var leftURL: URL?
    @State private var rightURL: URL?
    @State private var showLeftPicker = false
    @State private var showRightPicker = false

    private let analyzer = SkeletonAnalyzer()

    @State private var leftPlayer: AVPlayer?
    @State private var rightPlayer: AVPlayer?
    @State private var leftObservations: [TimedObservation] = []
    @State private var rightObservations: [TimedObservation] = []

    @State private var isAnalyzing = false
    @State private var currentTime: CMTime = .zero
    @State private var timeObserverToken: Any?

    @State private var comparisonURL: URL?
    @State private var comparisonPlayer: AVPlayer?

    var body: some View {
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
            }
            .padding(.horizontal)

            if isAnalyzing {
                ProgressView("Analyzing...")
                    .padding(.top, 6)
            }

            HStack(spacing: 12) {
                Button("Analyze & Play Both") {
                    guard let l = leftURL, let r = rightURL else { return }
                    analyzeBothAndPlay(left: l, right: r)
                }
                .disabled(leftURL == nil || rightURL == nil || isAnalyzing)
                .buttonStyle(.borderedProminent)

                Button("Play Both (no analysis)") {
                    guard let l = leftURL, let r = rightURL else { return }
                    playBoth(left: l, right: r)
                }
                .disabled(leftURL == nil || rightURL == nil)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            HStack {
                Button("Generate Skeleton Overlay Video") { exportSkeletonOverlay() }
                    .disabled(leftURL == nil || rightURL == nil || isAnalyzing)
                    .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                playerView(player: leftPlayer)
                playerView(player: rightPlayer)
            }
            .frame(maxHeight: 360)

            let leftPoints = convertToTimedPoints(leftObservations)
            let rightPoints = convertToTimedPoints(rightObservations)

            VStack(alignment: .leading, spacing: 8) {
                Text("Combined Skeleton")
                    .font(.headline)
                    .padding(.horizontal)
                CombinedSkeletonOverlayView(left: leftPoints, right: rightPoints, currentTime: currentTime)
                    .frame(height: 160)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Comparison Preview")
                    .font(.headline)
                    .padding(.horizontal)
                if let player = comparisonPlayer {
                    VideoPlayer(player: player)
                        .id(comparisonURL?.absoluteString ?? UUID().uuidString)
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

            Spacer()
        }
        .padding(.vertical)
        #if os(macOS)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 36) }
        #endif
        .sheet(isPresented: $showLeftPicker) {
            VideoPicker(selectedURL: $leftURL)
        }
        .sheet(isPresented: $showRightPicker) {
            VideoPicker(selectedURL: $rightURL)
        }
        .onDisappear { stopPlayback() }
    }

    private func playerView(player: AVPlayer?) -> some View {
        ZStack {
            if let p = player {
                VideoPlayer(player: p)
                    .onDisappear { stopPlayback() }
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .overlay(Text("Ready to play").foregroundColor(.white))
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(8)
        .clipped()
    }

    // MARK: - Analysis & Playback

    private func analyzeBothAndPlay(left: URL, right: URL) {
        isAnalyzing = true
        leftObservations = []
        rightObservations = []

        let group = DispatchGroup()
        var leftResult: [TimedObservation] = []
        var rightResult: [TimedObservation] = []

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            analyzer.analyzeAsset(url: left) { obs in
                leftResult = obs
                group.leave()
            }
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            analyzer.analyzeAsset(url: right) { obs in
                rightResult = obs
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isAnalyzing = false
            self.leftObservations = leftResult
            self.rightObservations = rightResult
            self.playBoth(left: left, right: right)
        }
    }

    private func playBoth(left: URL, right: URL) {
        stopPlayback()

        let lp = AVPlayer(url: left)
        let rp = AVPlayer(url: right)

        lp.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        rp.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)

        self.leftPlayer = lp
        self.rightPlayer = rp
        self.currentTime = .zero

        DispatchQueue.main.async {
            lp.play()
            rp.play()
        }

        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = lp.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time
        }
    }

    private func stopPlayback() {
        if let token = timeObserverToken, let lp = leftPlayer {
            lp.removeTimeObserver(token)
            timeObserverToken = nil
        }
        leftPlayer?.pause()
        rightPlayer?.pause()
        comparisonPlayer?.pause()
        leftPlayer = nil
        rightPlayer = nil
        currentTime = .zero
    }

    // MARK: - Skeleton overlay export

    private func exportSkeletonOverlay() {
        guard let leftURL = leftURL, let rightURL = rightURL else { return }

        if leftObservations.isEmpty || rightObservations.isEmpty {
            isAnalyzing = true
            leftObservations = []
            rightObservations = []

            let group = DispatchGroup()
            var leftResult: [TimedObservation] = []
            var rightResult: [TimedObservation] = []

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                analyzer.analyzeAsset(url: leftURL) { obs in
                    leftResult = obs
                    group.leave()
                }
            }

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                analyzer.analyzeAsset(url: rightURL) { obs in
                    rightResult = obs
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.isAnalyzing = false
                self.leftObservations = leftResult
                self.rightObservations = rightResult
                let leftPoints = self.convertToTimedPoints(leftResult)
                let rightPoints = self.convertToTimedPoints(rightResult)
                self.composeSkeletonOverlay(leftPoints: leftPoints, rightPoints: rightPoints)
            }
        } else {
            let leftPoints = convertToTimedPoints(leftObservations)
            let rightPoints = convertToTimedPoints(rightObservations)
            composeSkeletonOverlay(leftPoints: leftPoints, rightPoints: rightPoints)
        }
    }

    private func composeSkeletonOverlay(leftPoints: [TimedPoints], rightPoints: [TimedPoints]) {
        guard !leftPoints.isEmpty && !rightPoints.isEmpty else { return }

        let fps: Int32 = 30
        let durationSeconds = max(leftPoints.last!.time.seconds, rightPoints.last!.time.seconds)
        let frameCount = Int(ceil(durationSeconds * Double(fps)))
        let videoSize = CGSize(width: 1280, height: 360)

        let filename = "skeleton_overlay_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: outputURL)

        let connections: [(Int, Int)] = [
            (5,6), (5,7), (7,9), (6,8), (8,10),
            (11,12), (11,13), (13,15), (12,14), (14,16),
            (5,11), (6,12),
            (0,1),(0,2),(1,3),(2,4)
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
                print("Failed to create AVAssetWriter")
                return
            }

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(videoSize.width),
                AVVideoHeightKey: Int(videoSize.height)
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = false

            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height)
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)

            guard writer.canAdd(input) else {
                print("Cannot add input to writer")
                return
            }
            writer.add(input)

            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            var frameIndex = 0
            let jointOrderCount = 17

            func samplePoints(at t: Double, from track: [TimedPoints]) -> [CGPoint] {
                if track.isEmpty { return Array(repeating: CGPoint(x: 0.5, y: 0.5), count: jointOrderCount) }
                var best = track[0]
                var bestDiff = abs(track[0].time.seconds - t)
                for p in track {
                    let d = abs(p.time.seconds - t)
                    if d < bestDiff {
                        best = p
                        bestDiff = d
                    }
                }
                return best.points.map { CGPoint(x: $0.x * videoSize.width, y: $0.y * videoSize.height) }
            }

            let drawingQueue = DispatchQueue(label: "skeleton.render.queue")

            input.requestMediaDataWhenReady(on: drawingQueue) {
                while input.isReadyForMoreMediaData && frameIndex < frameCount {
                    autoreleasepool {
                        let tSec = Double(frameIndex) / Double(fps)
                        let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: fps)

                        let leftSample = samplePoints(at: tSec, from: leftPoints)
                        let rightSample = samplePoints(at: tSec, from: rightPoints)

                        guard let cgImage = renderSkeletonImage(size: videoSize, left: leftSample, right: rightSample, connections: connections) else {
                            print("Failed to render frame \(frameIndex)")
                            frameIndex += 1
                            return
                        }

                        if let px = pixelBuffer(from: cgImage, size: videoSize) {
                            let appended = adaptor.append(px, withPresentationTime: presentationTime)
                            if !appended {
                                print("Failed to append frame at \(frameIndex)")
                            }
                        } else {
                            print("Failed to create pixel buffer for frame \(frameIndex)")
                        }
                        frameIndex += 1
                    }
                }

                if frameIndex >= frameCount {
                    input.markAsFinished()
                    writer.finishWriting {
                        DispatchQueue.main.async {
                            if FileManager.default.fileExists(atPath: outputURL.path) {
                                let player = AVPlayer(url: outputURL)
                                self.comparisonURL = outputURL
                                self.comparisonPlayer = player
                                player.seek(to: .zero) { _ in player.play() }
                            } else {
                                print("Output file missing after write")
                            }
                        }
                    }
                }
            }
        }
    }

    // draw skeletons into CGImage
    private func renderSkeletonImage(size: CGSize, left: [CGPoint], right: [CGPoint], connections: [(Int, Int)]) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo) else { return nil }

        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))

        func drawSkeleton(points: [CGPoint], color: CGColor, lineWidth: CGFloat = 3.0) {
            ctx.setStrokeColor(color)
            ctx.setLineWidth(lineWidth)
            for (a, b) in connections {
                guard a >= 0 && a < points.count && b >= 0 && b < points.count else { continue }
                let pa = points[a]
                let pb = points[b]
                if (pa.x == size.width * 0.5 && pa.y == size.height * 0.5) && (pb.x == size.width * 0.5 && pb.y == size.height * 0.5) {
                    continue
                }
                ctx.move(to: CGPoint(x: pa.x, y: size.height - pa.y))
                ctx.addLine(to: CGPoint(x: pb.x, y: size.height - pb.y))
                ctx.strokePath()
            }

            for p in points {
                if p.x == size.width * 0.5 && p.y == size.height * 0.5 { continue }
                let r: CGFloat = 4.0
                let circleRect = CGRect(x: p.x - r, y: (size.height - p.y) - r, width: r*2, height: r*2)
                ctx.setFillColor(color)
                ctx.fillEllipse(in: circleRect)
            }
        }

        drawSkeleton(points: left, color: CGColor(red: 1, green: 0, blue: 0, alpha: 0.9))
        drawSkeleton(points: right, color: CGColor(red: 0, green: 1, blue: 0, alpha: 0.9))

        return ctx.makeImage()
    }

    // create CVPixelBuffer from CGImage
    private func pixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
        var px: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: kCFBooleanTrue!
        ] as CFDictionary

        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                                         kCVPixelFormatType_32ARGB, attrs, &px)
        guard status == kCVReturnSuccess, let pixelBuffer = px else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let pxData = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pxData,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else {
            return nil
        }

        context.clear(CGRect(origin: .zero, size: size))
        context.draw(image, in: CGRect(origin: .zero, size: size))

        return pixelBuffer
    }

    // MARK: - Export / Compose (existing)
    private func exportComparison() {
        // kept unchanged
    }

    private func composeComparison(leftPoints: [TimedPoints], rightPoints: [TimedPoints]) {
        // kept unchanged
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


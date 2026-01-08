import Foundation
import Combine
import AVFoundation
import SwiftUI
import Vision

@MainActor
final class CompareViewModel: ObservableObject {
    private let analyzer = SkeletonAnalyzer()

    // Players
    @Published var leftPlayer: AVPlayer?
    @Published var rightPlayer: AVPlayer?

    // Observations
    @Published var leftObservations: [TimedObservation] = []
    @Published var rightObservations: [TimedObservation] = []

    // Video sizes
    @Published var leftVideoSize: CGSize = .zero
    @Published var rightVideoSize: CGSize = .zero

    // UI state
    @Published var isAnalyzing: Bool = false
    @Published var currentTime: CMTime = .zero
    @Published var showFullscreenCompare: Bool = false
    // comparison export result
    @Published var comparisonURL: URL?
    @Published var comparisonPlayer: AVPlayer?

    // internal
    private var timeObserverToken: Any?

    init() {}

    func analyzeBothAndPlay(left: URL, right: URL) {
        Task { @MainActor in
            // mark analyzing on main actor and clear state
            self.isAnalyzing = true
            self.leftObservations = []
            self.rightObservations = []
            self.leftVideoSize = .zero
            self.rightVideoSize = .zero
        }

        Task.detached(priority: .userInitiated) {
            // local analyzer instance so we don't touch actor-isolated stored properties from this background task
            let analyzer = SkeletonAnalyzer()

            async let lSize = try? await CompareViewModel.probeVideoSize(url: left)
            async let rSize = try? await CompareViewModel.probeVideoSize(url: right)

            async let leftObs = CompareViewModel.analyzeAssetAsync(left)
            async let rightObs = CompareViewModel.analyzeAssetAsync(right)

            let (ls, rs, lObs, rObs) = await (lSize, rSize, leftObs, rightObs)

            await MainActor.run {
                if let ls = ls { self.leftVideoSize = ls }
                if let rs = rs { self.rightVideoSize = rs }
                self.leftObservations = lObs
                self.rightObservations = rObs
                self.isAnalyzing = false
                self.playBoth(left: left, right: right)
            }
        }
    }

    // Async wrapper for the callback-based analyzer; self-contained so it can run off-main
    private static nonisolated func analyzeAssetAsync(_ url: URL) async -> [TimedObservation] {
        let analyzer = SkeletonAnalyzer()
        return await withCheckedContinuation { continuation in
            analyzer.analyzeAsset(url: url) { obs in
                continuation.resume(returning: obs)
            }
        }
    }

    func playBoth(left: URL, right: URL) {
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
            self.addTimeObserver(to: lp)
            self.showFullscreenCompare = true
        }
    }

    func stopPlayback() {
        if let token = timeObserverToken, let lp = leftPlayer {
            lp.removeTimeObserver(token)
            timeObserverToken = nil
        }
        leftPlayer?.pause()
        rightPlayer?.pause()
        leftPlayer = nil
        rightPlayer = nil
        currentTime = .zero
    }

    private func addTimeObserver(to player: AVPlayer) {
        removeTimeObserver()
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // update on main actor explicitly
            Task { @MainActor in
                self?.currentTime = time
            }
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken, let lp = leftPlayer {
            lp.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // Probe video natural size taking into account preferredTransform
    private static nonisolated func probeVideoSize(url: URL) async throws -> CGSize {
        let asset = AVAsset(url: url)
        let tracks: [AVAssetTrack] = try await asset.load(.tracks)
        if let track = tracks.first {
            let natural: CGSize = try await track.load(.naturalSize)
            let t: CGAffineTransform = try await track.load(.preferredTransform)
            let isPortrait = abs(t.b) == 1.0 || abs(t.c) == 1.0
            return isPortrait ? CGSize(width: natural.height, height: natural.width) : natural
        }
        return .zero
    }

    /// Export a combined skeleton overlay video for the given left/right source files.
    /// The resulting URL/player are published on `comparisonURL` / `comparisonPlayer`.
    func exportComparison(leftURL: URL, rightURL: URL) {
        Task.detached(priority: .userInitiated) {
            // If observations missing, run analysis
            var lObs = await MainActor.run { self.leftObservations }
            var rObs = await MainActor.run { self.rightObservations }

            if lObs.isEmpty || rObs.isEmpty {
                await MainActor.run { self.isAnalyzing = true }
                // run analyses (analyzeAssetAsync creates its own analyzer)
                async let a = CompareViewModel.analyzeAssetAsync(leftURL)
                async let b = CompareViewModel.analyzeAssetAsync(rightURL)
                let (la, rb) = await (a, b)
                lObs = la
                rObs = rb
                await MainActor.run {
                    self.leftObservations = lObs
                    self.rightObservations = rObs
                    self.isAnalyzing = false
                }
            }

            // convert observations to timed points on the main actor (observations may be actor-isolated)
            let leftPoints = await MainActor.run { CompareViewModel.convertToTimedPointsStatic(lObs) }
            let rightPoints = await MainActor.run { CompareViewModel.convertToTimedPointsStatic(rObs) }

            // Compose overlay on background
            let (outputURL, player) = await self.composeSkeletonOverlayInBackground(leftPoints: leftPoints, rightPoints: rightPoints)

            await MainActor.run {
                if let url = outputURL, let p = player {
                    self.comparisonURL = url
                    self.comparisonPlayer = p
                }
            }
        }
    }

    // Compose overlay video in background and return URL/player
    private func composeSkeletonOverlayInBackground(leftPoints: [TimedPoints], rightPoints: [TimedPoints]) async -> (URL?, AVPlayer?) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(URL?, AVPlayer?), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                guard !leftPoints.isEmpty && !rightPoints.isEmpty else { continuation.resume(returning: (nil, nil)); return }

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

                guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
                    print("Failed to create AVAssetWriter")
                    continuation.resume(returning: (nil, nil))
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
                    continuation.resume(returning: (nil, nil))
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

                            guard let cgImage = CompareViewModel.renderSkeletonImage(size: videoSize, left: leftSample, right: rightSample, connections: connections) else {
                                print("Failed to render frame \(frameIndex)")
                                frameIndex += 1
                                return
                            }

                            if let px = CompareViewModel.pixelBuffer(from: cgImage, size: videoSize) {
                                let appended = adaptor.append(px, withPresentationTime: presentationTime)
                                if !appended { print("Failed to append frame at \(frameIndex)") }
                            } else {
                                print("Failed to create pixel buffer for frame \(frameIndex)")
                            }
                            frameIndex += 1
                        }
                    }

                    if frameIndex >= frameCount {
                        input.markAsFinished()
                        writer.finishWriting {
                            if FileManager.default.fileExists(atPath: outputURL.path) {
                                let player = AVPlayer(url: outputURL)
                                continuation.resume(returning: (outputURL, player))
                            } else {
                                print("Output file missing after write")
                                continuation.resume(returning: (nil, nil))
                            }
                        }
                    }
                }
            }
        }
    }

    // Convert TimedObservation to TimedPoints (same logic as in view)
    private static nonisolated func convertToTimedPointsStatic(_ timedObs: [TimedObservation]) -> [TimedPoints] {
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

    // Compose an overlay-only video (skeletons) and publish the result
    func composeSkeletonOverlay(leftPoints: [TimedPoints], rightPoints: [TimedPoints]) {
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

                        guard let cgImage = CompareViewModel.renderSkeletonImage(size: videoSize, left: leftSample, right: rightSample, connections: connections) else {
                            print("Failed to render frame \(frameIndex)")
                            frameIndex += 1
                            return
                        }

                        if let px = CompareViewModel.pixelBuffer(from: cgImage, size: videoSize) {
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
    static nonisolated func renderSkeletonImage(size: CGSize, left: [CGPoint], right: [CGPoint], connections: [(Int, Int)]) -> CGImage? {
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
    static nonisolated func pixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
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
}

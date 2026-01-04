// swift
// File: `HyroxApp/SkeletonAnalyzer.swift`
import Foundation
import AVFoundation
import Vision
import CoreMedia

public final class SkeletonAnalyzer {
    private var imageGenerator: AVAssetImageGenerator?

    public init() {}

    // Matches the call used in RenameLabelView: analyzer.analyzeAsset(url:) { obs in ... }
    public func analyzeAsset(url: URL,
                             frameInterval: Double = 0.2,
                             completion: @escaping ([TimedObservation]) -> Void) {
        let asset = AVAsset(url: url)
        let duration = asset.duration
        guard duration.seconds > 0 else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let generator = AVAssetImageGenerator(asset: asset)
        self.imageGenerator = generator // retain until finished
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var times: [NSValue] = []
        var t: Double = 0
        while t < duration.seconds {
            let cm = CMTimeMakeWithSeconds(t, preferredTimescale: 600)
            times.append(NSValue(time: cm))
            t += frameInterval
        }
        if times.isEmpty {
            self.imageGenerator = nil
            DispatchQueue.main.async { completion([]) }
            return
        }

        var observations: [TimedObservation] = []
        let observationsLock = DispatchQueue(label: "SkeletonAnalyzer.observationsLock")
        let group = DispatchGroup()

        for _ in times { group.enter() }

        generator.generateCGImagesAsynchronously(forTimes: times) { [weak self] requestedTime, cgImage, actualTime, result, error in
            defer { group.leave() }

            guard result == .succeeded, let cgImage = cgImage else {
                return
            }

            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                if let obs = request.results?.compactMap({ $0 as? VNHumanBodyPoseObservation }).first {
                    observationsLock.sync {
                        observations.append(TimedObservation(time: actualTime, observation: obs))
                    }
                }
            } catch {
                // ignore per-frame Vision errors
            }
        }

        group.notify(queue: .main) { [weak self] in
            let sorted = observations.sorted { $0.time < $1.time }
            completion(sorted)
            // release the generator so it can deinit
            self?.imageGenerator = nil
        }
    }
}

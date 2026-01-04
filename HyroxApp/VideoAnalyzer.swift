// swift
// File: `HyroxApp/VideoAnalyzer.swift`
import Foundation
import AVFoundation
import Vision
import CoreMedia
import CoreGraphics

/// Samples frames with AVAssetImageGenerator, downsizes, limits Vision concurrency,
/// and returns an array of TimedObservation on the main queue.
public func fastAnalyzeAsset(
    url: URL,
    sampleFPS: Double = 5.0,
    targetSize: CGSize = CGSize(width: 256, height: 256),
    maxConcurrentRequests: Int = 2,
    completion: @escaping ([TimedObservation]) -> Void
) {
    let asset = AVAsset(url: url)

    func process(withTracks tracks: [AVAssetTrack]) {
        guard !tracks.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let durationSeconds = asset.duration.seconds
        guard durationSeconds.isFinite && durationSeconds > 0 else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let frameCount = max(1, Int((durationSeconds * sampleFPS).rounded(.down)))
        let times: [NSValue] = (0..<frameCount).map { i in
            let seconds = Double(i) / sampleFPS
            return NSValue(time: CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = targetSize
        generator.requestedTimeToleranceBefore = CMTimeMake(value: 1, timescale: 30)
        generator.requestedTimeToleranceAfter = CMTimeMake(value: 1, timescale: 30)

        let visionQueue = DispatchQueue(label: "fastAnalyze.vision", attributes: .concurrent)
        let semaphore = DispatchSemaphore(value: maxConcurrentRequests)
        let generationGroup = DispatchGroup()
        let visionGroup = DispatchGroup()
        let resultsLock = DispatchQueue(label: "fastAnalyze.resultsLock")
        var results: [TimedObservation] = []

        for _ in times { generationGroup.enter() }

        generator.generateCGImagesAsynchronously(forTimes: times) { requestedTimeValue, cgImage, actualTime, result, error in
            defer { generationGroup.leave() }

            guard let cgImage = cgImage else { return }

            semaphore.wait()
            visionGroup.enter()
            visionQueue.async {
                defer {
                    semaphore.signal()
                    visionGroup.leave()
                }

                let request = VNDetectHumanBodyPoseRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    if let obs = request.results?.first as? VNHumanBodyPoseObservation {
                        let timed = TimedObservation(time: actualTime, observation: obs)
                        resultsLock.async {
                            results.append(timed)
                        }
                    }
                } catch {
                    // ignore per-frame errors
                }
            }
        }

        generationGroup.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
            visionGroup.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
                resultsLock.sync {
                    let sorted = results.sorted { $0.time < $1.time }
                    DispatchQueue.main.async {
                        completion(sorted)
                    }
                }
            }
        }
    }

    if #available(iOS 16.0, *) {
        asset.loadTracks(withMediaType: .video) { tracks, loadError in
            // unwrap optional tracks safely; fallback to empty array
            process(withTracks: tracks ?? [])
        }
    } else {
        let tracks = asset.tracks(withMediaType: .video)
        process(withTracks: tracks)
    }
}

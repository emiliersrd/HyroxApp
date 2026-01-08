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

/// More precise analyzer using AVAssetReader to obtain CVPixelBuffer frames and their exact
/// presentation timestamps. This reduces timestamp drift vs playback and is better when you
/// need tight sync between analyzed keypoints and video frames.
public func fastAnalyzeAssetUsingReader(
    url: URL,
    sampleFPS: Double = 10.0,
    targetSize: CGSize = CGSize(width: 256, height: 256),
    maxConcurrentRequests: Int = 2,
    completion: @escaping ([TimedObservation]) -> Void
) {
    let asset = AVAsset(url: url)
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            let reader = try AVAssetReader(asset: asset)

            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
            trackOutput.alwaysCopiesSampleData = false

            guard reader.canAdd(trackOutput) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            reader.add(trackOutput)

            if !reader.startReading() {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let visionQueue = DispatchQueue(label: "fastAnalyze.reader.vision", attributes: .concurrent)
            let semaphore = DispatchSemaphore(value: maxConcurrentRequests)
            let visionGroup = DispatchGroup()
            var results: [TimedObservation] = []
            let resultsLock = DispatchQueue(label: "fastAnalyze.reader.resultsLock")

            let sampleInterval = CMTimeMake(value: 1, timescale: Int32(sampleFPS))
            var nextSampleTime = CMTime.zero

            while reader.status == .reading {
                guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else { break }
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                // process when pts >= nextSampleTime
                if pts >= nextSampleTime {
                    // advance nextSampleTime
                    repeat { nextSampleTime = CMTimeAdd(nextSampleTime, sampleInterval) } while nextSampleTime <= pts

                    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        semaphore.wait()
                        visionGroup.enter()
                        visionQueue.async {
                            defer { semaphore.signal(); visionGroup.leave() }
                            let request = VNDetectHumanBodyPoseRequest()
                            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
                            do {
                                try handler.perform([request])
                                if let obs = request.results?.first as? VNHumanBodyPoseObservation {
                                    let timed = TimedObservation(time: pts, observation: obs)
                                    resultsLock.async { results.append(timed) }
                                }
                            } catch {
                                // ignore
                            }
                        }
                    }
                }
            }

            visionGroup.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
                resultsLock.sync {
                    let sorted = results.sorted { $0.time < $1.time }
                    DispatchQueue.main.async { completion(sorted) }
                }
            }

        } catch {
            DispatchQueue.main.async { completion([]) }
        }
    }
}

import Foundation
import Vision
import AVFoundation

/// Skeleton analyzer that uses Vision's human body pose request on video frames.
final class SkeletonAnalyzer {
    private let sequenceHandler = VNSequenceRequestHandler()

    /// Analyze a CMSampleBuffer - returns landmarks if detected
    func analyze(sampleBuffer: CMSampleBuffer) -> VNHumanBodyPoseObservation? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let request = VNDetectHumanBodyPoseRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
            if let observations = request.results as? [VNHumanBodyPoseObservation], let first = observations.first {
                return first
            }
        } catch {
            print("Vision error: \(error)")
        }
        return nil
    }

    /// Analyze using an AVAsset (video file) - iterates frames and calls the completion with observations array
    func analyzeAsset(url: URL, completion: @escaping ([VNHumanBodyPoseObservation]) -> Void) {
        var results: [VNHumanBodyPoseObservation] = []
        let asset = AVAsset(url: url)
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            print("Failed to create reader: \(error)")
            completion([])
            return
        }

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion([])
            return
        }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]

        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(trackOutput)
        reader.startReading()

        while reader.status == .reading {
            if let sample = trackOutput.copyNextSampleBuffer(), let pixelBuffer = CMSampleBufferGetImageBuffer(sample) {
                let request = VNDetectHumanBodyPoseRequest()
                do {
                    try sequenceHandler.perform([request], on: pixelBuffer)
                    if let observations = request.results as? [VNHumanBodyPoseObservation] {
                        results.append(contentsOf: observations)
                    }
                } catch {
                    print("Vision frame error: \(error)")
                }
            }
        }

        if reader.status == .completed {
            completion(results)
        } else {
            completion(results)
        }
    }
}

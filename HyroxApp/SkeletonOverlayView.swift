// swift
import SwiftUI
import Vision
import CoreMedia

struct SkeletonOverlayView: View {
    // Use a named-tuple array to avoid ambiguity with project-level `TimedObservation`
    let observations: [(time: CMTime, observation: VNHumanBodyPoseObservation)]
    let currentTime: CMTime

    // joint pairs to draw as segments
    private static let pairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip)
    ]

    // helper to convert JointName -> VNRecognizedPointKey
    private func key(for joint: VNHumanBodyPoseObservation.JointName) -> VNRecognizedPointKey {
        VNRecognizedPointKey(rawValue: joint.rawValue.rawValue)
    }

    private func observationAtCurrentTime() -> VNHumanBodyPoseObservation? {
        guard !observations.isEmpty else { return nil }
        let secs = currentTime.seconds
        var chosen: (time: CMTime, observation: VNHumanBodyPoseObservation)? = nil
        // assume observations are sorted by time ascending; pick latest <= currentTime
        for o in observations {
            if o.time.seconds <= secs {
                chosen = o
            } else {
                break
            }
        }
        if chosen == nil {
            chosen = observations.first
        }
        return chosen?.observation
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let obs = observationAtCurrentTime(),
                   let points = try? obs.recognizedPointsAll() {
                    // draw segments
                    ForEach(Array(Self.pairs.enumerated()), id: \.offset) { index, pair in
                        let ka = key(for: pair.0)
                        let kb = key(for: pair.1)
                        if let pa = points[ka], let pb = points[kb],
                           pa.confidence > 0.1, pb.confidence > 0.1 {
                            let p1 = CGPoint(x: CGFloat(pa.x) * geo.size.width, y: (1 - CGFloat(pa.y)) * geo.size.height)
                            let p2 = CGPoint(x: CGFloat(pb.x) * geo.size.width, y: (1 - CGFloat(pb.y)) * geo.size.height)
                            Path { path in
                                path.move(to: p1)
                                path.addLine(to: p2)
                            }
                            .stroke(Color.green.opacity(0.9), lineWidth: 3)
                        }
                    }

                    // draw keypoints
                    ForEach(points.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { nameKey in
                        if let point = points[nameKey], point.confidence > 0.1 {
                            let x = CGFloat(point.x) * geo.size.width
                            let y = (1 - CGFloat(point.y)) * geo.size.height
                            Circle()
                                .fill(Color.yellow.opacity(0.95))
                                .frame(width: 10, height: 10)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
        }
    }
}

// swift
import Vision

private extension VNHumanBodyPoseObservation {
    /// Return all recognized points using Vision's group key.
    func recognizedPointsAll() throws -> [VNRecognizedPointKey: VNRecognizedPoint] {
        try recognizedPoints(forGroupKey: VNRecognizedPointGroupKey.all)
    }
}

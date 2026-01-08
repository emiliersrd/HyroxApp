// swift
import SwiftUI
import Vision
import CoreMedia

struct SkeletonOverlayView: View {
    // Use a named-tuple array to avoid ambiguity with project-level `TimedObservation`
    let observations: [(time: CMTime, observation: VNHumanBodyPoseObservation)]
    let currentTime: CMTime
    /// Size (in pixels) of the source video frames used to produce observations.
    /// This is used to compute correct aspect-fit mapping from normalized Vision points
    /// to the SwiftUI view coordinates. If unknown, default to 1x1 to treat points
    /// as fully-normalized to the view.
    let videoSize: CGSize

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

    // Get a pair of nearest observations bracketing currentTime
    private func bracketObservations() -> (prev: (time: CMTime, observation: VNHumanBodyPoseObservation)?, next: (time: CMTime, observation: VNHumanBodyPoseObservation)?) {
        guard !observations.isEmpty else { return (nil, nil) }
        // If currentTime is before first, return first as prev
        var prev: (time: CMTime, observation: VNHumanBodyPoseObservation)? = nil
        var next: (time: CMTime, observation: VNHumanBodyPoseObservation)? = nil
        for o in observations {
            // 'o' is already a labeled tuple (time:..., observation:...)
            if o.time.seconds <= currentTime.seconds {
                prev = o
            } else {
                next = o
                break
            }
        }
        if prev == nil { prev = observations.first }
        if next == nil { next = observations.last }
        return (prev, next)
    }

    // Convert a normalized point (0..1) in video-space to view coordinates using aspectFit
    private func mapPointNormalizedToView(_ point: CGPoint, videoSize: CGSize, viewSize: CGSize) -> CGPoint {
        // If videoSize is degenerate, just map normalized to view directly
        guard videoSize.width > 0 && videoSize.height > 0 else {
            return CGPoint(x: point.x * viewSize.width, y: (1 - point.y) * viewSize.height)
        }

        let videoAspect = videoSize.width / videoSize.height
        let viewAspect = viewSize.width / viewSize.height
        var scale: CGFloat = 1.0
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0

        if viewAspect > videoAspect {
            // view is wider -> video fits by height
            scale = viewSize.height / videoSize.height
            let fittedWidth = videoSize.width * scale
            xOffset = (viewSize.width - fittedWidth) / 2
        } else {
            // view is taller -> video fits by width
            scale = viewSize.width / videoSize.width
            let fittedHeight = videoSize.height * scale
            yOffset = (viewSize.height - fittedHeight) / 2
        }

        // VN points: x (0..1) left->right, y (0..1) bottom->top (Vision coordinate origin is bottom-left)
        let x = point.x * videoSize.width * scale + xOffset
        let y = (1 - point.y) * videoSize.height * scale + yOffset
        return CGPoint(x: x, y: y)
    }

    // Interpolate between two recognized-points dictionaries for fraction t (0..1)
    private func interpolatePoints(_ a: [VNRecognizedPointKey: VNRecognizedPoint], _ b: [VNRecognizedPointKey: VNRecognizedPoint], t: CGFloat) -> [VNRecognizedPointKey: CGPoint] {
        var out: [VNRecognizedPointKey: CGPoint] = [:]
        for (key, pa) in a {
            if let pb = b[key] {
                let x = CGFloat(pa.x) * (1 - t) + CGFloat(pb.x) * t
                let y = CGFloat(pa.y) * (1 - t) + CGFloat(pb.y) * t
                out[key] = CGPoint(x: x, y: y)
            } else {
                out[key] = CGPoint(x: CGFloat(pa.x), y: CGFloat(pa.y))
            }
        }
        // include keys present only in b
        for (key, pb) in b where out[key] == nil {
            out[key] = CGPoint(x: CGFloat(pb.x), y: CGFloat(pb.y))
        }
        return out
    }

    // Return interpolated normalized points for currentTime
    private func interpolatedNormalizedPoints() -> [VNRecognizedPointKey: CGPoint]? {
        if observations.isEmpty { return nil }
        let (prevOpt, nextOpt) = bracketObservations()
        guard let prev = prevOpt else { return nil }
        guard let next = nextOpt else { return nil }

        // If prev and next are the same observation, return its points
        if prev.time == next.time {
            if let pts = try? prev.observation.recognizedPointsAll() {
                var map: [VNRecognizedPointKey: CGPoint] = [:]
                for (k, p) in pts where p.confidence > 0.05 {
                    map[k] = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
                }
                return map
            }
            return nil
        }

        let start = prev.time.seconds
        let end = next.time.seconds
        guard end > start else { return nil }
        let t = CGFloat((currentTime.seconds - start) / (end - start))
        let clampedT = max(0, min(1, t))

        guard let aPoints = try? prev.observation.recognizedPointsAll(), let bPoints = try? next.observation.recognizedPointsAll() else {
            return nil
        }

        // Filter low confidence points first
        var aFiltered: [VNRecognizedPointKey: VNRecognizedPoint] = [:]
        var bFiltered: [VNRecognizedPointKey: VNRecognizedPoint] = [:]
        for (k, p) in aPoints where p.confidence > 0.05 { aFiltered[k] = p }
        for (k, p) in bPoints where p.confidence > 0.05 { bFiltered[k] = p }

        let interp = interpolatePoints(aFiltered, bFiltered, t: clampedT)
        return interp
    }

    // EMA smoothing state to reduce jitter between frames
    @State private var smoothedPoints: [VNRecognizedPointKey: CGPoint] = [:]
    private let smoothingAlpha: CGFloat = 0.45 // 0..1 (higher = more reactive)

    // Apply EMA smoothing to a newly computed set of normalized points
    private func applySmoothing(to newPoints: [VNRecognizedPointKey: CGPoint]) -> [VNRecognizedPointKey: CGPoint] {
        var out = smoothedPoints
        for (k, p) in newPoints {
            if let prev = smoothedPoints[k] {
                let x = prev.x * (1 - smoothingAlpha) + p.x * smoothingAlpha
                let y = prev.y * (1 - smoothingAlpha) + p.y * smoothingAlpha
                out[k] = CGPoint(x: x, y: y)
            } else {
                out[k] = p
            }
        }
        // Optionally prune keys not in newPoints to avoid stale points
        for k in out.keys where newPoints[k] == nil {
            out.removeValue(forKey: k)
        }
        return out
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // compute raw interpolated points
                if let rawPoints = interpolatedNormalizedPoints() {
                    Group {
                        let pointsToUse = smoothedPoints.isEmpty ? rawPoints : smoothedPoints

                        ForEach(Array(Self.pairs.enumerated()), id: \.offset) { index, pair in
                            let ka = key(for: pair.0)
                            let kb = key(for: pair.1)
                            if let pa = pointsToUse[ka], let pb = pointsToUse[kb] {
                                let p1 = mapPointNormalizedToView(pa, videoSize: videoSize, viewSize: geo.size)
                                let p2 = mapPointNormalizedToView(pb, videoSize: videoSize, viewSize: geo.size)
                                Path { path in
                                    path.move(to: p1)
                                    path.addLine(to: p2)
                                }
                                .stroke(Color.green.opacity(0.95), lineWidth: 3)
                            }
                        }

                        ForEach(pointsToUse.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { nameKey in
                            if let pt = pointsToUse[nameKey] {
                                let mapped = mapPointNormalizedToView(pt, videoSize: videoSize, viewSize: geo.size)
                                Circle()
                                    .fill(Color.yellow.opacity(0.95))
                                    .frame(width: 10, height: 10)
                                    .position(x: mapped.x, y: mapped.y)
                            }
                        }
                    }
                }
            }
            .onChange(of: currentTime) { _ in
                if let rawPoints = interpolatedNormalizedPoints() {
                    smoothedPoints = applySmoothing(to: rawPoints)
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

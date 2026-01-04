//
//  CombinedSkeletonOverlayView.swift
//  HyroxApp
//
//  Created by mac on 04/01/2026.
//

// swift
import SwiftUI
import CoreMedia

struct CombinedSkeletonOverlayView: View {
    var left: [TimedPoints]
    var right: [TimedPoints]
    var currentTime: CMTime

    // Joint connections (must match convertToTimedPoints joint order)
    private let connections: [(Int, Int)] = [
        (5,6), (5,7), (7,9), (6,8), (8,10), // shoulders/elbows/wrists
        (11,12), (11,13), (13,15), (12,14), (14,16), // hips/knees/ankles
        (5,11), (6,12), // torso
        (0,1),(0,2),(1,3),(2,4) // head-ish
    ]

    private let jointCount = 17

    private func samplePoints(at t: Double, from track: [TimedPoints]) -> [CGPoint] {
        guard !track.isEmpty else {
            return Array(repeating: CGPoint(x: 0.5, y: 0.5), count: jointCount)
        }
        var best = track[0]
        var bestDiff = abs(track[0].time.seconds - t)
        for p in track {
            let d = abs(p.time.seconds - t)
            if d < bestDiff {
                best = p
                bestDiff = d
            }
        }
        return best.points
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let tSec = currentTime.seconds
                let l = samplePoints(at: tSec, from: left).map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                let r = samplePoints(at: tSec, from: right).map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

                func strokeSkeleton(points: [CGPoint], color: Color, lineWidth: Double = 3.0, alpha: Double = 0.9) {
                    var path = Path()
                    for (a, b) in connections {
                        guard a >= 0 && a < points.count && b >= 0 && b < points.count else { continue }
                        let pa = points[a]
                        let pb = points[b]
                        // skip placeholder center points (0.5,0.5 mapped)
                        if (pa.x == size.width * 0.5 && pa.y == size.height * 0.5) &&
                           (pb.x == size.width * 0.5 && pb.y == size.height * 0.5) {
                            continue
                        }
                        path.move(to: CGPoint(x: pa.x, y: pa.y))
                        path.addLine(to: CGPoint(x: pb.x, y: pb.y))
                    }
                    context.stroke(path, with: .color(color.opacity(alpha)), lineWidth: lineWidth)

                    // joints
                    for p in points {
                        if p.x == size.width * 0.5 && p.y == size.height * 0.5 { continue }
                        let circle = Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
                        context.fill(circle, with: .color(color.opacity(alpha)))
                    }
                }

                strokeSkeleton(points: l, color: .red)
                strokeSkeleton(points: r, color: .green)
            }
            .drawingGroup()
        }
    }
}

// swift
import SwiftUI
import CoreMedia

struct CombinedSkeletonOverlayView: View {
    let left: [TimedPoints]
    let right: [TimedPoints]
    let currentTime: CMTime

    var leftLabel: String = "Left video"
    var rightLabel: String = "Right video"

    // Set to true if the corresponding skeleton appears upside-down (feet at top).
    // Example: if feet are at top, set leftInvertY = true to flip vertically.
    var leftInvertY: Bool = false
    var rightInvertY: Bool = false

    private let connections: [(Int, Int)] = [
        (5,6), (5,7), (7,9), (6,8), (8,10),
        (11,12), (11,13), (13,15), (12,14), (14,16),
        (5,11), (6,12),
        (0,1),(0,2),(1,3),(2,4)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in
                    let t = currentTime.seconds
                    if let l = samplePoints(at: t, from: left) {
                        drawSkeleton(in: &ctx, size: size, points: l, color: .red, invertY: leftInvertY)
                    }
                    if let r = samplePoints(at: t, from: right) {
                        drawSkeleton(in: &ctx, size: size, points: r, color: .green, invertY: rightInvertY)
                    }
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(6)

                VStack {
                    HStack(spacing: 12) {
                        legendItem(color: .red, text: leftLabel)
                        legendItem(color: .green, text: rightLabel)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.45))
                    .foregroundColor(.white)
                    .font(.caption)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(width: geo.size.width)
            }
        }
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func samplePoints(at t: Double, from track: [TimedPoints]) -> [CGPoint]? {
        guard !track.isEmpty else { return nil }
        var best = track[0]
        var bestDiff = abs(best.time.seconds - t)
        for p in track {
            let d = abs(p.time.seconds - t)
            if d < bestDiff {
                best = p
                bestDiff = d
            }
        }
        return best.points
    }

    private func drawSkeleton(in ctx: inout GraphicsContext, size: CGSize, points: [CGPoint], color: Color, invertY: Bool) {
        // If invertY == true, use (1 - y) so the rendered skeleton is vertically flipped.
        let mapped = points.map { pt -> CGPoint in
            let x = pt.x * size.width
            let y = invertY ? (1.0 - pt.y) * size.height : pt.y * size.height
            return CGPoint(x: x, y: y)
        }

        let lineStyle = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        for (a, b) in connections {
            guard a >= 0, a < mapped.count, b >= 0, b < mapped.count else { continue }
            var path = Path()
            path.move(to: mapped[a])
            path.addLine(to: mapped[b])
            ctx.stroke(path, with: .color(color), style: lineStyle)
        }

        for p in mapped {
            let r: CGFloat = 4.0
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r*2, height: r*2)
            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.9)))
        }
    }
}

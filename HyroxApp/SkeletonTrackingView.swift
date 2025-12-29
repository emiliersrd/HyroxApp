import SwiftUI

struct SkeletonTrackingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Skeleton tracking")
                .font(.largeTitle)
                .bold()

            Text("Placeholder for camera preview and coach video.")
                .foregroundColor(.secondary)

            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(height: 300)
                .cornerRadius(12)
                .overlay(
                    Text("Camera preview + overlay")
                        .foregroundColor(.white)
                )

            Spacer()
        }
        .padding()
        .navigationTitle("Skeleton tracking")
    }
}

struct SkeletonTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        SkeletonTrackingView()
    }
}

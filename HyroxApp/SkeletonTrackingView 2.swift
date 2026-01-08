import SwiftUI
import AVFoundation
import Vision
import CoreMedia

struct SkeletonTrackingView: View {
    @StateObject private var camera = CameraController()

    var body: some View {
        VStack(spacing: 16) {
            Text("Live Skeleton Tracking")
                .font(.title2)
                .bold()
                .padding(.top)

            CameraPreviewRepresentable(previewLayer: camera.previewLayer)
                .aspectRatio(9.0/16.0, contentMode: .fit)
                .cornerRadius(12)
                .padding(.horizontal)

            HStack(spacing: 24) {
                Button(action: {
                    if camera.isRecording {
                        camera.stopRecording()
                    } else {
                        camera.startRecording()
                    }
                }) {
                    Label(camera.isRecording ? "Stop Recording" : "Start Recording", systemImage: camera.isRecording ? "stop.circle" : "record.circle")
                        .font(.headline)
                        .padding()
                        .foregroundColor(.white)
                        .background(camera.isRecording ? Color.red : Color.green)
                        .cornerRadius(10)
                }
            }

            if camera.isRecording {
                Text("Recording…")
                    .foregroundColor(.red)
            }

            // Display number of skeletons detected
            if let last = camera.observations.last {
                Text("Skeleton detected at time: \(String(format: "%.2f", last.time.seconds))s")
                    .font(.caption)
                    .padding(.top, 6)
            } else {
                Text("No skeleton detected yet.")
                    .font(.caption)
                    .padding(.top, 6)
            }

            Spacer()
        }
        .navigationTitle("Skeleton Tracking")
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

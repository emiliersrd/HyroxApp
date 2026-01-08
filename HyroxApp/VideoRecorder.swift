import Foundation
import AVFoundation
import SwiftUI
import Combine
import Photos

/// Observable video recorder using AVCaptureSession and AVCaptureMovieFileOutput.
final class VideoRecorder: NSObject, ObservableObject {
    // Manual publisher because automatic synthesis doesn't work when inheriting from NSObject
    let objectWillChange = ObservableObjectPublisher()

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?

    // Notify observers via objectWillChange
    var isRecording = false {
        didSet { objectWillChange.send() }
    }
    var recordedURL: URL? {
        didSet { objectWillChange.send() }
    }

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Video device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.videoDeviceInput = videoInput
            }
        } catch {
            print("Video input error: \(error)")
        }

        // Audio device
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                print("Audio input error: \(error)")
            }
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
    }

    /// Requests camera + microphone permissions. Calls completion(true) if both granted.
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var videoGranted = false
        var audioGranted = false

        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            videoGranted = granted
            group.leave()
        }

        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            audioGranted = granted
            group.leave()
        }

        group.notify(queue: .main) {
            completion(videoGranted && audioGranted)
        }
    }

    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func startRecording() {
        guard !movieOutput.isRecording else { return }
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("recording_\(UUID().uuidString).mov")

        // Ensure fileURL does not already exist
        try? FileManager.default.removeItem(at: fileURL)

        // Set orientation on movie connection if available
        if let connection = movieOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    /// Save the most recent recorded movie to the user's photo library.
    func saveToPhotoLibrary(completion: @escaping (Bool, Error?) -> Void) {
        guard let fileURL = recordedURL else { completion(false, nil); return }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(false, nil) }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: fileURL, options: nil)
            }, completionHandler: { success, error in
                DispatchQueue.main.async { completion(success, error) }
            })
        }
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            if let error = error {
                print("Recording error: \(error)")
            } else {
                self.recordedURL = outputFileURL
            }
        }
    }
}

// SwiftUI preview view for the capture session
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = PreviewContainerView()
        // Ensure the preview layer uses the correct gravity and matches view bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Keep the preview layer sized to the view
        previewLayer.frame = uiView.bounds
    }
}

/// A simple UIView that keeps its sublayers sized to its bounds.
private class PreviewContainerView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        // Resize all sublayers to fill the view
        layer.sublayers?.forEach { $0.frame = bounds }
    }
}

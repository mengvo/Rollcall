// CameraManager.swift

import AVFoundation
import Vision
import SwiftUI
import Combine

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var detectedFaces: [DetectedFace] = []

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "face.detection")
    private var photoContinuation: ((UIImage?) -> Void)?

    func startSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("No camera available")
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoContinuation = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Video frame face detection
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation] else { return }
            let faces = results.map { DetectedFace(boundingBox: $0.boundingBox) }
            DispatchQueue.main.async {
                self?.detectedFaces = faces
            }
        }

        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
}

// MARK: - Photo capture
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?(nil)
            return
        }
        photoContinuation?(image)
        photoContinuation = nil
    }
}

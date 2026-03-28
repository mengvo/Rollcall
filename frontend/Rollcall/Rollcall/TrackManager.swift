import Vision
import UIKit
import CoreVideo
import Combine

// MARK: - Data Models

struct FaceCandidate {
    let quality: Float
    let boundingBox: CGRect
    let image: UIImage          // cropped at scoring time — no buffer retention issues
    let frameIndex: Int
}

class FaceTrack {
    let id: UUID
    var observation: VNDetectedObjectObservation
    var candidates: [FaceCandidate] = []
    var lastSeenFrame: Int
    var isActive: Bool = true
    var framesSinceLastScore: Int = 0
    
    var bestCandidate: FaceCandidate? {
        candidates.max(by: { $0.quality < $1.quality })
    }
    
    init(id: UUID, observation: VNDetectedObjectObservation, frameIndex: Int) {
        self.id = id
        self.observation = observation
        self.lastSeenFrame = frameIndex
    }
}

// MARK: - TrackManager

class TrackManager: ObservableObject {
    
    // MARK: Config
    private let detectionInterval = 30       // re-detect every N frames
    private let qualityScoringInterval = 5   // score quality every N frames per track
    private let trackTimeoutFrames = 15      // close track if not seen for N frames
    private let minFaceSizeRatio: CGFloat = 0.04  // bbox area / frame area minimum
    
    // MARK: State
    private var tracks: [UUID: FaceTrack] = [:]
    private let sequenceHandler = VNSequenceRequestHandler()
    private var frameIndex = 0
    
    // MARK: CIContext (reuse — expensive to create)
    private let ciContext = CIContext()
    
    // MARK: Update Entry Point
    
    /// Called every frame from AVCaptureVideoDataOutputSampleBufferDelegate
    /// Callback returns current face boxes for overlay + optional best image when a track closes
    func update(pixelBuffer: CVPixelBuffer,
                frameIndex: Int,
                completion: @escaping ([TrackedFaceBox], UIImage?) -> Void) {
        self.frameIndex = frameIndex
        
        if frameIndex % detectionInterval == 0 || tracks.isEmpty {
            runDetection(on: pixelBuffer, completion: completion)
        } else {
            runTracking(on: pixelBuffer, completion: completion)
        }
    }
    
    // MARK: - Detection
    
    private func runDetection(on pixelBuffer: CVPixelBuffer,
                              completion: @escaping ([TrackedFaceBox], UIImage?) -> Void) {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        try? handler.perform([request])
        
        guard let detectedFaces = request.results as? [VNFaceObservation] else {
            completion(currentBoxes(), nil)
            return
        }
        
        let detectedIDs = Set(detectedFaces.map { $0.uuid })
        
        // Close tracks for faces no longer detected
        var emittedImage: UIImage? = nil
        for id in tracks.keys where !detectedIDs.contains(id) {
            if let image = closeTrack(id: id) {
                emittedImage = image  // emit one at a time; service will be called per-close
            }
        }
        
        // Seed or update tracks from detection results
        for face in detectedFaces {
            if tracks[face.uuid] == nil {
                // New face — create track
                tracks[face.uuid] = FaceTrack(
                    id: face.uuid,
                    observation: face,
                    frameIndex: frameIndex
                )
            } else {
                // Existing face re-confirmed by detector — update observation
                tracks[face.uuid]?.observation = face
                tracks[face.uuid]?.lastSeenFrame = frameIndex
            }
            
            // Score this frame for all active tracks on detection frames
            scoreFrameIfNeeded(
                trackID: face.uuid,
                observation: face,
                pixelBuffer: pixelBuffer,
                force: true
            )
        }
        
        completion(currentBoxes(), emittedImage)
    }
    
    // MARK: - Tracking
    
    private func runTracking(on pixelBuffer: CVPixelBuffer,
                             completion: @escaping ([TrackedFaceBox], UIImage?) -> Void) {
        guard !tracks.isEmpty else {
            completion([], nil)
            return
        }
        
        // Build one tracking request per active track
        let trackingRequests: [(UUID, VNTrackObjectRequest)] = tracks.compactMap { id, track in
            guard track.isActive else { return nil }
            let request = VNTrackObjectRequest(detectedObjectObservation: track.observation)
            request.trackingLevel = .accurate
            return (id, request)
        }
        
        let requests = trackingRequests.map { $0.1 }
        try? sequenceHandler.perform(requests, on: pixelBuffer)
        
        var emittedImage: UIImage? = nil
        
        for (id, request) in trackingRequests {
            guard let result = request.results?.first as? VNDetectedObjectObservation else {
                // Tracking lost for this face
                if let image = handleTrackingLost(id: id) {
                    emittedImage = image
                }
                continue
            }
            
            if result.confidence < 0.3 {
                // Confidence too low — close track
                if let image = closeTrack(id: id) {
                    emittedImage = image
                }
                continue
            }
            
            // Update track with new tracked position
            tracks[id]?.observation = result
            tracks[id]?.lastSeenFrame = frameIndex
            tracks[id]?.framesSinceLastScore += 1
            
            // Score quality on interval
            scoreFrameIfNeeded(
                trackID: id,
                observation: result,
                pixelBuffer: pixelBuffer,
                force: false
            )
        }
        
        // Timeout tracks not seen recently (e.g. occluded and tracking failed silently)
        for id in tracks.keys {
            if let track = tracks[id],
               frameIndex - track.lastSeenFrame > trackTimeoutFrames {
                if let image = closeTrack(id: id) {
                    emittedImage = image
                }
            }
        }
        
        completion(currentBoxes(), emittedImage)
    }
    
    // MARK: - Quality Scoring
    
    private func scoreFrameIfNeeded(trackID: UUID,
                                    observation: VNDetectedObjectObservation,
                                    pixelBuffer: CVPixelBuffer,
                                    force: Bool) {
        guard let track = tracks[trackID] else { return }
        
        // Only score every N frames unless forced (e.g. on detection frames)
        guard force || track.framesSinceLastScore >= qualityScoringInterval else { return }
        tracks[trackID]?.framesSinceLastScore = 0
        
        // Skip if face is too small — not worth scoring
        let area = observation.boundingBox.width * observation.boundingBox.height
        guard area >= minFaceSizeRatio else { return }
        
        // Crop face from pixel buffer now — don't store the buffer
        guard let croppedImage = cropFace(from: pixelBuffer, boundingBox: observation.boundingBox) else { return }
        
        // Run quality request on the full buffer (Vision needs full image context)
        let qualityRequest = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([qualityRequest])
        
        guard let quality = qualityRequest.results?.first?.faceCaptureQuality else { return }
        
        let candidate = FaceCandidate(
            quality: quality,
            boundingBox: observation.boundingBox,
            image: croppedImage,
            frameIndex: frameIndex
        )
        
        tracks[trackID]?.candidates.append(candidate)
    }
    
    // MARK: - Track Lifecycle
    
    private func handleTrackingLost(id: UUID) -> UIImage? {
        // Give it a few frames grace before closing
        guard let track = tracks[id] else { return nil }
        if frameIndex - track.lastSeenFrame > 5 {
            return closeTrack(id: id)
        }
        return nil
    }
    
    /// Closes a track, returns the best candidate image if one exists
    @discardableResult
    private func closeTrack(id: UUID) -> UIImage? {
        guard let track = tracks[id] else { return nil }
        tracks.removeValue(forKey: id)
        
        // Need at least a few candidates for a meaningful best-frame selection
        guard track.candidates.count >= 2,
              let best = track.bestCandidate else { return nil }
        
        return best.image
    }
    
    // MARK: - Overlay Boxes
    
    /// Current state of all active tracks for the bounding box overlay
    private func currentBoxes() -> [TrackedFaceBox] {
        tracks.values.map { track in
            TrackedFaceBox(
                id: track.id,
                normalizedRect: track.observation.boundingBox,
                quality: track.candidates.last?.quality  // most recently scored quality
            )
        }
    }
    
    // MARK: - Crop Utility
    
    private func cropFace(from pixelBuffer: CVPixelBuffer, boundingBox: CGRect) -> UIImage? {
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        
        let rect = CGRect(
            x: boundingBox.origin.x * width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        ).integral
        
        // Increased from 0.2 to 0.5 — gives InsightFace enough context to detect
        let padding = rect.width * 0.5
        let paddedRect = rect.insetBy(dx: -padding, dy: -padding)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).cropped(to: paddedRect)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

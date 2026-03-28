import SwiftUI
import AVFoundation
import Vision

// MARK: - ContentView

struct MatchView: View {
    let authManager: AuthManager
    @ObservedObject var peopleViewModel: PeopleViewModel
    
    @StateObject private var trackManager = TrackManager()
    @State private var matchedPeople: [MatchResult] = []   // persisted, deduplicated
    @State private var latestMatch: MatchResult?            // for the banner
    @State private var isProcessing = false
    @State private var overlayBoxes: [TrackedFaceBox] = []
    
    var body: some View {
        ZStack {
            CameraView(
                trackManager: trackManager,
                onFaceTracksUpdated: { boxes in
                    overlayBoxes = boxes
                },
                onBestFrameReady: { image in
                    sendToMatchingService(image: image)
                }
            )
            .ignoresSafeArea()
            
            // Face bounding box overlay
            GeometryReader { geo in
                ForEach(overlayBoxes) { box in
                    FaceBoxOverlay(box: box, viewSize: geo.size)
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Latest match banner
                if let result = latestMatch {
                    MatchBanner(result: result)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 60)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Matched people tray
                if !matchedPeople.isEmpty {
                    MatchedPeopleTray(people: matchedPeople)
                        .padding(.bottom, 8)
                }
                
                // Status indicator
                StatusBar(isProcessing: isProcessing, activeTracks: overlayBoxes.count)
                    .padding(.bottom, 32)
            }
        }
        .animation(.spring(duration: 0.3), value: latestMatch?.id)
        .animation(.spring(duration: 0.3), value: matchedPeople.count)
    }
    
    // MARK: - Matching
    
    private func sendToMatchingService(image: UIImage) {
        isProcessing = true
        
        APIService.shared.matchFace(image: image) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let json):
                    guard let id = json["id"] as? Int,
                          let firstName = json["first_name"] as? String,
                          let lastName = json["last_name"] as? String,
                          let imageUrl = json["image_url"] as? String,
                          let similarity = json["similarity"] as? Double else { return }
                    
                    let matchResult = MatchResult(
                        id: id,
                        firstName: firstName,
                        lastName: lastName,
                        imageUrl: imageUrl,
                        similarity: similarity
                    )
                    
                    // Mark as seen in the directory
                    peopleViewModel.markSeen(id: id)
                    
                    if !matchedPeople.contains(where: { $0.id == matchResult.id }) {
                        matchedPeople.append(matchResult)
                        
                        latestMatch = matchResult
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            if latestMatch?.id == matchResult.id {
                                latestMatch = nil
                            }
                        }
                    }
                    
                case .failure:
                    break
                }
            }
        }
    }
}

// MARK: - MatchResult

struct MatchResult: Decodable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let imageUrl: String
    let similarity: Double
    
    var fullName: String { "\(firstName) \(lastName)" }
    
    // Map snake_case from API to camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName  = "last_name"
        case imageUrl  = "image_url"
        case similarity
    }
}

// MARK: - MatchBanner

struct MatchBanner: View {
    let result: MatchResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fullName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(String(format: "%.0f%% match", result.similarity * 100))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - MatchedPeopleTray

struct MatchedPeopleTray: View {
    let people: [MatchResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected (\(people.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(people) { person in
                        MatchedPersonChip(person: person)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct MatchedPersonChip: View {
    let person: MatchResult
    
    var body: some View {
        HStack(spacing: 8) {
            // Person initials avatar
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(initials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(person.fullName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                Text(String(format: "%.0f%%", person.similarity * 100))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var initials: String {
        let f = person.firstName.prefix(1)
        let l = person.lastName.prefix(1)
        return "\(f)\(l)".uppercased()
    }
}

// MARK: - CameraView (UIViewControllerRepresentable)

struct CameraView: UIViewControllerRepresentable {
    let trackManager: TrackManager
    let onFaceTracksUpdated: ([TrackedFaceBox]) -> Void
    let onBestFrameReady: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.trackManager = trackManager
        vc.onFaceTracksUpdated = onFaceTracksUpdated
        vc.onBestFrameReady = onBestFrameReady
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// MARK: - CameraViewController

class CameraViewController: UIViewController {
    var trackManager: TrackManager!
    var onFaceTracksUpdated: (([TrackedFaceBox]) -> Void)?
    var onBestFrameReady: ((UIImage) -> Void)?
    
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "face.processing", qos: .userInitiated)
    private var frameIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupPreviewLayer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            processingQueue.async { self.session.startRunning() }
        }
    }
    
    private func setupCamera() {
        session.sessionPreset = .hd1280x720
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        session.addInput(input)
        
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        
        session.addOutput(videoOutput)
        
        // ← Fix: set portrait orientation on the video connection
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            // Mirror for front camera so left/right aren't flipped
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        processingQueue.async { self.session.startRunning() }
    }
    
    private func setupPreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameIndex += 1
        
        trackManager.update(pixelBuffer: pixelBuffer, frameIndex: frameIndex) { [weak self] boxes, bestImage in
            DispatchQueue.main.async {
                self?.onFaceTracksUpdated?(boxes)
                if let image = bestImage {
                    self?.onBestFrameReady?(image)
                }
            }
        }
    }
}

// MARK: - Supporting UI Components

struct TrackedFaceBox: Identifiable {
    let id: UUID
    let normalizedRect: CGRect  // Vision normalized coords (origin bottom-left)
    let quality: Float?
}

struct FaceBoxOverlay: View {
    let box: TrackedFaceBox
    let viewSize: CGSize
    
    // Convert Vision coords (normalized, bottom-left origin) to SwiftUI (top-left origin)
    private var frame: CGRect {
        CGRect(
            x: (1 - box.normalizedRect.origin.x - box.normalizedRect.width) * viewSize.width,
            y: (1 - box.normalizedRect.origin.y - box.normalizedRect.height) * viewSize.height,
            width: box.normalizedRect.width * viewSize.width,
            height: box.normalizedRect.height * viewSize.height
        )
    }
    
    private var qualityColor: Color {
        guard let q = box.quality else { return .white }
        if q > 0.7 { return .green }
        if q > 0.4 { return .yellow }
        return .red
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(qualityColor, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
            
            if let quality = box.quality {
                Text(String(format: "%.2f", quality))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(qualityColor.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .offset(y: -20)
            }
        }
        .position(x: frame.midX, y: frame.midY)
    }
}

struct StatusBar: View {
    let isProcessing: Bool
    let activeTracks: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Label("\(activeTracks) face\(activeTracks == 1 ? "" : "s")",
                  systemImage: "person.fill")
            
            if isProcessing {
                Label("Matching...", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }
}

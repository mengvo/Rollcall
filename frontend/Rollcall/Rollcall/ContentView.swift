import SwiftUI

struct ContentView: View {
    @ObservedObject var authManager: AuthManager
    @StateObject private var cameraManager = CameraManager()
    @State private var identifiedPeople: [IdentifiedPerson] = []
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            FaceOverlayView(faces: cameraManager.detectedFaces)
                .ignoresSafeArea()

            VStack {
                // Sign out button top-right
                HStack {
                    Spacer()
                    Button(action: {
                        Task { await authManager.signOut() }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }

                Spacer()

                if !identifiedPeople.isEmpty {
                    PeopleListView(people: identifiedPeople)
                        .transition(.move(edge: .bottom))
                }

                HStack {
                    Button(action: captureAndIdentify) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 4)
                                    .frame(width: 82, height: 82)
                            )
                    }
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.5 : 1.0)
                }
                .padding(.bottom, 40)
            }

            if isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Identifying...")
                    .tint(.white)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
    }

    private func captureAndIdentify() {
        isProcessing = true
        cameraManager.capturePhoto { image in
            guard let image = image else {
                isProcessing = false
                return
            }
            APIService.shared.identifyFaces(in: image) { result in
                DispatchQueue.main.async {
                    isProcessing = false
                    switch result {
                    case .success(let people):
                        identifiedPeople = people
                    case .failure(let error):
                        print("ID failed: \(error)")
                    }
                }
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @ObservedObject var authManager: AuthManager
    @StateObject private var cameraManager = CameraManager()
    @State private var identifiedPeople: [IdentifiedPerson] = []
    @State private var isProcessing = false

    // Enroll state
    @State private var showEnrollSheet = false
    @State private var enrollFirstName = ""
    @State private var enrollLastName = ""
    @State private var capturedBase64: String?
    @State private var enrollMessage: String?
    @State private var showNoFaceAlert = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()

            FaceOverlayView(faces: cameraManager.detectedFaces)
                .ignoresSafeArea()

            VStack {
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

                HStack(spacing: 40) {
                    // Match button
                    Button(action: captureAndIdentify) {
                        VStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "magnifyingglass")
                                        .font(.title)
                                        .foregroundColor(.black)
                                )
                            Text("Match")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.5 : 1.0)

                    // Enroll button
                    Button(action: captureAndEnroll) {
                        VStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "person.badge.plus")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                            Text("Enroll")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.5 : 1.0)
                }
                .padding(.bottom, 40)
            }

            if isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Processing...")
                    .tint(.white)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .alert("No Face Detected", isPresented: $showNoFaceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Make sure a face is clearly visible in the frame before enrolling.")
        }
        .sheet(isPresented: $showEnrollSheet) {
            NavigationStack {
                Form {
                    Section("Enter Person's Name") {
                        TextField("First Name", text: $enrollFirstName)
                            .textInputAutocapitalization(.words)
                        TextField("Last Name", text: $enrollLastName)
                            .textInputAutocapitalization(.words)
                    }

                    if let message = enrollMessage {
                        Section {
                            Text(message)
                                .foregroundColor(message.contains("Success") ? .green : .red)
                        }
                    }
                }
                .navigationTitle("Enroll Person")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            resetEnrollState()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            submitEnrollment()
                        }
                        .disabled(enrollFirstName.isEmpty || enrollLastName.isEmpty || isProcessing)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func captureAndIdentify() {
        isProcessing = true
        cameraManager.capturePhoto { image in
            guard let image = image else {
                isProcessing = false
                return
            }
            APIService.shared.matchFace(image: image) { result in
                DispatchQueue.main.async {
                    isProcessing = false
                    switch result {
                    case .success(let json):
                        if let firstName = json["first_name"] as? String,
                           let lastName = json["last_name"] as? String,
                           let similarity = json["similarity"] as? Double {
                            let person = IdentifiedPerson(
                                id: String(json["id"] as? Int ?? 0),
                                name: "\(firstName) \(lastName)",
                                confidence: similarity
                            )
                            identifiedPeople = [person]
                        }
                    case .failure(let error):
                        print("ID failed: \(error)")
                    }
                }
            }
        }
    }

    private func captureAndEnroll() {
        // Check if a face is detected before capturing
        guard !cameraManager.detectedFaces.isEmpty else {
            showNoFaceAlert = true
            return
        }

        cameraManager.capturePhoto { image in
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                return
            }
            DispatchQueue.main.async {
                capturedBase64 = imageData.base64EncodedString()
                enrollFirstName = ""
                enrollLastName = ""
                enrollMessage = nil
                showEnrollSheet = true
            }
        }
    }

    private func submitEnrollment() {
        guard let base64 = capturedBase64 else { return }
        isProcessing = true

        APIService.shared.enrollPerson(
            firstName: enrollFirstName,
            lastName: enrollLastName,
            imageBase64: base64
        ) { result in
            DispatchQueue.main.async {
                isProcessing = false
                switch result {
                case .success:
                    enrollMessage = "Success! \(enrollFirstName) \(enrollLastName) enrolled."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        resetEnrollState()
                    }
                case .failure(let error):
                    enrollMessage = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func resetEnrollState() {
        showEnrollSheet = false
        enrollFirstName = ""
        enrollLastName = ""
        capturedBase64 = nil
        enrollMessage = nil
    }
}

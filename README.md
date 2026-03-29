# Rollcall

## Inspiration

Identity verification is a gatekeeping problem that affects some of the most vulnerable populations. Unhoused individuals are routinely turned away from shelters and services because they lack government-issued ID. Elder care facilities struggle to track residents with cognitive decline who wander. In disaster scenarios, separated families have no fast way to locate each other across shelters. And in everyday settings like schools, manual attendance still eats up instructional time — time that disproportionately impacts under-resourced classrooms where every minute counts.

These are all, at their core, the same problem: *quickly and reliably identifying a person without requiring them to do anything.* We built Rollcall to be a platform that solves that core problem — starting with the simplest use case (attendance) but architected to extend into contexts where the stakes are much higher.

## What it does

Rollcall is an iOS app that uses real-time facial recognition to identify people. Point your camera at someone, and the app detects their face on-device, matches it against an enrolled database using vector similarity search, and returns their identity in seconds — no cards, no sign-in sheets, no verbal roll call.

Key capabilities:

- **Real-time face detection** using Apple's Vision framework, running entirely on-device for speed and privacy — frames never leave the phone for detection
- **Identity matching** via face embeddings and cosine similarity search against a vector database
- **Enrollment** by capturing a photo and entering a name — no complex onboarding
- **People directory** with seen/unseen status tracking
- **Authenticated access** — only authorized users can view or manage the system, a deliberate design choice given the sensitivity of facial data

## How we built it

**Frontend (iOS):** Built natively in Swift/SwiftUI. We used `AVFoundation` for camera access and Apple's `Vision` framework for on-device face detection. The camera preview is bridged into SwiftUI via `UIViewRepresentable`, with real-time bounding box overlays rendered on detected faces. Captured images are base64-encoded and sent to the backend for identification.

**Backend (Python):** A FastAPI server exposes two core endpoints:
- `/enroll` — accepts an image and a name, generates a face embedding, and stores it
- `/match` — accepts an image and returns the closest matching person using vector similarity

**Database & Infrastructure:** Supabase provides the full backend layer:
- PostgreSQL with the `pgvector` extension for high-dimensional vector similarity search on face embeddings
- A `person` table storing names, embedding vectors, and image references
- Supabase Storage for face image files
- Supabase Auth for gating system access

**End-to-end pipeline:**

$$
\text{Camera} \xrightarrow{\text{Vision}} \text{On-Device Detection} \xrightarrow{\text{base64}} \text{FastAPI} \xrightarrow{\text{embedding}} \text{pgvector} \xrightarrow{\text{cosine similarity}} \text{Identity}
$$

This is not a single-API-call integration. The AI pipeline spans on-device inference (Vision), server-side embedding generation, and vector similarity search — three distinct stages with custom logic connecting them.

## Challenges we ran into

- **Learning Swift during a hackathon.** One team member had never written Swift before. Navigating optionals, property wrappers (`@Published`, `@StateObject`), and `UIViewRepresentable` under time pressure was a steep learning curve.
- **Vision framework coordinate misalignment.** Apple's Vision uses a bottom-left origin with normalized 0–1 coordinates, while SwiftUI uses a top-left origin with pixel values. Getting bounding boxes to actually align with detected faces required setting `videoOrientation = .portrait` on the video output and passing `orientation: .up` to `VNImageRequestHandler`.
- **Camera preview rendering black.** The initial `UIViewRepresentable` wrapper displayed nothing. The fix was promoting `AVCaptureVideoPreviewLayer` to the view's own layer class rather than adding it as a sublayer.
- **Supabase connection issues.** Supabase had migrated their hostname format, and our connection string used a deprecated format. Combined with unreliable hackathon WiFi, debugging whether it was a code problem or a network problem took longer than it should have.
- **SwiftUI list crash on delete.** Swipe-to-delete on the people directory triggered a `UICollectionView` inconsistency exception. The root cause: the async Supabase delete call triggered a data refresh that mutated the array mid-animation. The fix was removing the item from the local array synchronously before firing the async delete.

## What we learned

- **Swift and SwiftUI from zero** — the language, the declarative UI model, Combine, and how iOS development fundamentally differs from web/backend work
- **On-device ML inference** — using Apple's Vision framework for real-time face detection without sending data to a server
- **Vector similarity search with pgvector** — storing and querying face embeddings using cosine similarity in PostgreSQL, and understanding the tradeoffs of different distance metrics
- **The ethics of facial recognition are not optional.** Even at the hackathon stage, we had to grapple with questions about consent, data retention, and who gets access. We implemented auth gating as a first step, but a production system would need explicit opt-in enrollment, data retention policies, and transparency about how embeddings are stored. We don't think these are features to add later — they're foundational to whether this technology helps or harms.

## Built with

- Swift / SwiftUI
- AVFoundation & Vision Framework
- FastAPI (Python)
- Supabase (PostgreSQL, pgvector, Auth, Storage)
- Xcode / Kiro IDE

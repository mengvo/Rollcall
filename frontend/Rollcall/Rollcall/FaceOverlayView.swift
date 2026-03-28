// FaceOverlayView.swift

import SwiftUI

struct FaceOverlayView: View {
    let faces: [DetectedFace]

    var body: some View {
        GeometryReader { geometry in
            ForEach(faces) { face in
                // Vision gives bottom-left origin, SwiftUI uses top-left
                let rect = convertBoundingBox(face.boundingBox, in: geometry.size)
                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }

    private func convertBoundingBox(_ box: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: box.origin.x * size.width,
            y: (1 - box.origin.y - box.height) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }
}

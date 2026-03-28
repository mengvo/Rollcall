// Models.swift

import Foundation
import CoreGraphics

struct IdentifiedPerson: Identifiable, Codable {
    let id: String
    let name: String
    let confidence: Double
}

struct DetectedFace: Identifiable {
    let id = UUID()
    let boundingBox: CGRect // normalized 0-1 coordinates from Vision
}

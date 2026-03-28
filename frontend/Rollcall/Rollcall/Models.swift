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

//struct Person: Identifiable, Codable {
//    let id: UUID
//    let name: String
//    let imageUrl: String?
//
//    enum CodingKeys: String, CodingKey {
//        case id
//        case name
//        case imageUrl = "image_url"
//    }
//}

struct Person: Identifiable, Codable {
    let id: Int
    let firstName: String
    let lastName: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case imageUrl = "image_url"
    }
}

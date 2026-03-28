// APIService.swift

import UIKit

class APIService {
    static let shared = APIService()

    // Change this to your actual backend URL
    private let baseURL = "http://127.0.0.1:8000"

    func identifyFaces(in image: UIImage, completion: @escaping (Result<[IdentifiedPerson], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/identify"),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"capture.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(URLError(.zeroByteResource)))
                return
            }
            do {
                let people = try JSONDecoder().decode([IdentifiedPerson].self, from: data)
                completion(.success(people))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

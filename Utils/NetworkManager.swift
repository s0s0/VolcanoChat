import Foundation

class NetworkManager {
    static let shared = NetworkManager()

    private init() {}

    func request<T: Decodable>(
        url: URL,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil,
        responseType: T.Type,
        timeoutInterval: TimeInterval = 120.0
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = timeoutInterval

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func requestData(
        url: URL,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 120.0
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = timeoutInterval

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [Network] 无法获取 HTTP 响应")
            throw NetworkError.invalidResponse
        }

        print("📊 [Network] HTTP 状态码: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ [Network] HTTP 错误: \(httpResponse.statusCode)")

            // 尝试解析错误响应
            if let errorString = String(data: data, encoding: .utf8) {
                print("📄 [Network] 响应内容: \(errorString)")
            }

            throw NetworkError.requestFailed("HTTP \(httpResponse.statusCode)")
        }

        return data
    }
}

enum NetworkError: Error {
    case invalidResponse
    case decodingError
    case requestFailed(String)
}

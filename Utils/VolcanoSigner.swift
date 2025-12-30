import Foundation
import CryptoKit

class VolcanoSigner {
    static let shared = VolcanoSigner()

    private init() {}

    // 火山引擎签名算法 v4
    func signRequest(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?,
        accessKeyId: String,
        secretAccessKey: String,
        region: String = "cn-beijing",
        service: String = "ml_maas"
    ) -> [String: String] {

        let date = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let timestamp = dateFormatter.string(from: date)

        let shortDate = String(timestamp.prefix(8).replacingOccurrences(of: "-", with: ""))

        var signedHeaders = headers
        signedHeaders["X-Date"] = timestamp

        // 计算内容哈希
        let contentHash: String
        if let body = body {
            contentHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        } else {
            contentHash = SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()
        }

        // 构建规范请求
        let canonicalUri = url.path.isEmpty ? "/" : url.path
        let canonicalQueryString = url.query ?? ""

        // 规范化请求头
        let sortedHeaders = signedHeaders.sorted { $0.key.lowercased() < $1.key.lowercased() }
        let canonicalHeaders = sortedHeaders.map { "\($0.key.lowercased()):\($0.value.trimmingCharacters(in: .whitespaces))" }.joined(separator: "\n") + "\n"
        let signedHeadersString = sortedHeaders.map { $0.key.lowercased() }.joined(separator: ";")

        let canonicalRequest = """
        \(method)
        \(canonicalUri)
        \(canonicalQueryString)
        \(canonicalHeaders)
        \(signedHeadersString)
        \(contentHash)
        """

        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8)).map { String(format: "%02x", $0) }.joined()

        // 构建待签名字符串
        let credentialScope = "\(shortDate)/\(region)/\(service)/request"
        let stringToSign = """
        HMAC-SHA256
        \(timestamp)
        \(credentialScope)
        \(canonicalRequestHash)
        """

        // 计算签名
        let kDate = hmacSHA256(key: "VOLC" + secretAccessKey, data: shortDate)
        let kRegion = hmacSHA256(key: kDate, data: region)
        let kService = hmacSHA256(key: kRegion, data: service)
        let kSigning = hmacSHA256(key: kService, data: "request")
        let signature = hmacSHA256(key: kSigning, data: stringToSign).map { String(format: "%02x", $0) }.joined()

        // 构建 Authorization 头
        let authorization = "HMAC-SHA256 Credential=\(accessKeyId)/\(credentialScope), SignedHeaders=\(signedHeadersString), Signature=\(signature)"

        var finalHeaders = signedHeaders
        finalHeaders["Authorization"] = authorization

        return finalHeaders
    }

    private func hmacSHA256(key: String, data: String) -> Data {
        return hmacSHA256(key: Data(key.utf8), data: data)
    }

    private func hmacSHA256(key: Data, data: String) -> Data {
        let key = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: key)
        return Data(signature)
    }
}

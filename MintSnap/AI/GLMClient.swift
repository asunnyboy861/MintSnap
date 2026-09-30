import Foundation

enum GLMError: LocalizedError {
    case proxyNotConfigured
    case insufficientCredits
    case rateLimited
    case badResponse
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .proxyNotConfigured: return "Cloud recognition unavailable. Add your own API key in Settings."
        case .insufficientCredits: return "No cloud scans left. Buy an AI Boost pack or add your own API key."
        case .rateLimited: return "Too many cloud requests right now. Please try again later."
        case .badResponse: return "Cloud service error. Using on-device results instead."
        case .emptyContent: return "Cloud returned no result. Try again or use on-device results."
        }
    }
}

final class KeychainHelper {
    static let service = "com.zzoutuo.MintSnap"

    static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var attrs = base
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class GLMClient {
    static let shared = GLMClient()

    private let proxyURL = URL(string: "https://cramjam-api.calcs.top")!
    private let byoURL = URL(string: "https://api.z.ai/api/paas/v4/chat/completions")!
    private let model = "glm-5.3-flash"

    private var proxyDevKey: String? {
        guard let url = Bundle.main.url(forResource: "GLMProxySecret", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    var byoAPIKey: String? {
        get { KeychainHelper.read("byo_glm_key") }
        set {
            if let v = newValue, !v.isEmpty { KeychainHelper.save(v, account: "byo_glm_key") }
            else { KeychainHelper.delete("byo_glm_key") }
        }
    }

    var hasBYOKey: Bool { byoAPIKey != nil }
    var cloudAvailable: Bool { proxyDevKey != nil || hasBYOKey }

    private var userId: String {
        if let id = KeychainHelper.read("proxy_user_id") { return id }
        let id = UUID().uuidString
        KeychainHelper.save(id, account: "proxy_user_id")
        return id
    }

    static let identifyPrompt = """
    You are a trading-card identification expert. Read the card photo and output STRICT JSON:
    {"cardName":"","setName":"","cardNumber":"","isReverseHolo":false,"isGraded":false,"grader":null,"grade":null,"certNumber":null}
    Rules: setName = official TCG set name; cardNumber like "025/165";
    if the card is inside a grading slab, read the label: grader, grade, certNumber.
    If any field is unreadable, use "" or false. Output JSON only.
    """

    func identifyCard(base64JPEG: String, ocrHints: [String]) async throws -> CardIdentity {
        let hintText = ocrHints.isEmpty ? "" : "\nOCR text found on card (use as hints):\n" + ocrHints.joined(separator: "\n")
        let content: [[String: Any]] = [
            ["type": "text", "text": Self.identifyPrompt + hintText],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64JPEG)"]]
        ]
        let raw = try await chat(content: content, maxTokens: 8192)
        return try Self.parseIdentity(raw)
    }

    static func parseIdentity(_ content: String) throws -> CardIdentity {
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { throw GLMError.badResponse }
        return try JSONDecoder().decode(CardIdentity.self, from: data)
    }

    private func chat(content: [[String: Any]], maxTokens: Int) async throws -> String {
        var payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": content]],
            "thinking": ["level": "low"],
            "max_tokens": maxTokens,
            "response_format": ["type": "json_object"]
        ]

        if let byoKey = byoAPIKey {
            return try await send(
                url: byoURL,
                payload: payload,
                authHeader: "Bearer \(byoKey)"
            )
        }

        guard let devKey = proxyDevKey else { throw GLMError.proxyNotConfigured }

        payload["max_tokens"] = maxTokens
        let body: [String: Any] = [
            "appId": "mintsnap",
            "userId": userId,
            "devKey": devKey,
            "payload": payload
        ]
        return try await send(url: proxyURL, payload: body, authHeader: nil)
    }

    private func send(url: URL, payload: [String: Any], authHeader: String?) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authHeader { req.setValue(authHeader, forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GLMError.badResponse }
        switch http.statusCode {
        case 200:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String, !content.isEmpty else {
                throw GLMError.emptyContent
            }
            return content
        case 402:
            throw GLMError.insufficientCredits
        case 429:
            throw GLMError.rateLimited
        default:
            throw GLMError.badResponse
        }
    }
}

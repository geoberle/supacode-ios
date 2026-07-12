import Foundation

enum ConnectionStore {
    private static let urlKey = "supacode.connection.url"
    private static let tokenKey = "supacode.connection.token"

    static func save(_ connection: Connection) {
        UserDefaults.standard.set(connection.url.absoluteString, forKey: urlKey)
        KeychainHelper.save(connection.token, forKey: tokenKey)
    }

    static func load() -> Connection? {
        guard let urlString = UserDefaults.standard.string(forKey: urlKey),
              let url = URL(string: urlString),
              let token = KeychainHelper.load(forKey: tokenKey)
        else { return nil }
        return Connection(url: url, token: token.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: urlKey)
        KeychainHelper.delete(forKey: tokenKey)
    }
}

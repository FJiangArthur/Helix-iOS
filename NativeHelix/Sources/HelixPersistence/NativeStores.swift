import Foundation
import HelixCore
import Security

public actor UserDefaultsSettingsStore: SettingsStore {
    private let userDefaults: UserDefaults
    private let settingsKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults = .standard,
        settingsKey: String = "helix.native.settings"
    ) {
        self.userDefaults = userDefaults
        self.settingsKey = settingsKey
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func loadSettings() async -> HelixSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return HelixSettings()
        }
        return (try? decoder.decode(HelixSettings.self, from: data)) ?? HelixSettings()
    }

    public func saveSettings(_ settings: HelixSettings) async {
        guard let data = try? encoder.encode(settings) else {
            return
        }
        userDefaults.set(data, forKey: settingsKey)
    }

    public func updateSettings(_ transform: @Sendable (HelixSettings) -> HelixSettings) async -> HelixSettings {
        let updated = transform(await loadSettings())
        await saveSettings(updated)
        return updated
    }

    public func reset() async {
        userDefaults.removeObject(forKey: settingsKey)
    }
}

public actor KeychainSecretStore: SecretStore {
    private let service: String
    private let accessGroup: String?

    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.artjiang.helix.native",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func setSecret(_ value: String?, named name: String) async {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }

        let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedValue, !normalizedValue.isEmpty else {
            await clearSecret(named: normalizedName)
            return
        }

        await clearSecret(named: normalizedName)

        guard let data = normalizedValue.data(using: .utf8) else {
            return
        }

        var query = baseQuery(for: normalizedName)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    public func secret(named name: String) async -> String? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return nil }

        var query = baseQuery(for: normalizedName)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func hasSecret(named name: String) async -> Bool {
        await secret(named: name) != nil
    }

    public func clearSecret(named name: String) async {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }
        SecItemDelete(baseQuery(for: normalizedName) as CFDictionary)
    }

    private func baseQuery(for name: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

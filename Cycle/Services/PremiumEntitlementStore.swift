import Foundation

/// Premium entitlement cached outside SwiftData so freemium gating never requires a schema migration.
enum PremiumEntitlementStore {
    private static let entitledKey = "lune.premium.entitled"
    private static let debugKey = "lune.premium.debug"

    static var cachedEntitlement: Bool {
        get { UserDefaults.standard.bool(forKey: entitledKey) }
        set { UserDefaults.standard.set(newValue, forKey: entitledKey) }
    }

    #if DEBUG
    static var debugOverride: Bool {
        get { UserDefaults.standard.bool(forKey: debugKey) }
        set { UserDefaults.standard.set(newValue, forKey: debugKey) }
    }
    #endif

    static func resolvedEntitlement(storeKitEntitled: Bool) -> Bool {
        #if DEBUG
        if debugOverride { return true }
        #endif
        return storeKitEntitled || cachedEntitlement
    }

    static func persist(storeKitEntitled: Bool) {
        cachedEntitlement = storeKitEntitled
    }
}

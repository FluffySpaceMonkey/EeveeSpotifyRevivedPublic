import Orion
import Foundation

class HubsAdBlocker: ClassHook<NSObject> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName: String = "HUBViewModelBuilderImplementation"
    
    // MARK: - Ad & Upsell Filter
    
    private func shouldStripComponent(_ component: [String: Any]) -> Bool {
        let adKeywords = [
            "ad", "sponsored", "upsell", "campaign", "promoted", "premium-upsell", 
            "merch", "ticket", "billboard", "banner", "interstitial", "overlay", "popup",
            "marquee", "leavebehind", "displayad", "fullbleed", "leaderboard", "advertisement",
            "sponsor", "promo"
        ]
        
        // Check ID
        if let id = component["id"] as? String {
            for keyword in adKeywords {
                if id.localizedCaseInsensitiveContains(keyword) {
                    return true
                }
            }
        }
        
        // Check Component Type
        if let componentType = component["component"] as? String {
            for keyword in adKeywords {
                if componentType.localizedCaseInsensitiveContains(keyword) {
                    return true
                }
            }
        }
        
        // Check Type
        if let type = component["type"] as? String {
            for keyword in adKeywords {
                if type.localizedCaseInsensitiveContains(keyword) {
                    return true
                }
            }
        }
        
        // Check Metadata
        if let metadata = component["metadata"] as? [String: Any] {
            // Check for explicit ad flags in metadata
            if metadata["ad"] as? Bool == true || metadata["is_ad"] as? Bool == true || metadata["is_sponsored"] as? Bool == true {
                return true
            }
            
            // Check for common ad/upsell keys in metadata dictionary
            let metadataKeys = metadata.keys.map { $0.lowercased() }
            if metadataKeys.contains(where: { key in
                adKeywords.contains(where: { key.contains($0) })
            }) {
                return true
            }
        }
        
        // Check Logging Metadata (often contains ad identifiers)
        if let logging = component["logging"] as? [String: Any] {
            if let type = logging["type"] as? String {
                let lowerType = type.lowercased()
                if adKeywords.contains(where: { lowerType.contains($0) }) {
                    return true
                }
            }
        }
        
        // Check Custom Data
        if let custom = component["custom"] as? [String: Any] {
            let customKeys = custom.keys.map { $0.lowercased() }
            if customKeys.contains(where: { key in
                adKeywords.contains(where: { key.contains($0) })
            }) {
                return true
            }
        }

        return false
    }

    private func filterComponents(_ components: [[String: Any]]) -> [[String: Any]] {
        var filtered = [[String: Any]]()
        
        for var component in components {
            if shouldStripComponent(component) {
                continue
            }
            
            // Recursively filter children
            if let children = component["children"] as? [[String: Any]] {
                component["children"] = filterComponents(children)
            }
            
            filtered.append(component)
        }
        
        return filtered
    }

    // MARK: - Hook Implementation

    func addJSONDictionary(_ dictionary: NSDictionary?) {
        guard let dictionary = dictionary as? [String: Any] else {
            orig.addJSONDictionary(dictionary)
            return
        }
        
        // First apply original mutations (like Liked Songs)
        var mutableDictionary = mutateHubsJSON(dictionary)
        
        // Filter 'body' components (main page content)
        if let body = mutableDictionary["body"] as? [[String: Any]] {
            mutableDictionary["body"] = filterComponents(body)
        }
        
        // Filter 'header' components (often contains banners/upsells)
        if let header = mutableDictionary["header"] as? [String: Any] {
            if let children = header["children"] as? [[String: Any]] {
                var mutableHeader = header
                mutableHeader["children"] = filterComponents(children)
                mutableDictionary["header"] = mutableHeader
            }
        }
        
        // Filter 'overlays' (popups/tooltips)
        if let overlays = mutableDictionary["overlays"] as? [[String: Any]] {
            mutableDictionary["overlays"] = filterComponents(overlays)
        }

        orig.addJSONDictionary(mutableDictionary as NSDictionary)
    }
}

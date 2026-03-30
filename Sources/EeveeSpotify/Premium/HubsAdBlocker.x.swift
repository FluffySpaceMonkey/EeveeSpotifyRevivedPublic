import Orion
import Foundation

class HubsAdBlocker: ClassHook<NSObject> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName: String = "HUBViewModelBuilderImplementation"
    
    // MARK: - Ad & Upsell Filter

    // Keywords matched against component `id` and `type` fields (case-insensitive)
    private let adIdKeywords: [String] = [
        "ad", "ads", "advertisement", "sponsored", "upsell", "campaign",
        "promoted", "premium-upsell", "merch", "ticket", "billboard",
        "banner", "interstitial", "overlay", "popup", "pop-up",
        "takeover", "native-ad", "display-ad", "search-takeover",
        "home-takeover", "branded", "brand", "credit-karma",
        "marquee", "leaderboard", "mrec", "halfpage", "skin",
        "roadblock", "wallpaper", "expandable", "rich-media",
        "video-ad", "audio-ad", "companion", "preroll", "midroll",
        "postroll", "rewarded", "offerwall", "survey", "incentivized"
    ]

    private func shouldStripComponent(_ component: [String: Any]) -> Bool {
        // Check ID field
        if let id = component["id"] as? String {
            let lowerID = id.lowercased()
            for keyword in adIdKeywords {
                if lowerID.contains(keyword) {
                    return true
                }
            }
        }

        // Check `type` field — Spotify uses this to identify ad component types
        if let type_ = component["type"] as? String {
            let lowerType = type_.lowercased()
            for keyword in adIdKeywords {
                if lowerType.contains(keyword) {
                    return true
                }
            }
        }

        // Check `component_type` / `componentType` fields
        if let compType = (component["component_type"] ?? component["componentType"]) as? String {
            let lowerCompType = compType.lowercased()
            for keyword in adIdKeywords {
                if lowerCompType.contains(keyword) {
                    return true
                }
            }
        }

        // Check Metadata
        if let metadata = component["metadata"] as? [String: Any] {
            // Check for explicit ad flags in metadata
            if metadata["ad"] as? Bool == true
                || metadata["is_ad"] as? Bool == true
                || metadata["is_sponsored"] as? Bool == true
                || metadata["advertisement"] as? Bool == true {
                return true
            }

            // Check for common ad/upsell keys in metadata dictionary
            let metadataKeys = metadata.keys.map { $0.lowercased() }
            if metadataKeys.contains(where: {
                $0 == "ad"
                    || $0.hasPrefix("ad-")
                    || $0.hasPrefix("ad_")
                    || $0.contains("upsell")
                    || $0.contains("campaign")
                    || $0.contains("promoted")
                    || $0.contains("sponsored")
                    || $0.contains("billboard")
                    || $0.contains("advertisement")
                    || $0.contains("takeover")
            }) {
                return true
            }

            // Check for ad-type string values inside metadata
            if let adType = metadata["type"] as? String {
                let lowerAdType = adType.lowercased()
                for keyword in adIdKeywords {
                    if lowerAdType.contains(keyword) {
                        return true
                    }
                }
            }
        }

        // Check Logging Metadata (often contains ad identifiers)
        if let logging = component["logging"] as? [String: Any] {
            if let type_ = logging["type"] as? String {
                let lowerType = type_.lowercased()
                if lowerType.contains("ad") || lowerType.contains("sponsored") || lowerType.contains("promoted") {
                    return true
                }
            }
            // Also check logging page_instance / component_id for ad markers
            if let pageInstance = logging["page_instance"] as? String {
                let lower = pageInstance.lowercased()
                if lower.contains("ad") || lower.contains("sponsored") || lower.contains("billboard") {
                    return true
                }
            }
        }

        // Check `reason` field — Spotify sometimes marks ad components with a reason
        if let reason = component["reason"] as? String {
            let lowerReason = reason.lowercased()
            if lowerReason.contains("ad") || lowerReason.contains("sponsored") || lowerReason.contains("promoted") {
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

            // Recursively filter nested component arrays under all known container keys
            for key in ["children", "items", "content", "sections", "rows", "components", "slots", "tiles"] {
                if let nested = component[key] as? [[String: Any]] {
                    component[key] = filterComponents(nested)
                }
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

        // Filter 'body' components (main page content — Home & Search feeds)
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

        // Filter 'sections' (used in Search page layout)
        if let sections = mutableDictionary["sections"] as? [[String: Any]] {
            mutableDictionary["sections"] = filterComponents(sections)
        }

        // Filter 'items' (generic item list used across Home and Search)
        if let items = mutableDictionary["items"] as? [[String: Any]] {
            mutableDictionary["items"] = filterComponents(items)
        }

        // Filter 'slots' (ad slot containers)
        if let slots = mutableDictionary["slots"] as? [[String: Any]] {
            mutableDictionary["slots"] = filterComponents(slots)
        }

        orig.addJSONDictionary(mutableDictionary as NSDictionary)
    }
}

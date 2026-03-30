import Orion
import Foundation

// MARK: - Deep recursive ad scanner
// Scans EVERY string value in the entire component tree, not just top-level fields.
// This catches ads that hide their identity in nested tracking/custom_data objects.

private let adSignalKeywords: Set<String> = [
    // Generic ad terms
    "advertisement", "advertise", "advertising",
    // Spotify-specific ad identifiers
    "dfp", "hpto", "marquee", "ad-logic", "adlogic", "ad_logic",
    "gam-ad", "gam_ad", "google_ads", "googleads",
    "doubleclick", "googlesyndication", "adservice",
    "moatads", "scorecardresearch",
    // Spotify internal ad component keys
    "spotifyxp", "xp-ad", "xp_ad",
    "native-ad", "native_ad", "nativead",
    "display-ad", "display_ad", "displayad",
    "search-ad", "search_ad", "searchad",
    "home-ad", "home_ad", "homead",
    "billboard", "takeover", "roadblock",
    "interstitial", "offerwall",
    "preroll", "midroll", "postroll",
    "rewarded-ad", "rewarded_ad",
    "sponsored-content", "sponsored_content",
    "promoted-content", "promoted_content",
    "upsell-banner", "upsell_banner",
    // Credit Karma / Cartier style brand injection
    "credit-karma", "credit_karma", "creditkarma",
    "cartier",
]

// Keywords checked only against component `id`, `type`, `component_key` fields
private let adIdKeywords: Set<String> = [
    "ad", "ads",
    "advertisement", "advertise", "advertising",
    "sponsored", "sponsor",
    "upsell", "premium-upsell", "premium_upsell",
    "campaign", "promoted", "promotion",
    "billboard", "banner", "takeover", "roadblock",
    "interstitial", "overlay", "popup", "pop-up",
    "native-ad", "native_ad", "display-ad", "display_ad",
    "search-ad", "search_ad", "home-ad", "home_ad",
    "dfp", "hpto", "marquee", "adlogic", "ad-logic", "ad_logic",
    "spotifyxp", "xp-ad", "xp_ad",
    "preroll", "midroll", "postroll", "rewarded",
    "offerwall", "incentivized", "survey",
    "merch", "ticket-upsell",
]

// MARK: - Utility: deep-scan any JSON value for ad signals

private func stringContainsAdSignal(_ s: String) -> Bool {
    let lower = s.lowercased()
    for kw in adSignalKeywords {
        if lower.contains(kw) { return true }
    }
    return false
}

private func anyValueContainsAdSignal(_ value: Any) -> Bool {
    if let s = value as? String {
        return stringContainsAdSignal(s)
    }
    if let dict = value as? [String: Any] {
        for (_, v) in dict {
            if anyValueContainsAdSignal(v) { return true }
        }
    }
    if let arr = value as? [Any] {
        for v in arr {
            if anyValueContainsAdSignal(v) { return true }
        }
    }
    return false
}

// MARK: - Component-level ad detection

private func componentIdMatchesAd(_ id: String) -> Bool {
    let lower = id.lowercased()
    for kw in adIdKeywords {
        if lower.contains(kw) { return true }
    }
    return false
}

private func shouldStripComponent(_ component: [String: Any]) -> Bool {
    // 1. Check `id` field
    if let id = component["id"] as? String, componentIdMatchesAd(id) {
        return true
    }

    // 2. Check `type` field
    if let type_ = component["type"] as? String, componentIdMatchesAd(type_) {
        return true
    }

    // 3. Check `component_key` / `componentKey` — Spotify uses this for SpotifyXP / DFP ad slots
    for key in ["component_key", "componentKey", "component_type", "componentType"] {
        if let v = component[key] as? String, componentIdMatchesAd(v) {
            return true
        }
    }

    // 4. Deep-scan `tracking`, `custom_data`, `customData`, `logging`, `metadata`
    //    These nested objects contain the true ad identity even when the top-level id is generic.
    for key in ["tracking", "custom_data", "customData", "logging", "metadata",
                "analytics", "impression_data", "impressionData",
                "event_data", "eventData", "payload", "data"] {
        if let v = component[key] {
            if anyValueContainsAdSignal(v) { return true }
        }
    }

    // 5. Check `reason` field
    if let reason = component["reason"] as? String, componentIdMatchesAd(reason) {
        return true
    }

    // 6. Check `uri` field — Spotify ad URIs often contain "ad" or "spotify:ad:"
    if let uri = component["uri"] as? String {
        let lower = uri.lowercased()
        if lower.contains("spotify:ad:") || lower.contains(":ad:") || lower.contains("/ad/") {
            return true
        }
    }

    return false
}

// MARK: - Recursive component tree filter

private let containerKeys = [
    "children", "items", "content", "sections", "rows",
    "components", "slots", "tiles", "cards", "entries",
    "shelf", "shelves", "modules", "blocks", "cells",
]

private func filterComponents(_ components: [[String: Any]]) -> [[String: Any]] {
    var result = [[String: Any]]()
    for var component in components {
        if shouldStripComponent(component) { continue }
        // Recurse into all known container keys
        for key in containerKeys {
            if let nested = component[key] as? [[String: Any]] {
                component[key] = filterComponents(nested)
            }
        }
        result.append(component)
    }
    return result
}

// Recursively strip ad components from any value (handles mixed arrays)
private func deepFilterValue(_ value: Any) -> Any {
    if var dict = value as? [String: Any] {
        if shouldStripComponent(dict) {
            // Return empty dict to neutralise the component in place
            return [String: Any]()
        }
        for key in containerKeys {
            if let nested = dict[key] as? [[String: Any]] {
                dict[key] = filterComponents(nested)
            } else if let nested = dict[key] as? [Any] {
                dict[key] = nested.compactMap { item -> Any? in
                    if let d = item as? [String: Any], shouldStripComponent(d) { return nil }
                    return deepFilterValue(item)
                }
            }
        }
        return dict
    }
    if let arr = value as? [[String: Any]] {
        return filterComponents(arr)
    }
    if let arr = value as? [Any] {
        return arr.compactMap { item -> Any? in
            if let d = item as? [String: Any], shouldStripComponent(d) { return nil }
            return deepFilterValue(item)
        }
    }
    return value
}

// MARK: - Hook

class HubsAdBlocker: ClassHook<NSObject> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName: String = "HUBViewModelBuilderImplementation"

    func addJSONDictionary(_ dictionary: NSDictionary?) {
        guard var dict = dictionary as? [String: Any] else {
            orig.addJSONDictionary(dictionary)
            return
        }

        // Apply LikedSongs mutation first
        dict = mutateHubsJSON(dict)

        // Filter every top-level container key that can carry ad components
        let topLevelContainerKeys = [
            "body", "sections", "items", "slots", "overlays",
            "rows", "cards", "modules", "blocks", "shelves",
            "components", "tiles", "entries", "cells",
        ]
        for key in topLevelContainerKeys {
            if let arr = dict[key] as? [[String: Any]] {
                dict[key] = filterComponents(arr)
            }
        }

        // Filter header children
        if var header = dict["header"] as? [String: Any] {
            for key in containerKeys {
                if let nested = header[key] as? [[String: Any]] {
                    header[key] = filterComponents(nested)
                }
            }
            dict["header"] = header
        }

        // Deep-filter the entire dictionary for any remaining ad components
        // (catches ads nested inside non-standard keys)
        for (key, value) in dict {
            if topLevelContainerKeys.contains(key) || key == "header" { continue }
            dict[key] = deepFilterValue(value)
        }

        orig.addJSONDictionary(dict as NSDictionary)
    }
}

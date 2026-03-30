import Orion
import Foundation

// MARK: - HubsAdBlocker
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ROOT CAUSE OF ADS SLIPPING THROUGH (all previous versions)             ║
// ║                                                                          ║
// ║  Spotify's HubFramework JSON schema has TWO separate "id" fields:       ║
// ║                                                                          ║
// ║  {                                                                       ║
// ║    "id": "home-section-3",          ← LOGGING ID (generic, useless)     ║
// ║    "component": {                                                        ║
// ║      "id": "spotify:ad-banner",     ← REAL COMPONENT TYPE ← CHECK THIS  ║
// ║      "category": "banner"                                                ║
// ║    },                                                                    ║
// ║    "text": { "title": "Advertisement" },                                 ║
// ║    ...                                                                   ║
// ║  }                                                                       ║
// ║                                                                          ║
// ║  All previous versions checked component["id"] (the logging ID).        ║
// ║  That is why Cartier / Credit Karma ads always got through —             ║
// ║  their logging ID is something like "home-section-3", which contains    ║
// ║  no ad keywords. The real type is in component["component"]["id"].       ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// MARK: - Known Spotify ad component type identifiers (namespace:name)
// These are the values that appear in component["component"]["id"].
// Spotify uses the "spotify:" namespace for all its own components.
private let adComponentTypeIds: Set<String> = [
    // Core ad types
    "spotify:ad",
    "spotify:ad-banner",
    "spotify:ad-card",
    "spotify:ad-row",
    "spotify:ad-carousel",
    "spotify:ad-header",
    "spotify:ad-overlay",
    "spotify:ad-interstitial",
    "spotify:ad-takeover",
    "spotify:ad-billboard",
    "spotify:ad-leaderboard",
    "spotify:ad-mrec",
    "spotify:ad-halfpage",
    "spotify:ad-skin",
    "spotify:ad-roadblock",
    "spotify:ad-wallpaper",
    "spotify:ad-expandable",
    "spotify:ad-video",
    "spotify:ad-audio",
    "spotify:ad-native",
    "spotify:ad-display",
    "spotify:ad-search",
    "spotify:ad-home",
    "spotify:ad-nowplaying",
    // Sponsored / promoted
    "spotify:sponsored",
    "spotify:sponsored-card",
    "spotify:sponsored-row",
    "spotify:sponsored-banner",
    "spotify:sponsored-content",
    "spotify:promoted",
    "spotify:promoted-card",
    "spotify:promoted-row",
    // Upsell
    "spotify:upsell",
    "spotify:upsell-banner",
    "spotify:upsell-card",
    "spotify:upsell-row",
    "spotify:premium-upsell",
    "spotify:premium-upsell-banner",
    "spotify:premium-upsell-card",
    "spotify:premium-upsell-row",
    // Ad platform identifiers
    "spotify:marquee",
    "spotify:billboard",
    "spotify:hpto",
    "spotify:dfp",
    "spotify:gam",
    "spotify:takeover",
    "spotify:interstitial",
    "spotify:overlay",
    "spotify:banner",
    // Misc
    "spotify:merch",
    "spotify:ticket-upsell",
    "spotify:rewarded",
    "spotify:offerwall",
    "spotify:survey",
    "spotify:incentivized",
    "spotify:brand-ad",
    "spotify:brand_ad",
]

// MARK: - Substring keywords for component type matching
// Catches any component["component"]["id"] that contains these substrings.
// This is a safety net for new ad type identifiers Spotify may introduce.
private let adTypeSubstrings: [String] = [
    ":ad", ":ads", ":ad-", ":ad_",
    "ad:", "ads:",
    ":advertisement", ":advertis",
    ":sponsored", ":sponsor",
    ":promoted", ":promotion",
    ":upsell", ":premium-upsell",
    ":billboard", ":takeover",
    ":interstitial", ":overlay",
    ":marquee", ":hpto", ":dfp", ":gam",
    ":rewarded", ":offerwall",
    ":native-ad", ":display-ad",
    ":video-ad", ":audio-ad",
    ":search-ad", ":home-ad",
    ":brand-ad", ":brand_ad",
    ":merch", ":ticket-upsell",
]

// MARK: - Keywords for the component["component"]["category"] field
// Spotify uses categories like "banner", "overlay" for ad components.
// We only strip on category if there's a corroborating signal elsewhere.
private let adCategoryValues: Set<String> = [
    "ad", "ads", "advertisement",
    "sponsored", "promoted",
    "upsell", "premium-upsell",
    "billboard", "takeover",
    "interstitial", "overlay",
    "marquee", "hpto", "dfp", "gam",
    "rewarded", "offerwall",
]

// MARK: - Keywords for deep-scanning metadata/logging/custom blobs
// These are checked recursively through the entire subtree of those fields.
private let adMetaKeywords: [String] = [
    "advertisement", "advertis",
    "sponsored", "sponsor",
    "promoted",
    "upsell",
    "billboard", "takeover",
    "marquee", "hpto", "dfp", "gam",
    "credit-karma", "creditkarma", "credit_karma",
    "cartier",
    "ad_type", "ad_id", "ad_unit", "adtype", "adunit",
    "is_ad", "isad", "is_sponsored",
    "campaign_id", "campaign_type",
    "impression_url", "click_url",
    "ad_slot", "ad_slots",
    "native_ad", "nativead", "display_ad",
    "rewarded", "offerwall",
    "brand_ad", "brand-ad",
]

// MARK: - Keywords for the top-level logging ID: component["id"]
// These are patterns Spotify sometimes uses in the logging IDs of ad components.
private let adLoggingIdKeywords: [String] = [
    "advertisement", "advertis",
    "sponsored", "sponsor",
    "promoted",
    "upsell",
    "billboard", "takeover",
    "interstitial",
    "marquee", "hpto", "dfp", "gam",
    "merch-",
    "rewarded", "offerwall",
    "native-ad", "display-ad",
    "video-ad", "audio-ad",
    "search-ad", "home-ad",
    "brand-ad", "brand_ad",
    "credit-karma", "creditkarma",
    "cartier",
]

// MARK: - Detection helpers

private func componentTypeIsAd(_ typeId: String) -> Bool {
    let lower = typeId.lowercased()
    if adComponentTypeIds.contains(lower) { return true }
    for kw in adTypeSubstrings {
        if lower.contains(kw) { return true }
    }
    return false
}

private func metaValueContainsAdSignal(_ value: Any) -> Bool {
    if let s = value as? String {
        let lower = s.lowercased()
        for kw in adMetaKeywords {
            if lower.contains(kw) { return true }
        }
        return false
    }
    if let dict = value as? [String: Any] {
        for (k, v) in dict {
            let lk = k.lowercased()
            for kw in adMetaKeywords {
                if lk.contains(kw) { return true }
            }
            if metaValueContainsAdSignal(v) { return true }
        }
    }
    if let arr = value as? [Any] {
        for v in arr {
            if metaValueContainsAdSignal(v) { return true }
        }
    }
    return false
}

private func shouldStripComponent(_ component: [String: Any]) -> Bool {

    // ── CHECK 1: component["component"]["id"]  ← THE KEY FIX ─────────────────
    // This is the authoritative component type in HubFramework JSON schema.
    // Format: "namespace:name" e.g. "spotify:ad-banner", "spotify:card"
    if let compDict = component["component"] as? [String: Any],
       let compTypeId = compDict["id"] as? String,
       componentTypeIsAd(compTypeId) {
        return true
    }

    // ── CHECK 2: component["component"]["category"] ───────────────────────────
    // Spotify uses "banner", "overlay", "interstitial" for ad components.
    // Only strip if there's a corroborating signal (avoid stripping real banners).
    if let compDict = component["component"] as? [String: Any],
       let category = compDict["category"] as? String {
        let lowerCat = category.lowercased()
        if adCategoryValues.contains(lowerCat) {
            // Require at least one more signal to confirm this is an ad
            let hasAdId = (component["id"] as? String).map { id in
                adLoggingIdKeywords.contains(where: { id.lowercased().contains($0) })
            } ?? false
            let hasAdMeta = ["metadata", "logging", "custom", "customData"].contains(where: { key in
                component[key].map { metaValueContainsAdSignal($0) } ?? false
            })
            if hasAdId || hasAdMeta { return true }
        }
    }

    // ── CHECK 3: component["id"] (logging/tracking ID) ────────────────────────
    // Spotify sometimes puts ad keywords in the logging ID.
    if let id = component["id"] as? String {
        let lower = id.lowercased()
        for kw in adLoggingIdKeywords {
            if lower.contains(kw) { return true }
        }
    }

    // ── CHECK 4: text fields ──────────────────────────────────────────────────
    // Ad components often have "Advertisement" as the title text.
    if let text = component["text"] as? [String: Any] {
        for (_, v) in text {
            if let s = v as? String {
                let lower = s.lowercased()
                if lower == "advertisement" || lower == "ad" || lower == "sponsored" {
                    return true
                }
            }
        }
    }

    // ── CHECK 5: Deep-scan metadata/logging/custom blobs ─────────────────────
    // Spotify buries ad identity in nested tracking/custom_data objects.
    for key in ["metadata", "logging", "custom", "customData", "tracking",
                "analytics", "impression_data", "impressionData",
                "event_data", "eventData", "payload", "data"] {
        if let v = component[key], metaValueContainsAdSignal(v) {
            return true
        }
    }

    // ── CHECK 6: URI field ────────────────────────────────────────────────────
    if let uri = component["uri"] as? String {
        let lower = uri.lowercased()
        if lower.contains("spotify:ad:") || lower.contains(":ad:") {
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
        for key in containerKeys {
            if let nested = component[key] as? [[String: Any]] {
                component[key] = filterComponents(nested)
            }
        }
        result.append(component)
    }
    return result
}

private func deepFilterValue(_ value: Any) -> Any {
    if var dict = value as? [String: Any] {
        if shouldStripComponent(dict) { return [String: Any]() }
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

        // Filter all known top-level container keys
        let topKeys = [
            "body", "sections", "items", "slots", "overlays",
            "rows", "cards", "modules", "blocks", "shelves",
            "components", "tiles", "entries", "cells",
        ]
        for key in topKeys {
            if let arr = dict[key] as? [[String: Any]] {
                dict[key] = filterComponents(arr)
            }
        }

        // Filter header and its children
        if var header = dict["header"] as? [String: Any] {
            if shouldStripComponent(header) {
                dict.removeValue(forKey: "header")
            } else {
                for key in containerKeys {
                    if let nested = header[key] as? [[String: Any]] {
                        header[key] = filterComponents(nested)
                    }
                }
                dict["header"] = header
            }
        }

        // Deep-filter all remaining keys (catches ads in non-standard containers)
        for key in dict.keys {
            if topKeys.contains(key) || key == "header" { continue }
            dict[key] = deepFilterValue(dict[key]!)
        }

        orig.addJSONDictionary(dict as NSDictionary)
    }
}

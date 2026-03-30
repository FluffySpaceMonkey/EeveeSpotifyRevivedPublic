import Foundation
import Orion

// Global variable for access token
public var spotifyAccessToken: String?

// Helper function to start capturing from other files
func DataLoaderServiceHooks_startCapturing() {
}

// MARK: - Hub JSON Ad Stripping
//
// This is the definitive fix for visual ads on Search and Home screens.
//
// WHY HubsAdBlocker (ClassHook on HUBViewModelBuilderImplementation) FAILS:
//   The class "HUBViewModelBuilderImplementation" does not exist in the Spotify
//   version(s) users are running. Orion's ClassHook silently does nothing when
//   the target class is missing. No amount of filtering logic in that hook helps.
//
// THE FIX:
//   Intercept the raw Hubs JSON response at the network level inside
//   SPTDataLoaderService (confirmed to exist in all versions). Detect hub
//   response URLs by path pattern, parse the JSON, strip all ad components,
//   and re-inject the cleaned data before it reaches any parser.
//
// HOW SPOTIFY DELIVERS SEARCH/HOME DISPLAY ADS:
//   Spotify fetches hub pages via spclient.wg.spotify.com paths like:
//     /hm/home/v3/...
//     /hm/search/v3/...
//     /hm/browse/v3/...
//     /hm/view/...
//   The response is a JSON dict with "body", "sections", "items" arrays
//   containing component objects. Ad components are identified by:
//     - component["component"]["id"]  e.g. "spotify:ad-banner"  ← PRIMARY
//     - component["text"]["title"] == "Advertisement"           ← SECONDARY
//     - component["id"] containing ad keywords                  ← TERTIARY
//     - Any string value anywhere in the component tree         ← DEEP SCAN

// MARK: - Ad component detection (shared with HubsAdBlocker)

private let adComponentTypeIds: Set<String> = [
    "spotify:ad", "spotify:ad-banner", "spotify:ad-card", "spotify:ad-row",
    "spotify:ad-carousel", "spotify:ad-header", "spotify:ad-overlay",
    "spotify:ad-interstitial", "spotify:ad-takeover", "spotify:ad-billboard",
    "spotify:ad-leaderboard", "spotify:ad-mrec", "spotify:ad-halfpage",
    "spotify:ad-skin", "spotify:ad-roadblock", "spotify:ad-wallpaper",
    "spotify:ad-expandable", "spotify:ad-video", "spotify:ad-audio",
    "spotify:ad-native", "spotify:ad-display", "spotify:ad-search",
    "spotify:ad-home", "spotify:ad-nowplaying",
    "spotify:sponsored", "spotify:sponsored-card", "spotify:sponsored-row",
    "spotify:sponsored-banner", "spotify:sponsored-content",
    "spotify:promoted", "spotify:promoted-card", "spotify:promoted-row",
    "spotify:upsell", "spotify:upsell-banner", "spotify:upsell-card",
    "spotify:upsell-row", "spotify:premium-upsell",
    "spotify:premium-upsell-banner", "spotify:premium-upsell-card",
    "spotify:marquee", "spotify:billboard", "spotify:hpto",
    "spotify:dfp", "spotify:gam", "spotify:takeover",
    "spotify:interstitial", "spotify:overlay", "spotify:banner",
    "spotify:rewarded", "spotify:offerwall", "spotify:brand-ad",
    "spotify:brand_ad", "spotify:merch", "spotify:ticket-upsell",
    "spotify:incentivized", "spotify:survey",
]

private let adTypeSubstrings: [String] = [
    ":ad", ":ad-", ":ad_", "ad:", "ads:",
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
]

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

private func shouldStripHubComponent(_ component: [String: Any]) -> Bool {
    // CHECK 1: component["component"]["id"] — the authoritative HubFramework type
    if let compDict = component["component"] as? [String: Any],
       let compTypeId = compDict["id"] as? String,
       componentTypeIsAd(compTypeId) {
        return true
    }

    // CHECK 2: component["component"]["category"]
    if let compDict = component["component"] as? [String: Any],
       let category = compDict["category"] as? String {
        let lowerCat = category.lowercased()
        let adCategories: Set<String> = [
            "ad", "ads", "advertisement", "sponsored", "promoted",
            "upsell", "premium-upsell", "billboard", "takeover",
            "interstitial", "overlay", "marquee", "hpto", "dfp", "gam",
            "rewarded", "offerwall",
        ]
        if adCategories.contains(lowerCat) { return true }
    }

    // CHECK 3: component["id"] (logging/tracking ID)
    if let id = component["id"] as? String {
        let lower = id.lowercased()
        for kw in adLoggingIdKeywords {
            if lower.contains(kw) { return true }
        }
    }

    // CHECK 4: text title == "Advertisement"
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

    // CHECK 5: deep-scan metadata/logging/custom blobs
    for key in ["metadata", "logging", "custom", "customData", "tracking",
                "analytics", "impression_data", "impressionData",
                "event_data", "eventData", "payload", "data",
                "custom_data", "customdata"] {
        if let v = component[key], metaValueContainsAdSignal(v) {
            return true
        }
    }

    // CHECK 6: URI field
    if let uri = component["uri"] as? String {
        let lower = uri.lowercased()
        if lower.contains("spotify:ad:") || lower.contains(":ad:") {
            return true
        }
    }

    return false
}

private let hubContainerKeys = [
    "children", "items", "content", "sections", "rows",
    "components", "slots", "tiles", "cards", "entries",
    "shelf", "shelves", "modules", "blocks", "cells",
]

private func filterHubComponents(_ components: [[String: Any]]) -> [[String: Any]] {
    var result = [[String: Any]]()
    for var component in components {
        if shouldStripHubComponent(component) { continue }
        for key in hubContainerKeys {
            if let nested = component[key] as? [[String: Any]] {
                component[key] = filterHubComponents(nested)
            } else if let nested = component[key] as? [Any] {
                component[key] = nested.compactMap { item -> Any? in
                    if let d = item as? [String: Any], shouldStripHubComponent(d) { return nil }
                    return deepFilterHubValue(item)
                }
            }
        }
        result.append(component)
    }
    return result
}

private func deepFilterHubValue(_ value: Any) -> Any {
    if var dict = value as? [String: Any] {
        if shouldStripHubComponent(dict) { return [String: Any]() }
        for key in dict.keys {
            if let nested = dict[key] as? [[String: Any]] {
                dict[key] = filterHubComponents(nested)
            } else if let nested = dict[key] as? [Any] {
                dict[key] = nested.compactMap { item -> Any? in
                    if let d = item as? [String: Any], shouldStripHubComponent(d) { return nil }
                    return deepFilterHubValue(item)
                }
            }
        }
        return dict
    }
    if let arr = value as? [[String: Any]] {
        return filterHubComponents(arr)
    }
    if let arr = value as? [Any] {
        return arr.compactMap { item -> Any? in
            if let d = item as? [String: Any], shouldStripHubComponent(d) { return nil }
            return deepFilterHubValue(item)
        }
    }
    return value
}

/// Strip all ad components from a raw Hubs JSON response Data.
/// Returns the cleaned Data, or nil if the data is not valid JSON or not a hub response.
func stripAdsFromHubJSON(_ data: Data) -> Data? {
    guard
        var dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
    else { return nil }

    var modified = false

    let topKeys = [
        "body", "sections", "items", "slots", "overlays",
        "rows", "cards", "modules", "blocks", "shelves",
        "components", "tiles", "entries", "cells",
    ]

    for key in topKeys {
        if let arr = dict[key] as? [[String: Any]] {
            let filtered = filterHubComponents(arr)
            if filtered.count != arr.count {
                dict[key] = filtered
                modified = true
            } else {
                dict[key] = filtered
            }
        }
    }

    // Filter header
    if var header = dict["header"] as? [String: Any] {
        if shouldStripHubComponent(header) {
            dict.removeValue(forKey: "header")
            modified = true
        } else {
            for key in hubContainerKeys {
                if let nested = header[key] as? [[String: Any]] {
                    let filtered = filterHubComponents(nested)
                    header[key] = filtered
                    modified = true
                }
            }
            dict["header"] = header
        }
    }

    // Deep-filter all remaining keys
    for key in dict.keys {
        if topKeys.contains(key) || key == "header" { continue }
        let filtered = deepFilterHubValue(dict[key]!)
        dict[key] = filtered
    }

    // Always re-serialize if we touched anything (even if count didn't change,
    // nested components may have been cleaned)
    guard let cleaned = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
        return nil
    }
    return cleaned
}

// MARK: - Hub URL detection
// Spotify delivers hub pages (Home, Search, Browse) via these spclient paths.
// We intercept these to strip ad components from the JSON before it's parsed.
private func isHubResponseURL(_ url: URL) -> Bool {
    let path = url.path.lowercased()
    let host = (url.host ?? "").lowercased()

    // Must be a Spotify API host
    guard host.contains("spotify.com") || host.contains("spclient") else { return false }

    // Hub page paths
    let hubPaths: [String] = [
        "/hm/home/",
        "/hm/search/",
        "/hm/browse/",
        "/hm/view/",
        "/hm/section/",
        "/hm/shelf/",
        "/hm/collection/",
        "/hm/user/",
        "/hm/artist/",
        "/hm/album/",
        "/hm/playlist/",
        "/hm/show/",
        "/hm/episode/",
        "/hm/audiobook/",
        "/hm/genre/",
        "/hm/mood/",
        "/hm/editorial/",
        "/hm/featured/",
        "/hm/new-releases/",
        "/hm/charts/",
        "/hm/concert/",
        "/hm/discover/",
        "/hm/made-for-you/",
        "/hm/recently-played/",
        "/hm/top-mixes/",
        "/hm/daily-mixes/",
        "/hm/radio/",
        "/hm/podcast/",
        "/hm/morning/",
        "/hm/evening/",
        "/hm/focus/",
        "/hm/workout/",
        "/hm/sleep/",
        "/hm/party/",
        "/hm/chill/",
        "/hm/",  // catch-all for any /hm/ path
    ]

    for hubPath in hubPaths {
        if path.hasPrefix(hubPath) || path.contains(hubPath) { return true }
    }

    return false
}

class SPTDataLoaderServiceHook: ClassHook<NSObject>, SpotifySessionDelegate {
    static let targetName = "SPTDataLoaderService"

    // orion:new
    static var cachedCustomizeData: Data?

    // orion:new
    static var handledCustomizeTasks = Set<Int>()

    // orion:new
    func shouldBlock(_ url: URL) -> Bool {
        let elapsed = Date().timeIntervalSince(tweakInitTime)
        
        // Always block: session destroy, token delete, and ALL ad-related requests
        if url.isDeleteToken
            || url.isSessionInvalidation
            || url.path.contains("session/purge")
            || url.path.contains("token/revoke")
            || url.isAdRelated {
            return true
        }

        // Block Spotify's ad-logic and ad-delivery endpoints by path fragment
        // (belt-and-suspenders: catches anything isAdRelated might miss)
        let pathLower = url.path.lowercased()
        let hostLower = (url.host ?? "").lowercased()
        let adPathFragments: [String] = [
            "/ads/", "/ad/", "/ad-logic/", "/adlogic/", "/ad_logic/",
            "/dfp/", "/hpto/", "/marquee/", "/gam/", "/gam-ad/",
            "/ad-slot/", "/ad-slots/", "/ad-inventory/", "/ad-targeting/",
            "/ad-decision/", "/ad-request/", "/ad-event/", "/ad-impression/",
            "/ad-click/", "/ad-tracking/", "/ad-measurement/",
            "/sponsored/", "/promoted/", "/billboard/", "/takeover/",
            "/interstitial/", "/native-ad/", "/display-ad/",
            "/video-ad/", "/audio-ad/", "/rewarded/", "/offerwall/",
        ]
        for fragment in adPathFragments {
            if pathLower.contains(fragment) { return true }
        }

        // Block known third-party ad network hosts entirely
        let adHosts: [String] = [
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "adservice.google.com", "moatads.com", "scorecardresearch.com",
            "omtrdc.net", "demdex.net", "ads.spotify.com", "adserver.spotify.com",
        ]
        for adHost in adHosts {
            if hostLower == adHost || hostLower.hasSuffix("." + adHost) { return true }
        }

        // Only block these after startup (30s) to allow initial login/initialization
        if elapsed > 30 {
            return url.isAccountValidate || url.isOndemandSelector
                || url.isTrialsFacade || url.isPremiumMarketing || url.isPendragonFetchMessageList
                || url.isPushkaTokens || url.path.contains("signup/public") || url.path.contains("apresolve")
                || url.path.contains("pses/screenconfig") || url.path.contains("bootstrap/v1/bootstrap")
        }
        
        return false
    }

    // orion:new
    func shouldModify(_ url: URL) -> Bool {
        let shouldPatchPremium = BasePremiumPatchingGroup.isActive
        let shouldReplaceLyrics = BaseLyricsGroup.isActive
        
        let isLyricsURL = url.isLyrics
        
        return (shouldReplaceLyrics && isLyricsURL)
            || (shouldPatchPremium && (url.isCustomize || url.isPremiumPlanRow || url.isPremiumBadge || url.isPlanOverview))
    }
    
    // orion:new
    func respondWithCustomData(_ data: Data, task: URLSessionDataTask, session: URLSession) {
        orig.URLSession(session, dataTask: task, didReceiveData: data)
    }

    // orion:new
    func handleBlockedEndpoint(_ url: URL, task: URLSessionDataTask, session: URLSession) {
        if url.isDeleteToken {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isAccountValidate {
            let response = "{\"status\":1,\"country\":\"US\",\"is_country_launched\":true}".data(using: .utf8)!
            respondWithCustomData(response, task: task, session: session)
        } else if url.isOndemandSelector {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isTrialsFacade {
            let response = "{\"result\":\"NOT_ELIGIBLE\"}".data(using: .utf8)!
            respondWithCustomData(response, task: task, session: session)
        } else if url.isPremiumMarketing {
            respondWithCustomData("{}".data(using: .utf8)!, task: task, session: session)
        } else if url.isPendragonFetchMessageList {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isPushkaTokens {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isSessionInvalidation || url.path.contains("session/purge") || url.path.contains("token/revoke") {
            // Return synthetic OK to prevent internal logout triggers
            respondWithCustomData("{\"status\":\"OK\"}".data(using: .utf8)!, task: task, session: session)
        } else if url.path.contains("signup/public") {
            respondWithCustomData("{\"status\":\"OK\"}".data(using: .utf8)!, task: task, session: session)
        } else if url.path.contains("apresolve") {
            respondWithCustomData("{\"status\":\"OK\"}".data(using: .utf8)!, task: task, session: session)
        } else if url.path.contains("pses/screenconfig") {
            respondWithCustomData("{}".data(using: .utf8)!, task: task, session: session)
        } else if url.path.contains("bootstrap/v1/bootstrap") {
            respondWithCustomData("{}".data(using: .utf8)!, task: task, session: session)
        } else {
            // All ad-related and unknown blocked URLs → empty response
            respondWithCustomData(Data(), task: task, session: session)
        }
        orig.URLSession(session, task: task, didCompleteWithError: nil)
    }
    
    func URLSession(
        _ session: URLSession,
        task: URLSessionDataTask,
        didCompleteWithError error: Error?
    ) {
        // Capture authorization token from any request
        if let request = task.currentRequest,
           let headers = request.allHTTPHeaderFields,
           let auth = headers["Authorization"] ?? headers["authorization"],
           auth.hasPrefix("Bearer ") {
            spotifyAccessToken = String(auth.dropFirst(7))
        }
	
        guard let url = task.currentRequest?.url else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }

        // Handle blocked endpoints (session protection + ad blocking)
        if shouldBlock(url) {
            handleBlockedEndpoint(url, task: task, session: session)
            return
        }

        // Handle customize 304 that was already served in didReceiveResponse
        if SPTDataLoaderServiceHook.handledCustomizeTasks.remove(task.taskIdentifier) != nil {
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }

        // ── HUB JSON AD STRIPPING ─────────────────────────────────────────────────
        // If this is a hub page response (Home/Search/Browse), strip ad components
        // from the JSON before it reaches the app's parser. This is the definitive
        // fix for visual display ads that bypass HUBViewModelBuilderImplementation.
        if error == nil,
           BasePremiumPatchingGroup.isActive,
           isHubResponseURL(url),
           let buffer = URLSessionHelper.shared.obtainData(for: url),
           let cleaned = stripAdsFromHubJSON(buffer) {
            respondWithCustomData(cleaned, task: task, session: session)
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }
        // ─────────────────────────────────────────────────────────────────────────

        guard error == nil, shouldModify(url) else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }
        
        guard let buffer = URLSessionHelper.shared.obtainData(for: url) else {
            // Customize 304 fallback: serve cached modified data when no buffer available
            if url.isCustomize, let cached = SPTDataLoaderServiceHook.cachedCustomizeData {
                respondWithCustomData(cached, task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
            }
            return
        }
        
        do {
            if url.isLyrics {
                let originalLyrics = try? Lyrics(serializedBytes: buffer)
                
                // Try to fetch custom lyrics with a timeout
                let semaphore = DispatchSemaphore(value: 0)
                var customLyricsData: Data?
                
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        customLyricsData = try getLyricsDataForCurrentTrack(
                            url.path,
                            originalLyrics: originalLyrics
                        )
                    } catch {
                    }
                    semaphore.signal()
                }
                
                // Wait up to 5 seconds for custom lyrics
                let timeout = DispatchTime.now() + .milliseconds(5000)
                let result = semaphore.wait(timeout: timeout)
                
                if result == .success, let data = customLyricsData {
                    respondWithCustomData(data, task: task, session: session)
                    orig.URLSession(session, task: task, didCompleteWithError: nil)
                } else {
                    respondWithCustomData(buffer, task: task, session: session)
                    orig.URLSession(session, task: task, didCompleteWithError: nil)
                }
                return
            }
            
            if url.isPremiumPlanRow {
                respondWithCustomData(
                    try getPremiumPlanRowData(
                        originalPremiumPlanRow: try PremiumPlanRow(serializedBytes: buffer)
                    ),
                    task: task,
                    session: session
                )
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
            
            if url.isPremiumBadge {
                respondWithCustomData(try getPremiumPlanBadge(), task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
            
            if url.isCustomize {
                var customizeMessage = try CustomizeMessage(serializedBytes: buffer)
                modifyRemoteConfiguration(&customizeMessage.response)
                let modifiedData = try customizeMessage.serializedData()
                SPTDataLoaderServiceHook.cachedCustomizeData = modifiedData
                respondWithCustomData(modifiedData, task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
            
            if url.isPlanOverview {
                respondWithCustomData(try getPlanOverviewData(), task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
        }
        catch {
            orig.URLSession(session, task: task, didCompleteWithError: error)
        }
    }

    func URLSession(
        _ session: URLSession,
        dataTask task: URLSessionDataTask,
        didReceiveResponse response: HTTPURLResponse,
        completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        // Block ad responses at the HTTP response level — cancel before data arrives
        if let url = task.currentRequest?.url, shouldBlock(url) {
            handler(.cancel)
            return
        }

        // Handle customize 304 — prevent free-account data leaking from URLSession cache
        if let url = task.currentRequest?.url, url.isCustomize, response.statusCode == 304 {
            if let cached = SPTDataLoaderServiceHook.cachedCustomizeData {
                let fakeResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:])!
                orig.URLSession(session, dataTask: task, didReceiveResponse: fakeResponse, completionHandler: handler)
                respondWithCustomData(cached, task: task, session: session)
                SPTDataLoaderServiceHook.handledCustomizeTasks.insert(task.taskIdentifier)
                return
            }
        }

        guard
            let url = task.currentRequest?.url,
            url.isLyrics,
            response.statusCode != 200
        else {
            orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
            return
        }

        do {
            let data = try getLyricsDataForCurrentTrack(url.path)
            let okResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:])!
            
            orig.URLSession(session, dataTask: task, didReceiveResponse: okResponse, completionHandler: handler)
            respondWithCustomData(data, task: task, session: session)
        } catch {
            orig.URLSession(session, task: task, didCompleteWithError: error)
        }
    }

    func URLSession(
        _ session: URLSession,
        dataTask task: URLSessionDataTask,
        didReceiveData data: Data
    ) {
        guard let url = task.currentRequest?.url else {
            return
        }

        // Suppress data for blocked endpoints (prevent original data from reaching handler)
        if shouldBlock(url) {
            return
        }

        // Buffer hub responses so we can strip ads in didCompleteWithError
        if BasePremiumPatchingGroup.isActive && isHubResponseURL(url) {
            URLSessionHelper.shared.setOrAppend(data, for: url)
            return
        }

        if shouldModify(url) {
            URLSessionHelper.shared.setOrAppend(data, for: url)
            return
        }

        orig.URLSession(session, dataTask: task, didReceiveData: data)
    }
}

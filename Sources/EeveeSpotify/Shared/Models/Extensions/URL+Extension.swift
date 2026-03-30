import Foundation

extension URL {
    var isLyrics: Bool {
        self.path.contains("color-lyrics/v2")
    }
    
    var isPlanOverview: Bool {
        self.path.contains("GetPlanOverview")
    }
    
    var isShuffle: Bool {
        self.path.contains("shuffle")
    }
    
    var isPremiumPlanRow: Bool {
        self.path.contains("v1/GetPremiumPlanRow")
    }
    
    var isPremiumBadge: Bool {
        self.path.contains("GetYourPremiumBadge")
    }

    var isOpenSpotifySafariExtension: Bool {
        self.host == "eevee"
    }
    
    var isCustomize: Bool {
        self.path.contains("v1/customize")
    }
    
    var isBootstrap: Bool {
        self.path.contains("v1/bootstrap")
    }

    // Blocked endpoint matchers (session protection)

    var isDeleteToken: Bool {
        self.path.contains("DeleteToken")
    }

    var isAccountValidate: Bool {
        self.path.contains("signup/public")
    }

    var isOndemandSelector: Bool {
        self.path.contains("select-ondemand-set")
    }

    var isTrialsFacade: Bool {
        self.path.contains("trials-facade/start-trial")
    }

    var isPremiumMarketing: Bool {
        self.path.contains("premium-marketing/upsellOffer")
    }

    var isPendragonFetchMessageList: Bool {
        self.path.contains("pendragon") && self.path.contains("FetchMessageList")
    }

    var isPushkaTokens: Bool {
        self.path.contains("pushka-tokens")
    }

    // MARK: - Ad-related URL detection
    // Covers Spotify's own ad delivery infrastructure plus third-party ad networks.
    var isAdRelated: Bool {
        let path = self.path.lowercased()
        let host = (self.host ?? "").lowercased()
        let fullURL = self.absoluteString.lowercased()

        // ── Third-party ad network hosts ──────────────────────────────────────────
        let adHosts: [String] = [
            "doubleclick.net",
            "googlesyndication.com",
            "googleadservices.com",
            "adservice.google.com",
            "moatads.com",
            "scorecardresearch.com",
            "omtrdc.net",
            "demdex.net",
            "ads.spotify.com",
            "adserver.spotify.com",
        ]
        for adHost in adHosts {
            if host == adHost || host.hasSuffix("." + adHost) {
                return true
            }
        }

        // ── Spotify spclient ad-delivery paths ────────────────────────────────────
        // spclient.wg.spotify.com is the main Spotify API gateway.
        // Ad-specific sub-paths on it must be blocked while leaving other API calls intact.
        if host.contains("spclient") {
            let spAdPaths: [String] = [
                "/ads/",
                "/ad-logic/",
                "/ad_logic/",
                "/adlogic/",
                "/dfp/",
                "/hpto/",
                "/marquee/",
                "/gam/",
                "/ad-decision/",
                "/ad-request/",
                "/ad-slot/",
                "/ad-slots/",
                "/ad-inventory/",
                "/ad-targeting/",
                "/ad-event/",
                "/ad-impression/",
                "/ad-click/",
                "/ad-tracking/",
                "/ad-measurement/",
                "/sponsored/",
                "/promoted/",
                "/campaign/",
                "/billboard/",
                "/takeover/",
                "/interstitial/",
            ]
            for p in spAdPaths {
                if path.contains(p) { return true }
            }
        }

        // ── Generic Spotify ad path segments ─────────────────────────────────────
        // These appear on any Spotify domain (api.spotify.com, etc.)
        let genericAdPaths: [String] = [
            "/ads/",
            "/ad/",
            "/ad-logic/",
            "/ad_logic/",
            "/adlogic/",
            "/dfp/",
            "/hpto/",
            "/marquee/",
            "/gam-ad/",
            "/ad-slot/",
            "/ad-slots/",
            "/ad-inventory/",
            "/ad-targeting/",
            "/ad-decision/",
            "/ad-request/",
            "/ad-event/",
            "/ad-impression/",
            "/ad-click/",
            "/ad-tracking/",
            "/ad-measurement/",
            "/advert/",
            "/adverts/",
            "/advertising/",
            "/sponsored/",
            "/promoted/",
            "/upsell/",
            "/upsells/",
            "/campaign/",
            "/campaigns/",
            "/billboard/",
            "/billboards/",
            "/banner/",
            "/banners/",
            "/interstitial/",
            "/interstitials/",
            "/overlay/",
            "/overlays/",
            "/popup/",
            "/pop-up/",
            "/takeover/",
            "/takeovers/",
            "/native-ad/",
            "/display-ad/",
            "/video-ad/",
            "/audio-ad/",
            "/rewarded/",
            "/offerwall/",
            "/search-ad/",
            "/search-ads/",
            "/home-ad/",
            "/home-ads/",
        ]
        for p in genericAdPaths {
            if path.contains(p) { return true }
        }

        // ── Hostname substring matches (catch CDN variants) ───────────────────────
        let adHostSubstrings: [String] = [
            "doubleclick",
            "googlesyndication",
            "adservice.google",
            "moatads",
            "scorecardresearch",
        ]
        for s in adHostSubstrings {
            if host.contains(s) { return true }
        }

        // ── Spotify URI scheme ad detection ───────────────────────────────────────
        if fullURL.hasPrefix("spotify:ad:") { return true }

        return false
    }

    // Additional session protection endpoints
    var isSessionInvalidation: Bool {
        self.path.contains("logout") || self.path.contains("sign-out") ||
        self.path.contains("session/purge") || self.path.contains("token/revoke") ||
        self.path.contains("auth/expire") ||
        (self.path.contains("melody") && self.path.contains("check")) ||
        self.path.contains("product-state") ||
        (self.path.contains("license") && self.path.contains("check"))
    }
}

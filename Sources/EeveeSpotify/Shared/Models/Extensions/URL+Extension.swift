import Foundation

extension URL {
    var isDeleteToken: Bool {
        self.path.contains("login5") && self.path.contains("delete")
    }
    var isLyrics: Bool {
        self.path.contains("color-lyrics") || self.path.contains("lyrics")
    }
    var isCustomize: Bool {
        self.path.contains("user-customization-service") && self.path.contains("customize")
    }
    var isPremiumPlanRow: Bool {
        self.path.contains("premium-plan-row")
    }
    var isPremiumBadge: Bool {
        self.path.contains("premium-badge")
    }
    var isPlanOverview: Bool {
        self.path.contains("plan-overview")
    }
    var isAccountValidate: Bool {
        self.path.contains("melody/v1/check_eligibility") ||
        (self.path.contains("account") && self.path.contains("validate"))
    }
    var isOndemandSelector: Bool {
        self.path.contains("ondemand-selector")
    }
    var isTrialsFacade: Bool {
        self.path.contains("trials-facade")
    }
    var isPremiumMarketing: Bool {
        self.path.contains("premium-marketing")
    }
    var isPendragonFetchMessageList: Bool {
        self.path.contains("pendragon") && self.path.contains("FetchMessageList")
    }
    var isPushkaTokens: Bool {
        self.path.contains("pushka-tokens")
    }

    // MARK: - Ad-related URL detection
    //
    // Covers Spotify's own ad delivery infrastructure plus third-party ad networks.
    //
    // Confirmed by binary analysis of Spotify 9.1.32 decrypted IPA:
    //   - Esperanto gRPC service: spotify.ads.esperanto.proto.*
    //     Paths: /.spotify.ads.esperanto.proto.TriggerSlotRequest
    //            /.spotify.ads.esperanto.proto.PrepareSlotRequest
    //            /.spotify.ads.esperanto.proto.CreateSlotResponse
    //            /.spotify.ads.esperanto.proto.PostEventV2Request
    //            /.spotify.ads.esperanto.proto.SubInStreamRequest
    //            /.spotify.ads.esperanto.proto.UpdateSlotResponse
    //            /.spotify.ads.esperanto.proto.AddPlaytimeRequest
    //   - Brand ads: spotify.ads.brandads.v1.EmbeddedAd / EmbeddedAdMetadata
    //   - Browse ads: spotify.ads.browseads.v2.BrowseAd / BrowseAdMetadata
    //   - Casita proto ad types: ImageBrandAd, VideoBrandAd, PromotionV1/V3
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
            "pubads.g.doubleclick.net",
            "securepubads.g.doubleclick.net",
            "pagead2.googlesyndication.com",
            "tpc.googlesyndication.com",
            "cm.g.doubleclick.net",
            "stats.g.doubleclick.net",
            "ad.doubleclick.net",
            "googleads.g.doubleclick.net",
        ]
        for adHost in adHosts {
            if host == adHost || host.hasSuffix("." + adHost) {
                return true
            }
        }

        // ── Spotify Esperanto ad service (confirmed in binary) ────────────────────
        // The Esperanto service delivers in-stream and display ad slots via gRPC.
        // The gRPC method paths contain "spotify.ads.esperanto.proto".
        if fullURL.contains("spotify.ads.esperanto.proto") {
            return true
        }

        // ── Spotify spclient ad-delivery paths ────────────────────────────────────
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
                // Esperanto ad service sub-paths on spclient
                "/esperanto/ads",
                "/ads/esperanto",
            ]
            for p in spAdPaths {
                if path.contains(p) { return true }
            }
        }

        // ── Generic Spotify ad path segments ─────────────────────────────────────
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

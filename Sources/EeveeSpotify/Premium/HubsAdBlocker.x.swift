import Orion
import Foundation

// MARK: - HubsAdBlocker
//
// This hook targets HUBViewModelBuilderImplementation (confirmed present in
// Spotify 9.1.32 binary) and strips ad components from hub JSON before
// the view model is built.
//
// The PRIMARY fix for visual ads is in AdViewBlocker.x.swift which hooks
// the actual ad view classes. This file is a belt-and-suspenders second layer.
//
// The hub JSON stripping logic is also used by DataLoaderServiceHooks.x.swift
// at the network level (see stripAdsFromHubJSON / isHubResponseURL there).

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

        // Strip ads using the shared stripAdsFromHubJSON logic.
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let cleaned = stripAdsFromHubJSON(data),
           let cleanedDict = (try? JSONSerialization.jsonObject(with: cleaned, options: [])) as? [String: Any] {
            orig.addJSONDictionary(cleanedDict as NSDictionary)
        } else {
            orig.addJSONDictionary(dict as NSDictionary)
        }
    }
}

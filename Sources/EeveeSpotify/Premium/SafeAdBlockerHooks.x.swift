import Orion
import UIKit

// MARK: - Dummy Classes for Safe Fallback
// These ensure Orion never crashes if a Spotify class is missing in a specific version.
@objc(EeveeDummyView)
class EeveeDummyView: UIView {}

@objc(EeveeDummyViewController)
class EeveeDummyViewController: UIViewController {}

// MARK: - Display Ad Card (Search & Home Banners)
class DisplayAdCardElementUIHook: ClassHook<UIView> {
    typealias Group = BasePremiumPatchingGroup
    static var targetName: String {
        if NSClassFromString("_TtC22AdsPlatform_ElementKit22DisplayAdCardElementUI") != nil {
            return "_TtC22AdsPlatform_ElementKit22DisplayAdCardElementUI"
        }
        return "EeveeDummyView"
    }

    func layoutSubviews() {
        orig.layoutSubviews()
        if !target.isHidden {
            target.isHidden = true
        }
        if target.frame.size.height != 0 {
            target.frame = .zero
        }
    }
}

// MARK: - Fullbleed Display Ad
class FullbleedDisplayAdElementUIHook: ClassHook<UIView> {
    typealias Group = BasePremiumPatchingGroup
    static var targetName: String {
        if NSClassFromString("_TtC22AdsPlatform_ElementKit27FullbleedDisplayAdElementUI") != nil {
            return "_TtC22AdsPlatform_ElementKit27FullbleedDisplayAdElementUI"
        }
        return "EeveeDummyView"
    }

    func layoutSubviews() {
        orig.layoutSubviews()
        if !target.isHidden {
            target.isHidden = true
        }
        if target.frame.size.height != 0 {
            target.frame = .zero
        }
    }
}

// MARK: - SPTBannerView
class SPTBannerViewHook: ClassHook<UIView> {
    typealias Group = BasePremiumPatchingGroup
    static var targetName: String {
        if NSClassFromString("SPTBannerView") != nil {
            return "SPTBannerView"
        }
        return "EeveeDummyView"
    }

    func layoutSubviews() {
        orig.layoutSubviews()
        if !target.isHidden {
            target.isHidden = true
        }
        if target.frame.size.height != 0 {
            target.frame = .zero
        }
    }
}

// MARK: - Marquee Classic Overlay
class MarqueeClassicContentViewControllerHook: ClassHook<UIViewController> {
    typealias Group = BasePremiumPatchingGroup
    static var targetName: String {
        if NSClassFromString("_TtC19Marquee_MarqueeImpl35MarqueeClassicContentViewController") != nil {
            return "_TtC19Marquee_MarqueeImpl35MarqueeClassicContentViewController"
        }
        return "EeveeDummyViewController"
    }

    func viewWillAppear(_ animated: Bool) {
        orig.viewWillAppear(animated)
        target.dismiss(animated: false, completion: nil)
    }
}

// MARK: - Marquee Prerelease Overlay
class MarqueePrereleaseContentViewControllerHook: ClassHook<UIViewController> {
    typealias Group = BasePremiumPatchingGroup
    static var targetName: String {
        if NSClassFromString("_TtC19Marquee_MarqueeImpl38MarqueePrereleaseContentViewController") != nil {
            return "_TtC19Marquee_MarqueeImpl38MarqueePrereleaseContentViewController"
        }
        return "EeveeDummyViewController"
    }

    func viewWillAppear(_ animated: Bool) {
        orig.viewWillAppear(animated)
        target.dismiss(animated: false, completion: nil)
    }
}

// MARK: - Ad On App Open Overlay
class AdOnAppOpenViewControllerHook: ClassHook<UIViewController> {
    typealias Group = BasePremiumPatchingGroup
    static var targetName: String {
        if NSClassFromString("AdOnAppOpenViewController") != nil {
            return "AdOnAppOpenViewController"
        }
        return "EeveeDummyViewController"
    }

    func viewWillAppear(_ animated: Bool) {
        orig.viewWillAppear(animated)
        target.dismiss(animated: false, completion: nil)
    }
}

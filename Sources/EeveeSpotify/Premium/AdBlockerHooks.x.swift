import Orion
import Foundation
import UIKit

// MARK: - Ad View Controllers and Views

class MarqueeContentViewControllerHook: ClassHook<UIViewController> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName = "MarqueeContentViewController"
    
    func viewDidLoad() {
        orig.viewDidLoad()
        target.view.isHidden = true
        target.view.alpha = 0
        target.view.frame = .zero
    }
    
    func viewWillAppear(_ animated: Bool) {
        orig.viewWillAppear(animated)
        target.dismiss(animated: false, completion: nil)
    }
}

class MarqueeClassicContentViewControllerHook: ClassHook<UIViewController> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName = "MarqueeClassicContentViewController"
    
    func viewDidLoad() {
        orig.viewDidLoad()
        target.view.isHidden = true
        target.view.alpha = 0
        target.view.frame = .zero
    }
    
    func viewWillAppear(_ animated: Bool) {
        orig.viewWillAppear(animated)
        target.dismiss(animated: false, completion: nil)
    }
}

class LeaveBehindViewModelHook: ClassHook<NSObject> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName = "LeaveBehindViewModel"
    
    func shouldShowLeaveBehind() -> Bool {
        return false
    }
}

class DisplayAdCardElementHook: ClassHook<UIView> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName = "DisplayAdCardElement"
    
    func initWithFrame(_ frame: CGRect) -> UIView {
        let view = orig.initWithFrame(.zero)
        view.isHidden = true
        view.alpha = 0
        return view
    }
    
    func layoutSubviews() {
        orig.layoutSubviews()
        target.isHidden = true
        target.frame = .zero
    }
}

class FullbleedDisplayAdElementUIHook: ClassHook<UIView> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName = "AdsPlatform_ElementKit.FullbleedDisplayAdElementUI"
    
    func initWithFrame(_ frame: CGRect) -> UIView {
        let view = orig.initWithFrame(.zero)
        view.isHidden = true
        view.alpha = 0
        return view
    }
    
    func layoutSubviews() {
        orig.layoutSubviews()
        target.isHidden = true
        target.frame = .zero
    }
}

class SPTBannerViewHook: ClassHook<UIView> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName = "SPTBannerView"
    
    func initWithFrame(_ frame: CGRect) -> UIView {
        let view = orig.initWithFrame(.zero)
        view.isHidden = true
        view.alpha = 0
        return view
    }
    
    func layoutSubviews() {
        orig.layoutSubviews()
        target.isHidden = true
        target.frame = .zero
    }
}

class SPTBannerViewControllerHook: ClassHook<UIViewController> {
    typealias Group = BasePremiumPatchingGroup
    static let targetName = "SPTBannerViewController"
    
    func viewDidLoad() {
        orig.viewDidLoad()
        target.view.isHidden = true
        target.view.alpha = 0
        target.view.frame = .zero
    }
    
    func viewWillAppear(_ animated: Bool) {
        orig.viewWillAppear(animated)
        target.dismiss(animated: false, completion: nil)
    }
}

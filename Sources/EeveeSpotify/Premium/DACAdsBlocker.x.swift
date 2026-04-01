import Orion
import Foundation

// DAC (Data-driven Accessory Components) is the newer framework replacing HUB in some areas.
// Components are often Protobuf-based.

struct DACAdBlockerGroup: HookGroup { }

class DACAdsBlocker: ClassHook<NSObject> {
    typealias Group = DACAdBlockerGroup
    static let targetName: String = "DACIntegrationServiceImpl"

    // This method is likely responsible for creating a view/renderer for a DAC component.
    // By returning nil for ad components, we can prevent them from being rendered.
    func rendererForComponent(_ component: NSObject) -> Any? {
        
        let componentClassName = NSStringFromClass(type(of: component))
        
        // Check for known ad-related DAC components
        if componentClassName.contains("UpgradeComponent") || 
           componentClassName.contains("AdComponent") ||
           componentClassName.contains("Upsell") {
            return nil
        }
        
        // Most DAC components have a "model" or "data" property that contains the actual content.
        // We can check if that content contains ad-related strings.
        if component.responds(to: Selector(("model"))) {
            if let model = component.value(forKey: "model") as? NSObject {
                let modelDescription = model.description.lowercased()
                if modelDescription.contains("ad-card") || 
                   modelDescription.contains("sponsored") ||
                   modelDescription.contains("upsell") {
                    return nil
                }
            }
        }
        
        // Also check "componentInstanceInfo" which often contains the component ID/type
        if component.responds(to: Selector(("componentInstanceInfo"))) {
            if let info = component.value(forKey: "componentInstanceInfo") as? NSObject {
                let infoDescription = info.description.lowercased()
                if infoDescription.contains("ad-card") || 
                   infoDescription.contains("sponsored") ||
                   infoDescription.contains("upsell") {
                    return nil
                }
            }
        }

        return orig.rendererForComponent(component)
    }
}

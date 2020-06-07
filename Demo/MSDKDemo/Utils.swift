import UIKit

class Utils: NSObject {

    static func SDKVersion() -> String? {
        if let path = Bundle.main.path(forResource: "OPPWAMobile-Resources.bundle/version", ofType: "plist") {
            if let versionDict = NSDictionary(contentsOfFile: path) as? [String: String] {
                return versionDict["OPPVersion"]
            }
        }
        return ""
    }
    
    static func amountAsString() -> String {
        return String(format: "%.2f", Config.amount) + " " + Config.currency
    }
    
    static func showResult(presenter: UIViewController, success: Bool, message: String?) {
        let title = success ? "Success" : "Failure"
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        presenter.present(alert, animated: true, completion: nil)
    }
    
    static func configureCheckoutSettings() -> OPPCheckoutSettings {
        let checkoutSettings = OPPCheckoutSettings.init()
        checkoutSettings.paymentBrands = Config.checkoutPaymentBrands
        checkoutSettings.shopperResultURL = Config.urlScheme + "://payment"
        
        checkoutSettings.theme.navigationBarBackgroundColor = Config.mainColor
        checkoutSettings.theme.confirmationButtonColor = Config.mainColor
        checkoutSettings.theme.accentColor = Config.mainColor
        checkoutSettings.theme.cellHighlightedBackgroundColor = Config.mainColor
        checkoutSettings.theme.sectionBackgroundColor = Config.mainColor.withAlphaComponent(0.05)
        
        return checkoutSettings
    }
}

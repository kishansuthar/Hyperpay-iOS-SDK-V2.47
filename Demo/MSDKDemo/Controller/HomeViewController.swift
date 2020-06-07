import UIKit

class HomeViewController: UIViewController {
    @IBOutlet var versionLabel: UILabel!
    
    // MARK: - Life cycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let version = Utils.SDKVersion() {
            self.versionLabel.text = "mobile SDK v" + version
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

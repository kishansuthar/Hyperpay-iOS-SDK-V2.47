import UIKit

class CheckoutViewController: UIViewController, OPPCheckoutProviderDelegate {
    @IBOutlet var amountLabel: UILabel!
    @IBOutlet var checkoutButton: UIButton!
    @IBOutlet var processingView: UIActivityIndicatorView!
    
    var checkoutProvider: OPPCheckoutProvider?
    var transaction: OPPTransaction?
    
    // MARK: - Life cycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Ready-to-use UI"
        self.amountLabel.text = Utils.amountAsString()
    }
    
    // MARK: - Action methods
    
    @IBAction func checkoutButtonAction(_ sender: UIButton) {
        self.processingView.startAnimating()
        sender.isEnabled = false
        Request.requestCheckoutID(amount: Config.amount, currency: Config.currency, completion: {(checkoutID) in
            
            DispatchQueue.main.async {
                self.processingView.stopAnimating()
                sender.isEnabled = true
                
                guard let checkoutID = checkoutID else {
                    Utils.showResult(presenter: self, success: false, message: "Checkout ID is empty")
                    return
                }
                
                self.checkoutProvider = self.configureCheckoutProvider(checkoutID: checkoutID)
                self.checkoutProvider?.delegate = self
                self.checkoutProvider?.presentCheckout(forSubmittingTransactionCompletionHandler: { (transaction, error) in
                    DispatchQueue.main.async {
                        self.handleTransactionSubmission(transaction: transaction, error: error)
                    }
                }, cancelHandler: nil)
            }
        })
    }
    
    // MARK: - OPPCheckoutProviderDelegate methods
    
    // This method is called right before submitting a transaction to the Server.
    func checkoutProvider(_ checkoutProvider: OPPCheckoutProvider, continueSubmitting transaction: OPPTransaction, completion: @escaping (String?, Bool) -> Void) {
        // To continue submitting you should call completion block which expects 2 parameters:
        // checkoutID - you can create new checkoutID here or pass current one
        // abort - you can abort transaction here by passing 'true'
        completion(transaction.paymentParams.checkoutID, false)
    }
    
    // MARK: - Payment helpers
    
    func handleTransactionSubmission(transaction: OPPTransaction?, error: Error?) {
        guard let transaction = transaction else {
            Utils.showResult(presenter: self, success: false, message: error?.localizedDescription)
            return
        }
        
        self.transaction = transaction
        if transaction.type == .synchronous {
            // If a transaction is synchronous, just request the payment status
            self.requestPaymentStatus()
        } else if transaction.type == .asynchronous {
            // If a transaction is asynchronous, SDK opens transaction.redirectUrl in a browser
            // Subscribe to notifications to request the payment status when a shopper comes back to the app
            NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveAsynchronousPaymentCallback), name: Notification.Name(rawValue: Config.asyncPaymentCompletedNotificationKey), object: nil)
        } else {
            Utils.showResult(presenter: self, success: false, message: "Invalid transaction")
        }
    }
    
    func configureCheckoutProvider(checkoutID: String) -> OPPCheckoutProvider? {
        let provider = OPPPaymentProvider.init(mode: .test)
        let checkoutSettings = Utils.configureCheckoutSettings()
        checkoutSettings.storePaymentDetails = .prompt
        return OPPCheckoutProvider.init(paymentProvider: provider, checkoutID: checkoutID, settings: checkoutSettings)
    }
    
    func requestPaymentStatus() {
        guard let resourcePath = self.transaction?.resourcePath else {
            Utils.showResult(presenter: self, success: false, message: "Resource path is invalid")
            return
        }
        
        self.transaction = nil
        self.processingView.startAnimating()
        Request.requestPaymentStatus(resourcePath: resourcePath) { (success) in
            DispatchQueue.main.async {
                self.processingView.stopAnimating()
                let message = success ? "Your payment was successful" : "Your payment was not successful"
                Utils.showResult(presenter: self, success: success, message: message)
            }
        }
    }
    
    // MARK: - Async payment callback
    
    @objc func didReceiveAsynchronousPaymentCallback() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: Config.asyncPaymentCompletedNotificationKey), object: nil)
        self.checkoutProvider?.dismissCheckout(animated: true) {
            DispatchQueue.main.async {
                self.requestPaymentStatus()
            }
        }
    }
}

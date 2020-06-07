import UIKit
import SafariServices

enum CardParamsError: Error {
    case invalidParam(String)
}

class CustomUIViewController: UIViewController, SFSafariViewControllerDelegate {
    @IBOutlet var holderTextField: UITextField!
    @IBOutlet var numberTextField: UITextField!
    @IBOutlet var expiryMonthTextField: UITextField!
    @IBOutlet var expiryYearTextField: UITextField!
    @IBOutlet var cvvTextField: UITextField!
    @IBOutlet var processingView: UIActivityIndicatorView!
    @IBOutlet var cardBrandLabel: UILabel!
    
    var provider: OPPPaymentProvider?
    var transaction: OPPTransaction?
    var safariVC: SFSafariViewController?
    
    // MARK: - Life cycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "SDK & your own UI"
        self.cardBrandLabel.text = Config.cardBrand
        self.holderTextField.text = Config.cardHolder
        self.numberTextField.text = Config.cardNumber
        self.expiryMonthTextField.text = Config.cardExpiryMonth
        self.expiryYearTextField.text = Config.cardExpiryYear
        self.cvvTextField.text = Config.cardCVV
        
        self.provider = OPPPaymentProvider.init(mode: .test)
    }
    
    // MARK: - Action methods
    
    @IBAction func payButtonAction(_ sender: Any) {
        do {
            try self.validateFields()
        } catch CardParamsError.invalidParam(let reason) {
            Utils.showResult(presenter: self, success: false, message: reason)
            return
        } catch {
            Utils.showResult(presenter: self, success: false, message: "Parameters are invalid")
            return
        }
        
        self.view.endEditing(true)
        self.processingView.startAnimating()
        Request.requestCheckoutID(amount: Config.amount, currency: Config.currency) { (checkoutID) in
            DispatchQueue.main.async {
                guard let checkoutID = checkoutID else {
                    self.processingView.stopAnimating()
                    Utils.showResult(presenter: self, success: false, message: "Checkout ID is empty")
                    return
                }
                
                guard let transaction = self.createTransaction(checkoutID: checkoutID) else {
                    self.processingView.stopAnimating()
                    return
                }
                
                self.provider!.submitTransaction(transaction, completionHandler: { (transaction, error) in
                    DispatchQueue.main.async {
                        self.processingView.stopAnimating()
                        self.handleTransactionSubmission(transaction: transaction, error: error)
                    }
                })
            }
        }
    }
    
    // MARK: - Payment helpers
    
    func createTransaction(checkoutID: String) -> OPPTransaction? {
        do {
            let params = try OPPCardPaymentParams.init(checkoutID: checkoutID, paymentBrand: Config.cardBrand, holder: self.holderTextField.text!, number: self.numberTextField.text!, expiryMonth: self.expiryMonthTextField.text!, expiryYear: self.expiryYearTextField.text!, cvv: self.cvvTextField.text!)
            params.shopperResultURL = Config.urlScheme + "://payment"
            return OPPTransaction.init(paymentParams: params)
        } catch let error as NSError {
            Utils.showResult(presenter: self, success: false, message: error.localizedDescription)
            return nil
        }
    }
    
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
            // If a transaction is asynchronous, you should open transaction.redirectUrl in a browser
            // Subscribe to notifications to request the payment status when a shopper comes back to the app
            NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveAsynchronousPaymentCallback), name: Notification.Name(rawValue: Config.asyncPaymentCompletedNotificationKey), object: nil)
            self.presenterURL(url: self.transaction!.redirectURL!)
        } else {
            Utils.showResult(presenter: self, success: false, message: "Invalid transaction")
        }
    }
    
    func presenterURL(url: URL) {
        self.safariVC = SFSafariViewController(url: url)
        self.safariVC?.delegate = self;
        self.present(safariVC!, animated: true, completion: nil)
    }
    
    func requestPaymentStatus() {
        // You can either hard-code resourcePath or request checkout info to get the value from the server
        // * Hard-coding: "/v1/checkouts/" + checkoutID + "/payment"
        // * Requesting checkout info:
        
        guard let checkoutID = self.transaction?.paymentParams.checkoutID else {
            Utils.showResult(presenter: self, success: false, message: "Checkout ID is invalid")
            return
        }
        self.transaction = nil
        
        self.processingView.startAnimating()
        self.provider!.requestCheckoutInfo(withCheckoutID: checkoutID) { (checkoutInfo, error) in
            DispatchQueue.main.async {
                guard let resourcePath = checkoutInfo?.resourcePath else {
                    self.processingView.stopAnimating()
                    Utils.showResult(presenter: self, success: false, message: "Checkout info is empty or doesn't contain resource path")
                    return
                }
                
                Request.requestPaymentStatus(resourcePath: resourcePath) { (success) in
                    DispatchQueue.main.async {
                        self.processingView.stopAnimating()
                        let message = success ? "Your payment was successful" : "Your payment was not successful"
                        Utils.showResult(presenter: self, success: success, message: message)
                    }
                }
            }
        }
    }
    
    // MARK: - Async payment callback
    
    @objc func didReceiveAsynchronousPaymentCallback() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: Config.asyncPaymentCompletedNotificationKey), object: nil)
        self.safariVC?.dismiss(animated: true, completion: {
            DispatchQueue.main.async {
                self.requestPaymentStatus()
            }
        })
    }
    
    // MARK: - Fields validation
    
    func validateFields() throws {
        guard let holder = self.holderTextField.text, OPPCardPaymentParams.isHolderValid(holder) else {
            throw CardParamsError.invalidParam("Card holder name is invalid.")
        }
        
        guard let number = self.numberTextField.text, OPPCardPaymentParams.isNumberValid(number, luhnCheck: true) else {
            throw CardParamsError.invalidParam("Card number is invalid.")
        }
        
        guard let month = self.expiryMonthTextField.text, let year = self.expiryYearTextField.text, !OPPCardPaymentParams.isExpired(withExpiryMonth: month, andYear: year) else {
            throw CardParamsError.invalidParam("Expiry date is invalid")
        }
        
        guard let cvv = self.cvvTextField.text, OPPCardPaymentParams.isCvvValid(cvv) else {
            throw CardParamsError.invalidParam("CVV is invalid")
        }
    }
    
    // MARK: - Safari Delegate
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true) {
            DispatchQueue.main.async {
                self.requestPaymentStatus()
            }
        }
    }
    
    // MARK: - Keyboard dismissing on tap
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

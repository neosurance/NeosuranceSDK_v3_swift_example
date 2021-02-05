//
//  ViewController.swift
//  NSR SDK SwiftExample
//
//  Created by ok_neosurance on 03/11/20.
//

import Foundation
import UIKit
import AuthenticationServices
import WebKit
import NSR_SDK_v3_swift

class ViewController: UIViewController, WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body as! NSDictionary
        if(body["what"] != nil) {
            let WHAT = body["what"] as! String
            if("setup" == WHAT) {
                self.setup()
            }
            if("registerUser" == WHAT) {
                self.registerUser()
            }
            if("forgetUser" == WHAT) {
                self.forgetUser()
            }
            if("showApp" == WHAT) {
                self.showApp()
            }
            if("sendEvent" == WHAT) {
                self.sendEvent()
            }
            if("sendEvent2" == WHAT) {
                self.sendEvent2()
            }
            if("traceNetworks" == WHAT) {
                self.traceNetworks()
            }
            if("sendEventPush" == WHAT) {
                self.sendEventPush()
            }
            if("sendEventPush2" == WHAT) {
                self.sendEventPush2()
            }
            if("crunchEvent" == WHAT) {
                self.crunchEvent()
            }
            if("appLogin" == WHAT) {
                self.appLogin()
            }
            if("appPayment" == WHAT) {
                self.appPayment()
            }
            if("accurateLocation" == WHAT) {
                let nsr = NSR.getSharedInstance()
                nsr.accurateLocation(meters: 0, duration: 20, extend: true)
            }
            if("accurateLocationEnd" == WHAT) {
                let nsr = NSR.getSharedInstance()
                nsr.accurateLocationEnd()
            }
            if("resetCruncher" == WHAT) {
                let nsr = NSR.getSharedInstance()
                nsr.resetCruncher()
            }
            if("openPage" == WHAT) {
                let nsr = NSR.getSharedInstance()
                nsr.crunchEvent(event: "openPage", payload: NSMutableDictionary())
            }
            if("closeView" == WHAT) {
                let nsr = NSR.getSharedInstance()
                nsr.closeView()
            }
            if("policies" == WHAT) {
                
                let criteria = NSMutableDictionary()
                criteria.setObject(true, forKey: "available" as NSCopying)
                
                let nsr = NSR.getSharedInstance()
                nsr.policies(criteria: criteria, completionHandler: { responseObject, error in
                    if (error == nil) {
                        print("policies response: ", nsr.dictToJson(dict: responseObject))
                    } else {
                        print("policies error: ", error ?? "default error in policies");
                    }
                })
            }
            
        }
    }
    
    
    var webView: NSRWebView!
    var webConfiguration: WKWebViewConfiguration!
    var config: NSDictionary!
    //var timer: NSTimer!
    
    var loadingView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let configFile = Bundle.main.path(forResource: "config", ofType: "plist"){
            
            let configTmp = NSDictionary.init(contentsOfFile: configFile)
            self.config = configTmp
            
            self.setup()
            
            self.webConfiguration = WKWebViewConfiguration()
            //"addScriptMessageHandler" renamed "add"
            self.webConfiguration.userContentController.add(self, name: "app")
            
            let sh = UIApplication.shared.statusBarFrame.size.height
            let size = self.view.frame.size
            
            self.webView = NSRWebView.init(frame: CGRect(x: CGFloat(0), y: sh, width: size.width, height: size.height - sh), configuration: self.webConfiguration)
            self.webView.scrollView.bounces = false
            
            if #available(iOS 11.0, *){
                self.webView.scrollView.insetsLayoutMarginsFromSafeArea = false
            }
            
            if let htmlFile = Bundle.main.path(forResource: "sample", ofType: "html"){
                
                do {
                    let htmlString = try String.init(contentsOfFile: htmlFile, encoding: String.Encoding.utf8)
                    print(htmlString)
                    self.webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
                } catch {
                    print("Html file error")
                }
            }
            
            self.view.addSubview(self.webView)
            
        }
        
        
    }
    
    func setup(){
        
        print("Setup")
        
        self.setVisible()
        
        let nsr = NSR.getSharedInstance()
        
        nsr.workflowDelegate = WFDelegate()
        
        //_ = nsr.setWorkflowDelegate()
        
        let settings = NSMutableDictionary()
        settings.setValue(self.config["base_url"], forKey: "base_url")
        settings.setValue(self.config["code"], forKey: "code")
        settings.setValue(self.config["secret_key"], forKey: "secret_key")
        settings.setValue(true, forKey: "dev_mode")
        //settings.setValue(UIStatusBarStyle.default, forKey: "bar_style")
        //settings.setValue(UIColor.init(red: CGFloat(0.2), green: CGFloat(1), blue: CGFloat(1), alpha: CGFloat(1)), forKey: "back_color")
        //UIColor.init(red: 0.2, green: 1.0, blue: 1.0, alpha: 1.0)
        
        /*
        let back_color = NSMutableDictionary()
        back_color.setValue("0.2", forKey: "red")
        back_color.setValue("1.0", forKey: "green")
        back_color.setValue("1.0", forKey: "blue")
        back_color.setValue("1.0", forKey: "alpha")
                
        settings.setValue(back_color, forKey: "back_color")
        */
 
        DispatchQueue.main.asyncAfter(deadline: .now() + 2){
            self.setHidden()
        }
        
        nsr.setup(settings: settings)
        
    }

    func setVisible(){
        
        let marginLeft = CGFloat(UIScreen.main.bounds.size.width/2 - 40)
        let marginTop = CGFloat(UIScreen.main.bounds.size.height/2 - 40)
        
        loadingView = UIView.init(frame: CGRect(x: marginLeft, y: marginTop, width: CGFloat(80), height: CGFloat(80)))
        loadingView.backgroundColor = UIColor.init(displayP3Red: 255/255, green: 255/255, blue: 255/255, alpha: 0.6)
        loadingView.layer.cornerRadius = 5
        
        let activityView = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.whiteLarge)
        activityView.center = CGPoint.init(x: loadingView.frame.size.width / 2, y: CGFloat(35))
        activityView.startAnimating()
        activityView.tag = 100
        
        loadingView.addSubview(activityView)
        
        let lblLoading = UILabel.init(frame: CGRect(x: CGFloat(0), y: CGFloat(48), width: CGFloat(80), height: CGFloat(30)))
        lblLoading.text = "Loading..."
        lblLoading.textColor = .white
        lblLoading.font = UIFont.init(name: lblLoading.font.fontName, size: CGFloat(15))
        lblLoading.textAlignment = .center
        
        loadingView.addSubview(lblLoading)
        
        self.view.addSubview(loadingView)
        
        loadingView.isHidden = false
    }

    func setHidden(){
        loadingView.isHidden = true
    }
    
    
    
    
    
    
    func registerUser(){
        print("Register User")
        
        self.setVisible()
        
        //let configTmp = self.config ?? NSDictionary()
                
        let user = NSRUser()
        
        user.code = (self.config["user.code"] as! String)
        user.email = (self.config["user.email"] as! String)
        user.firstname = (self.config["user.firstname"] as! String)
        user.lastname = (self.config["user.lastname"] as! String)
        user.country = (self.config["user.country"] as! String)
        user.fiscalCode = (self.config["user.fiscalCode"] as! String)
        user.address = (self.config["user.address"] as! String)
        user.city = (self.config["user.city"] as! String)
        user.province = (self.config["user.province"] as! String)
        //user.mobile = (self.config["user.mobile"] as! String)
        //user.gender = (self.config["user.gender"] as! String)
        //user.birthday = (self.config["user.birthday"] as! Date)
        user.cap = (self.config["user.cap"] as! String)
        //user.extra = (self.config["user.extra"] as! NSDictionary)
        
        
        let locals = NSMutableDictionary()
        locals.setObject(user.email ?? "", forKey:"email" as NSCopying)
        locals.setObject(user.firstname ?? "", forKey:"firstname" as NSCopying)
        locals.setObject(user.lastname ?? "", forKey:"lastname" as NSCopying)
        locals.setObject(user.fiscalCode ?? "", forKey:"fiscalCode" as NSCopying)
        locals.setObject(user.address ?? "", forKey:"address" as NSCopying)
        locals.setObject(user.city ?? "", forKey:"city" as NSCopying)
        locals.setObject(user.province ?? "", forKey:"province" as NSCopying)
        locals.setObject("fake-push", forKey:"pushToken" as NSCopying)
        
        if (self.config["user.locals"] as? String) != nil{
            user.locals = locals
            //user.setValue(locals, forKey: "locals")
        }
        
        
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2){
            self.setHidden()
        }
        
        let nsr = NSR.getSharedInstance()
        nsr.registerUser(user: user)
        
    }

    func forgetUser(){
        print("Forget User")
        let payload = NSMutableDictionary()
        NSR.getSharedInstance().crunchEvent(event: "forgetUser", payload: payload)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2){
            self.innerForgetUser()
        }
        
    }

    func innerForgetUser(){
        print("innerForgetUser User")
        NSR.getSharedInstance().forgetUser()
    }

    func showApp(){
        print("ViewController - showApp")
        self.setVisible()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2){
            self.setHidden()
        }
        NSR.getSharedInstance().showApp()
    }

    func sendEvent(){
        print("Send Event")
        
        let payload = NSMutableDictionary()
        
        //payload.setValue("IT", forKey: "fromCode")
        //payload.setValue("italia", forKey: "fromCountry")
        //payload.setValue("FR", forKey: "toCode")
        //payload.setValue("francia", forKey: "toCountry")
        //payload.setValue(1, forKey: "fake")
        //NSR.getSharedInstance().sendEvent(event:"inAirport", payload:payload)
        
        NSR.getSharedInstance().sendEvent(event:"ondemand", payload:payload)
        
    }

    func traceNetworks(){
        print("Trace Networks not available")
        //NSR.getSharedInstance().traceNetworks()
    }

    func sendEvent2(){
        print("Send Event 2")
        self.setVisible()
        
        let payload = NSMutableDictionary()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2){
            self.setHidden()
        }
        NSR.getSharedInstance().sendEvent(event:"2go", payload:payload)
    }

    func sendEventPush(){
        print("Send Event Push")
        let payload = NSMutableDictionary()
        NSR.getSharedInstance().sendEvent(event:"inpoi", payload:payload)
    }

    func sendEventPush2(){
        print("Send Event Push 2")
        
        self.setVisible()
        
        let payload = NSMutableDictionary()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2){
            self.setHidden()
        }
        
        NSR.getSharedInstance().sendEvent(event:"bikeWeekEnd", payload:payload)
    }


    func crunchEvent(){
        print("crunch Event")
        
        let payload = NSMutableDictionary()
        payload.setValue(51.16135787, forKey: "latitude")
        payload.setValue(-0.17700102, forKey: "longitude")
        
        NSR.getSharedInstance().crunchEvent(event: "position", payload: payload)
    }
    
    func appLogin(){
        print("AppLogin")
        let url = UserDefaults.standard.object(forKey: "login_url") as? String ?? ""
        
        if(!url.isEmpty){
            NSR.getSharedInstance().loginExecuted(url: url)
            UserDefaults.standard.removeObject(forKey: "login_url")
        }
    }

    func appPayment(){
        print("AppPayment")
        let url = UserDefaults.standard.object(forKey: "payment_url") as? String ?? ""
        
        let paymentInfo = NSMutableDictionary()
        paymentInfo.setValue("abcde", forKey: "transactionCode")
        
        if(!url.isEmpty){
            NSR.getSharedInstance().paymentExecuted(paymentInfo: paymentInfo, url: url)
            UserDefaults.standard.removeObject(forKey: "payment_url")
        }
    }

    func preferredStatusBarStyle()->UIStatusBarStyle{
        return UIStatusBarStyle.lightContent
    }
    
}


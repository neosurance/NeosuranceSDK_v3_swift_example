//
//  NSRControllerWebView.swift
//  NSR SDK SwiftExample
//
//  Created by ok_neosurance on October 2020.
//

import Foundation
import WebKit
import CoreLocation

public class NSRControllerWebView: UIViewController,WKUIDelegate,WKNavigationDelegate,WKScriptMessageHandler,CLLocationManagerDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate{
    
    var webView: NSRWebView!
    var webConfiguration: WKWebViewConfiguration!
    var url: URL!
    var barStyle: UIStatusBarStyle!
    var locationManager: CLLocationManager!
    var locationCallBack: String!
    var photoCallBack: String!
    
    override public func loadView() {
        
        super.loadView()
            
        NSR.getSharedInstance().registerWebView(newWebView: self)
        self.webConfiguration = WKWebViewConfiguration()
        //addScriptMessageHandler
        self.webConfiguration.userContentController.add(self, name: "app")
        
        let sh = UIApplication.shared.statusBarFrame.size.height
        let size = self.view.frame.size
        
        
        self.webView = NSRWebView(frame: CGRect(x: CGFloat(0), y: sh, width: size.width, height: size.height - sh), configuration: self.webConfiguration)
        self.webView.navigationDelegate = self
        self.webView.scrollView.showsVerticalScrollIndicator = false
        self.webView.scrollView.showsHorizontalScrollIndicator = false
        self.webView.scrollView.bounces = false
        self.webView.scrollView.insetsLayoutMarginsFromSafeArea = false
        
        //self.webView.load(NSURLRequest.init(url: self.url as URL) as URLRequest)
        self.webView.load(URLRequest.init(url: self.url))
        
        self.view.addSubview(self.webView)
            
        
        
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    public func navigate(url: String?){
        
        if(url != nil){
            let urlTmp = url!
            if(!urlTmp.isEmpty){
                if let urlTmpObj = URL.init(string: urlTmp){
                    self.webView.load(URLRequest.init(url: urlTmpObj))
                }
            }
        }
        
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        print("NSRControllerWebView - userContentController")
        
        let body = message.body as! NSDictionary
        
        let nsr = NSR.getSharedInstance()
        
        
        if(body["log"] != nil) {
            print(body["log"] as Any)
        }
        if(body["event"] != nil && body["payload"] != nil) {
            nsr.sendEvent(event: body["event"] as! String, payload: body["payload"] as! NSDictionary)
        }
        if(body["crunchEvent"] != nil && body["payload"] != nil) {
            nsr.crunchEvent(event: body["crunchEvent"] as! String, payload: body["payload"] as! NSDictionary)
        }
        if(body["archiveEvent"] != nil && body["payload"] != nil) {
            nsr.archiveEvent(event: body["archiveEvent"] as! String, payload: body["payload"] as! NSDictionary)
        }
        if(body["action"] != nil) {
            nsr.sendAction(action: body["action"] as! String, code: body["code"] as! String, details: body["details"] as! String)
        }
        
        if(body["what"] != nil) {
         
            let WHAT = body["what"] as! String
            print(WHAT)
            
            
            
            if(WHAT == "init" && body["callBack"] != nil) {
                
                /* Authorize */
                nsr.authorize(completionHandler: { authorized in
                    
                    let message = NSMutableDictionary()
                    
                    let baseUrl = (nsr.getSettings()["base_url"] != nil) ? nsr.getSettings()["base_url"] as! String : ""
                    
                    message.setObject(baseUrl, forKey: "api" as NSCopying)
                    message.setObject(nsr.getToken(), forKey: "token" as NSCopying)
                    message.setObject(nsr.getLang(), forKey: "lang" as NSCopying)
                    message.setObject(nsr.uuid(), forKey: "deviceUid" as NSCopying)
                    
                    let evalMessage = nsr.dictToJson(dict: message)
                    let evalCallBack = body["callBack"] as! String
                    let evalString = evalCallBack + "(" + evalMessage + ")"
                    self.eval(javascript: evalString)
                    
                })
                
            }
            
            if(WHAT == "close") {
                self.close()
            }
            
            if(WHAT == "photo" && body["callBack"] != nil) {
                self.takePhoto(callBack: body["callBack"] as! String)
            }
            
            if(WHAT == "location" && body["callBack"] != nil) {
                self.getLocation(callBack: body["callBack"] as! String)
            }
            
            if(WHAT == "user" && body["callBack"] != nil) {
                
                let evalMessage = nsr.dictToJson(dict: nsr.getUser().toDict(withLocals: true))
                let evalCallBack = body["callBack"] as! String
                let evalString = evalCallBack + "(" + evalMessage + ")"
                self.eval(javascript: evalString)
                
            }
            
            if(WHAT == "showApp") {
                nsr.showApp(params: body["params"] as! NSDictionary)
            }
            
            if(WHAT == "showUrl" && body["url"] != nil) {
                nsr.showUrl(url: body["url"] as! String, params: (body["params"] as! NSDictionary))
            }
            
            if (WHAT == "store" && body["key"] != nil && body["data"] != nil) {
                nsr.storeData(key: body["key"] as! String, data: body["data"] as! NSDictionary)
            }
            
            if ( (WHAT == "retrive" || WHAT == "retrieve") && body["key"] != nil && body["callBack"] != nil) {
                
                let val = nsr.retrieveData(key: body["key"] as! String)
                
                let evalMessage = (val.count > 0) ? nsr.dictToJson(dict: val) : "null"
                let evalCallBack = body["callBack"] as! String
                let evalString = evalCallBack + "(" + evalMessage + ")"
                self.eval(javascript: evalString)
                                
            }
            
            if(WHAT == "callApi" && body["callBack"] != nil) {
                
                /* Authorize */
                nsr.authorize(completionHandler: { authorized in
                    
                    if(!authorized){
                        let result = NSMutableDictionary()
                        result.setObject("error", forKey: "status" as NSCopying)
                        result.setObject("not authorized", forKey: "message" as NSCopying)
                        
                        let evalMessage = nsr.dictToJson(dict: result)
                        let evalCallBack = body["callBack"] as! String
                        let evalString = evalCallBack + "(" + evalMessage + ")"
                        self.eval(javascript: evalString)
                        
                        return
                    }
                    
                    /* REQUEST_HEADERS */
                    let headers = NSMutableDictionary()
                    headers.setObject(nsr.getToken(), forKey: "ns_token" as NSCopying)
                    headers.setObject(nsr.getLang(), forKey: "ns_lang" as NSCopying)
                    
                    nsr.securityDelegate.secureRequest(endpoint: body["endpoint"] as! String, payload: body["payload"] as! NSDictionary, headers: headers, completionHandler: { responseObject, error in
                        
                        if(error == nil){
                            let evalMessage = nsr.dictToJson(dict: responseObject)
                            let evalCallBack = body["callBack"] as! String
                            let evalString = evalCallBack + "(" + evalMessage + ")"
                            self.eval(javascript: evalString)
                        }else{
                            let result = NSMutableDictionary()
                            result.setObject("error", forKey: "status" as NSCopying)
                            result.setObject(error ?? "", forKey: "message" as NSCopying)
                            
                            let evalMessage = nsr.dictToJson(dict: result)
                            let evalCallBack = body["callBack"] as! String
                            let evalString = evalCallBack + "(" + evalMessage + ")"
                            self.eval(javascript: evalString)
                        }
                        
                    })
                    
                    
                })
                
            }
            if(WHAT == "geoCode" && body["location"] != nil && body["callBack"] != nil) {
                
                let geocoder = CLGeocoder()
                
                let bodyLocation = body["location"] as! NSDictionary
                let lat = (bodyLocation["latitude"] != nil) ? bodyLocation["latitude"] as? Double : Double.init("0.0")!
                let long = (bodyLocation["longitude"] != nil) ? bodyLocation["longitude"] as? Double : Double.init("0.0")!
                let location = CLLocation.init(latitude: lat!, longitude: long!)
                
                geocoder.reverseGeocodeLocation(location, completionHandler: { placemarks, error in
                    
                    if(placemarks != nil && placemarks!.count > 0){
                        let placemark = placemarks?[0]
                        
                        let address = NSMutableDictionary()
                        address.setObject(placemark?.isoCountryCode ?? "", forKey: "countryCode" as NSCopying)
                        address.setObject(placemark?.country ?? "", forKey: "countryName" as NSCopying)
                        
                        //let addressString = placemark?.addressDictionary
                        let addressString = "\(placemark?.subThoroughfare ?? ""), \(placemark?.thoroughfare ?? ""), \(placemark?.locality ?? ""), \(placemark?.subLocality ?? ""), \(placemark?.administrativeArea ?? ""), \(placemark?.postalCode ?? ""), \(placemark?.country ?? "")"
                                        
                        print("\(addressString)")
                        
                        address.setObject(addressString, forKey: "address" as NSCopying)
                        
                        let evalMessage = nsr.dictToJson(dict: address)
                        let evalCallBack = body["callBack"] as! String
                        let evalString = evalCallBack + "(" + evalMessage + ")"
                        self.eval(javascript: evalString)
                    }
                    
                })
                
            }
            
            let nsrWorkflowDelegate = nsr.workflowDelegate
            let callBackTmp = body["callBack"]
            
            if( nsrWorkflowDelegate != nil && WHAT == "executeLogin" && callBackTmp != nil) {
                
                let executeLoginBoolean = nsr.workflowDelegate.executeLogin(url: self.webView.url?.absoluteString ?? "")
                
                let evalMessage = String(executeLoginBoolean)
                let evalCallBack = body["callBack"] as! String
                let evalString = evalCallBack + "(" + evalMessage + ")"
                self.eval(javascript: evalString)
                
            }
            
            if(nsr.workflowDelegate != nil && WHAT == "executePayment" && body["payment"] != nil) {
                
                let paymentInfo = nsr.workflowDelegate.executePayment(payment: body["payment"] as? NSDictionary ?? NSDictionary(), url: self.webView.url?.absoluteString ?? "")
                
                if(body["callBack"] != nil) {
                    let evalMessage = (paymentInfo.count > 0) ? nsr.dictToJson(dict: paymentInfo) : ""
                    let evalCallBack = body["callBack"] as! String
                    let evalString = evalCallBack + "(" + evalMessage + ")"
                    self.eval(javascript: evalString)
                }
                
            }
            
            if(nsr.workflowDelegate != nil && WHAT == "confirmTransaction" && body["paymentInfo"] != nil) {
                nsr.workflowDelegate.confirmTransaction(paymentInfo: body["paymentInfo"] as! NSDictionary)
            }
            
            if(nsr.workflowDelegate != nil && WHAT == "keepAlive") {
                nsr.workflowDelegate.keepAlive()
            }
            
            if(nsr.workflowDelegate != nil && WHAT == "goTo"){
             
                if let area = body["area"] as? String{
                    nsr.workflowDelegate.goTo(area: area)
                }
            }
            
        }
        
    }
    
    
    public func checkBody(){
        
        self.webView.evaluateJavaScript("document.body.className", completionHandler: { result, error in
            
            if let resultString = result as? String{
                print("checkBody - resultString: " + resultString)
                self.close()
            }else{
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 15){
                    self.checkBody()
                }
                            
            }
            
        })
        
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        
        if (navigationAction.navigationType == .linkActivated){
            
            let url = navigationAction.request.url! //navigationAction.request.url.absoluteString
                        
            if(url.absoluteString.hasSuffix(".pdf")){
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            }else{
                decisionHandler(.allow)
            }
            
        }else{
            decisionHandler(.allow)
        }
    
    }
    
    
    public func close(){
        
        print(#function)
        
        NSR.getSharedInstance().clearWebView()
        
        self.dismiss(animated: true, completion: {
            
            if(self.webView != nil){
                self.webView.stopLoading()
                self.webView.navigationDelegate = nil
                self.webView.removeFromSuperview()
                self.webView = nil
            }
            
            if(self.locationManager != nil){
                self.locationManager.stopUpdatingLocation()
                self.locationManager.delegate = nil
                self.locationManager = nil
            }
            
        })
        
    }
    
    public func getLocation(callBack: String) {
        
        if(self.locationManager == nil){
            self.locationManager = CLLocationManager()
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.delegate = self
            self.locationManager.requestAlwaysAuthorization()
        }
        
        self.locationCallBack = callBack
        self.locationManager.startUpdatingLocation()
        
    }

    
    public func didUpdateLocations(manager: CLLocationManager, locations: NSArray){
        
        if(locations.count > 0){
            
            print("didUpdateToLocation")
            manager.stopUpdatingLocation()
            
            if(self.locationCallBack != nil && self.locationCallBack.count > 0){
                
                let loc = locations.lastObject as! CLLocation
                
                let latitudeString = "latitude:" + String(loc.coordinate.latitude)
                let longitudeString = ",longitude:" + String(loc.coordinate.longitude)
                let altitudeString = ",altitude:" + String(loc.altitude)
                
                let evalMessage = "{" + latitudeString + longitudeString + altitudeString + "}"
                let evalCallBack = self.locationCallBack!
                let evalString = evalCallBack + "(" + evalMessage + ")"
                self.eval(javascript: evalString)
                
                self.locationCallBack = nil
                
            }
            
        }
        
    }
    
    public func didFailWithError(manager: CLLocationManager, error: NSError){
        print("didFailWithError")
    }
    
    public func eval(javascript: String){
        
        DispatchQueue.main.async {
            if(self.webView != nil){
                self.webView.evaluateJavaScript(javascript, completionHandler: { result, error in })
            }
        }
        
    }
    
    
    
    /* *** PHOTO *** */
    
    public func takePhoto(callBack: String){
        let controller = UIImagePickerController()
        controller.delegate = self
        controller.sourceType = .camera
        controller.allowsEditing = false
        
        self.present(controller, animated: true, completion: {
            self.photoCallBack = callBack
        })
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                
        if(self.photoCallBack != nil){
        
            let image = (info[UIImagePickerController.InfoKey.originalImage] as? UIImage)!
            
            let newSize = CGSize.init(width: CGFloat(512)*image.size.width/image.size.height, height: CGFloat(512))
            UIGraphicsBeginImageContextWithOptions(newSize, false, CGFloat(0))
            
            image.draw(in: CGRect.init(x: CGFloat(0), y: CGFloat(0), width: newSize.width, height: newSize.height))
            
            
            let newImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            let imageData = newImage.jpegData(compressionQuality: 1.0)
            
            let base64 = (imageData?.base64EncodedString(options: Data.Base64EncodingOptions.init()) )!
            
            let evalCallBack = self.photoCallBack!
            let evalString = evalCallBack + "('data:image/png;base64," + base64 + "'))"
            self.eval(javascript: evalString)
            
            picker.dismiss(animated: true, completion: {
                self.photoCallBack = nil
            })
        }
            
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: {
            self.photoCallBack = nil
        })
    }
        
    
    public func shouldAutorotate()->Bool{
        return false
    }

    public func preferredInterfaceOrientationForPresentation()->UIInterfaceOrientation{
        return .portrait
    }

    public func supportedInterfaceOrientations()->UIInterfaceOrientationMask{
        return .portrait
    }

    public func preferredStatusBarStyle()->UIStatusBarStyle{
        return self.barStyle
    }
    
}

//
//  NSREventWebView.swift
//  NSR SDK
//
//  Created by ok_neosurance on October 2020.
//

import UIKit
import WebKit
import CoreLocation

public class NSREventWebView: NSObject, WKScriptMessageHandler{
    
    var webView: WKWebView!
    var webConfiguration: WKWebViewConfiguration!
    
    
    override init(){
        
        super.init()
        
        _ = NSR.getSharedInstance()
        
        self.webConfiguration = WKWebViewConfiguration()
        
        DispatchQueue.main.async {
            
            //"addScriptMessageHandler" renamed "add"
            self.webConfiguration.userContentController.add(self, name: "app")
            self.webView = WKWebView.init(frame: CGRect.zero, configuration: self.webConfiguration)
            
            if let htmlFile = Bundle.main.path(forResource: "eventCruncher", ofType: "html"){
                
                do {
                    let htmlString = try String.init(contentsOfFile: htmlFile, encoding: String.Encoding.utf8)
                    print(htmlString)
                    self.webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
                } catch {
                    print("Html file error")
                }
            }
            
        }
                
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            
        let body = message.body as! NSDictionary
        let nsr = NSR.getSharedInstance()
        
        let WHAT = (body["what"] != nil) ? body["what"] as! String : ""
                    
        if(body["log"] != nil) {
            print(body["log"] as! String)
        }
        if(body["event"] != nil && body["payload"] != nil) {
            nsr.sendEvent(event: body["event"] as! String, payload: body["payload"] as! NSDictionary)
        }
        if(body["archiveEvent"] != nil && body["payload"] != nil) {
            nsr.archiveEvent(event: body["archiveEvent"] as! String, payload: body["payload"] as! NSDictionary)
        }
        if(body["action"] != nil) {
            nsr.sendAction(action: body["action"] as? String ?? "", code: body["code"] as? String ?? "", details: body["details"] as? String ?? "")
        }
        if(body["push"] != nil) {
            if(body["delay"] != nil) {
                nsr.showPush(pid: body["id"] as? String ?? String(NSDate().timeIntervalSince1970 * 1000), push: body["push"] as! NSDictionary, delay: body["delay"] as! Int)
            }else{
                nsr.showPush(push: body["push"] as! NSDictionary)
            }
        }
        if(body["killPush"] != nil) {
            nsr.killPush(pid: body["killPush"] as! String)
        }
        
        if(body["what"] != nil) {
            
            if(WHAT == "continueInitJob") {
                nsr.continueInitJob()
            }
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
            
            if(WHAT == "token" && body["callBack"] != nil) {
                
                /* Authorize */
                nsr.authorize(completionHandler: { authorized in
                    if(authorized) {
                        
                        let evalMessage = nsr.getToken()
                        let evalCallBack = body["callBack"] as! String
                        let evalString = evalCallBack + "(" + evalMessage + ")"
                        self.eval(javascript: evalString)
                    }
                })
                
            }
            if(WHAT == "user" && body["callBack"] != nil) {
                
                let evalMessage = nsr.dictToJson(dict: nsr.getUser().toDict(withLocals: true))
                let evalCallBack = body["callBack"] as! String
                let evalString = evalCallBack + "(" + evalMessage + ")"
                self.eval(javascript: evalString)
                                    
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
                    
                    let bodyPayload = (body["payload"] != nil) ? body["payload"] as! NSDictionary : NSDictionary()
                    
                    nsr.securityDelegate.secureRequest(endpoint: body["endpoint"] as! String, payload: bodyPayload, headers: headers, completionHandler: { responseObject, error in
                        
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
            
            
            if(WHAT == "accurateLocation" && body["meters"] != nil && body["duration"] != nil) {
                let extend = nsr.getBoolean(dict: body, key: "extend")
                nsr.accurateLocation(meters: body["meters"] as! Double, duration: body["duration"] as! Int, extend: extend)
            }
            if(WHAT == "accurateLocationEnd") {
                nsr.accurateLocationEnd()
            }
            if(WHAT == "activateFences") {
                UserDefaults.standard.setValue(body["fences"], forKey: "fences")
                //nsr.traceFence()
            }
            if(WHAT == "removeFences") {
                //nsr.traceFence()
            }
        }
       
        
    }
    
    public func synch(){
        self.eval(javascript: "EVC.synch()")
    }

    public func reset(){
        self.eval(javascript: "localStorage.clear();EVC.synch()")
    }

    public func crunchEvent(event: String, payload: NSDictionary){
        
        let nsr = NSR.getSharedInstance()
        
        let nsrEvent = NSMutableDictionary()
        nsrEvent.setObject(event, forKey: "event" as NSCopying)
        nsrEvent.setObject(payload, forKey: "payload" as NSCopying)
        
        let message = nsr.dictToJson(dict: nsrEvent)
        let javascriptString = "EVC.innerCrunchEvent(" + message + ")"
        self.eval(javascript: javascriptString)
        
    }

    public func eval(javascript: String){
        
        DispatchQueue.main.async{
            if(self.webView != nil){
                self.webView.evaluateJavaScript(javascript, completionHandler: { result, error in
                    
                })
            }
        }
        
    }

    public func close(){
        if(self.webView != nil){
            self.webView.stopLoading()
            self.webView.navigationDelegate = nil
            self.webView = nil
        }
    }
    
    
}


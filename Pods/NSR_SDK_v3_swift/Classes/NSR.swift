//
//  NSR.swift
//  NSR SDK
//
//  Created by ok_neosurance on October 2020.
//

import UIKit
import CoreLocation
import CoreMotion
import Network
import MapKit
import Foundation

public protocol NSRSecurityDelegate: NSObject{
    func secureRequest( endpoint: String, payload: NSDictionary, headers: NSDictionary, completionHandler: @escaping(_ responseObject: NSDictionary, _ error: NSError?)->() )
}

public protocol NSRWorkflowDelegate: NSObject{
    func executeLogin(url: String)->(Bool)
    func executePayment(payment: NSDictionary, url: String)->(NSDictionary)
    func confirmTransaction(paymentInfo: NSDictionary)->()
    func keepAlive()->()
	func goTo(area: String)->()
}

public class NSR: NSObject, CLLocationManagerDelegate{

    static var sharedInstance: NSR!
    
    var securityDelegate: NSRSecurityDelegate!
    public var workflowDelegate: NSRWorkflowDelegate!
    
    var locationManager: CLLocationManager!
    var hardLocationManager: CLLocationManager!
    var stillLocationManager: CLLocationManager!
    var fenceLocationManager: CLLocationManager!
    
    var motionActivityManager: CMMotionActivityManager!
    
    var motionActivities: NSMutableArray!
    var regionsArray: NSMutableArray!
    
    static var LMStartMonitoring = false
    static var DwellRegion = false
    static var _logDisabled = false
    
    var controllerWebView: NSRControllerWebView!
    var eventWebView: NSREventWebView!
    var stillLocationSent: Bool!
    var setupInitiated: Bool!
    
    static var nwPathMonitor: NWPathMonitor!
    
    init(securityDelegate: NSRSecurityDelegate){
        
        super.init()
        
        if(NSR.sharedInstance == nil){
            NSR.sharedInstance = self
        }
        
        self.securityDelegate = securityDelegate
        
        self.stillLocationManager = nil
        self.locationManager = nil
        self.hardLocationManager = nil

        self.stillLocationSent = false
        self.setupInitiated = false
        self.controllerWebView = nil
        self.eventWebView = nil
                
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public static func getSharedInstance()->NSR{
        if(NSR.sharedInstance == nil){
            NSR.sharedInstance = NSR(securityDelegate: NSRDefaultSecurityDelegate())
        }
        return NSR.sharedInstance
    }
    
    public func setup(settings:NSMutableDictionary){
        
        print("NSR - SETUP")
        
        let settings_disable_log = settings["disable_log"]
        let logDisabledTmp = (settings_disable_log != nil) ? settings_disable_log as! Bool : false
        NSR._logDisabled = logDisabledTmp
        
        let mutableSettings = NSMutableDictionary.init(dictionary: settings)
        
        if(mutableSettings["ns_lang"] == nil){
            let language = (NSLocale.current.languageCode ?? "") as String
            /* let languageDic = NSLocale.components(fromLocaleIdentifier: language) */
            //let localizedStringForLanguageCode = NSLocale.current.localizedString(forLanguageCode: language)
            mutableSettings.setValue(language, forKey: "ns_lang")
        }
        
        if(mutableSettings["dev_mode"] == nil) {
            mutableSettings.setValue(0, forKey: "dev_mode")
        }
        
        /*
        if(mutableSettings["back_color"] != nil) {
            let back_color = mutableSettings["back_color"] as! NSDictionary
            
            let r = Float(back_color["red"] as! String)
            let g = Float(back_color["green"] as! String)
            let b = Float(back_color["blue"] as! String)
            let a = Float(back_color["alpha"] as! String)
            
            
            mutableSettings.setValue(r, forKey: "back_color_r")
            mutableSettings.setValue(g, forKey: "back_color_g")
            mutableSettings.setValue(b, forKey: "back_color_b")
            mutableSettings.setValue(a, forKey: "back_color_a")
            
            
            if let components = c.cgColor.components{
                
                let r = components[0]
                let g = components[1]
                let b = components[2]
                let a = components[3]
                
                mutableSettings.setObject(Double(r), forKey: "back_color_r" as NSCopying)
                mutableSettings.setObject(Double(g), forKey: "back_color_g" as NSCopying)
                mutableSettings.setObject(Double(b), forKey: "back_color_b" as NSCopying)
                mutableSettings.setObject(Double(a), forKey: "back_color_a" as NSCopying)
            
            }
            
            
        }
        */
        
        if(mutableSettings["skin"] != nil) {
            storeData(key: "skin", data: mutableSettings["skin"] as! NSDictionary)
        }
        
        setSettings(settings: mutableSettings)
        
        if(!setupInitiated){
            setupInitiated = true
            initJob()
        }
        
    }
    
    public func initJob(){
        
        self.stopHardTraceLocation()
        self.stopTraceLocation()
        self.stopTraceConnection()
        
        if(synchEventWebView()){
            self.continueInitJob()
        }
    }
    
    public func continueInitJob(){
        self.traceConnection()
        self.traceLocation()
        self.hardTraceLocation()
        //self.traceFence()
    }
    
    public func synchEventWebView()->Bool{
        
        let conf = getConf()
        let local_tracking_bool = getBoolean(dict: conf, key: "local_tracking")
        
        if(local_tracking_bool){
            
            if(eventWebView == nil){
                print("Making NSREventWebView")
                eventWebView = NSREventWebView()
                return true
            }else{
                eventWebView.synch()
            }
            
        }else if(eventWebView != nil) {
            eventWebView.close()
            eventWebView = nil
        }
        
        return false
        
    }
    
    public func setConf(conf:NSDictionary){
        
        
        UserDefaults.standard.set(conf, forKey: "NSR_conf")
        
        /* UserDefaults.standard.synchronize() */
        /*
        do {
            let encodedData = try NSKeyedArchiver.archivedData(withRootObject: conf, requiringSecureCoding: false)
            UserDefaults.standard.set(encodedData, forKey: "NSR_conf")
        } catch {
            print("setConf error")
        }
        */
        
        //print("NSR - setConf OK: ", conf)
        
    }

    public func getConf()->NSDictionary{
        
        let NSR_conf = UserDefaults.standard.object(forKey: "NSR_conf")
        
        if(NSR_conf != nil){
            let conf = UserDefaults.standard.object(forKey: "NSR_conf") as! NSDictionary
            //print("NSR - getConf ", conf)
            return conf
        }
        
        /*
        var conf = NSMutableDictionary()
        
        do {
            if let decoded = UserDefaults.standard.object(forKey: "NSR_conf") as? Data{
                conf = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSMutableDictionary.self, from: decoded) ?? NSMutableDictionary()
            }
        } catch {
            print("getConf error")
        }
        */
        
        return NSDictionary()
        
    }
    
    public func setSettings(settings: NSDictionary){
        
        
        do {
            let encodedData = try NSKeyedArchiver.archivedData(withRootObject: settings, requiringSecureCoding: false)
            UserDefaults.standard.set(encodedData, forKey: "NSR_settings")
        } catch {
            print("SetSettings error")
        }
        
        //UserDefaults.standard.set(settings, forKey: "NSR_settings")
        
    }

    public func getSettings()->NSDictionary{
        
        var settings = NSMutableDictionary()
        
        do {
            let decoded = UserDefaults.standard.object(forKey: "NSR_settings") as! Data
            settings = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSMutableDictionary.self, from: decoded) ?? NSMutableDictionary()
            /* let settings = UserDefaults.standard.object(forKey: "NSR_settings") as! NSDictionary */
        } catch {
            print("GetSettings error")
        }
        
        return settings
    }
    
    public func storeData(key: String, data: NSDictionary){
        
        let nsr_key = "NSR_WV_" + key
        /* UserDefaults.standard.set(data, forKey: nsr_key) */
        /* UserDefaults.standard.synchronize() */
        
        do {
            let encodedData = try NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false)
            UserDefaults.standard.set(encodedData, forKey: nsr_key)
        } catch {
            print("StoreData error")
        }
        
    }

    public func retrieveData(key: String)->NSDictionary{
        
        let nsr_key = "NSR_WV_" + key
        let decoded  = UserDefaults.standard.object(forKey: nsr_key) as! Data
        /* let val = NSKeyedUnarchiver.unarchiveObject(with: decoded) as! NSDictionary */
        /* let val = UserDefaults.standard.object(forKey: nsr_key) as! NSDictionary */
        
        var val = NSMutableDictionary()
        
        do {
            val = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSMutableDictionary.self, from: decoded) ?? NSMutableDictionary()
        } catch {
            print("retrieveData error")
        }
        
        return val
        
    }
    
    
    public func resetCruncher(){
        if(self.eventWebView != nil) {
            self.eventWebView.reset()
        }
    }
    
    public func hardTraceLocation(){
        print("hardTraceLocation")
        let conf = self.getConf()
        if(conf.count > 0 && self.getBoolean(dict: conf["position"] as! NSDictionary, key: "enabled")) {
            if(self.isHardTraceLocation()){
                self.initHardLocation()
                self.hardLocationManager.distanceFilter = self.getHardTraceMeters()
                self.hardLocationManager.startUpdatingLocation()
                print("hardTraceLocation activated again")
            }else{
                self.stopHardTraceLocation()
                self.setHardTraceEnd(0)
            }
        }
    }

    public func stopHardTraceLocation(){
        if(self.hardLocationManager != nil){
            print("stopHardTraceLocation")
            self.hardLocationManager.stopUpdatingLocation()
        }
    }
    
    public func accurateLocation(meters: Double, duration:Int, extend: Bool) {
        let conf = self.getConf()
        
        if(conf.count > 0 && self.getBoolean(dict: conf["position"] as! NSDictionary, key: "enabled")) {
            
            print("accurateLocation")
            self.initHardLocation()
            if(!self.isHardTraceLocation() || meters != self.getHardTraceMeters()) {
                self.setHardTraceMeters(meters)
                self.setHardTraceEnd(Int(round(NSDate().timeIntervalSince1970)) + duration)
                self.hardLocationManager.distanceFilter = meters
                self.hardLocationManager.startUpdatingLocation()
            }
            if(extend) {
                self.setHardTraceEnd(Int(round(NSDate().timeIntervalSince1970)) + duration)
            }
    
        }

    }
    
    public func accurateLocationEnd(){
        print("accurateLocationEnd")
        self.stopHardTraceLocation()
        self.setHardTraceEnd(0)
    }
    
    public func initHardLocation(){
        if(self.hardLocationManager == nil) {
            print("initHardLocation")
            self.hardLocationManager = CLLocationManager()
            self.hardLocationManager.allowsBackgroundLocationUpdates = true
            self.hardLocationManager.pausesLocationUpdatesAutomatically = false
            self.hardLocationManager.desiredAccuracy = kCLLocationAccuracyBest
            
            self.hardLocationManager.delegate = self
            self.hardLocationManager.requestAlwaysAuthorization()
        }
    }

    public func isHardTraceLocation()->Bool{
        
        let hte = self.getHardTraceEnd() as Int
        let date = NSDate()
        
        return (hte > 0 && Int(round(date.timeIntervalSince1970)) < hte)
    }

    public func checkHardTraceLocation(){
        if(!self.isHardTraceLocation()){
            self.stopHardTraceLocation()
            self.setHardTraceEnd(0)
        }
    }

    public func getHardTraceEnd()->Int{
        
        let n = UserDefaults.standard.object(forKey: "NSR_hardTraceEnd")
        if(n != nil) {
            return UserDefaults.standard.object(forKey: "NSR_hardTraceEnd") as! Int
        }else{
            return 0
        }
        
    }

    public func setHardTraceEnd(_ hardTraceEnd: Int){
        UserDefaults.standard.set(hardTraceEnd, forKey: "NSR_hardTraceEnd")
    }

    public func getHardTraceMeters()->Double{
        let n = UserDefaults.standard.object(forKey: "NSR_hardTraceMeters")
        if(n != nil) {
            return n as! Double
        }else{
            return 0
        }
    }

    public func setHardTraceMeters(_ meters: Double){
        UserDefaults.standard.set(meters, forKey: "NSR_hardTraceMeters")
    }
    
    public func traceLocation(){
        let conf = self.getConf()
        
        let positionEnabled = self.getBoolean(dict: conf["position"] as! NSDictionary, key: "enabled")
        if(conf.count > 0 && positionEnabled) {
            self.initLocation()
            //self.locationManager.distanceFilter = 500
            //self.locationManager.startUpdatingLocation()
            self.locationManager.startMonitoringSignificantLocationChanges()
            
        }
    }
    
    public func initLocation(){
        if(self.locationManager == nil) {
            print("initLocation")
            self.locationManager = CLLocationManager()
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.delegate = self
            self.locationManager.requestAlwaysAuthorization()
        }
    }
    
    public func initStillLocation(){
        if(self.stillLocationManager == nil) {
            print("initStillLocation")
            self.stillLocationManager = CLLocationManager()
            self.stillLocationManager.allowsBackgroundLocationUpdates = true
            self.stillLocationManager.pausesLocationUpdatesAutomatically = false
            self.stillLocationManager.distanceFilter = kCLDistanceFilterNone
            self.stillLocationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.stillLocationManager.delegate = self
            self.stillLocationManager.requestAlwaysAuthorization()
        }
    }
    
    public func stopTraceLocation(){
        print("stopTraceLocation")
        if(self.locationManager != nil){
            self.locationManager.stopMonitoringSignificantLocationChanges()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        
        if(manager == self.stillLocationManager) {
            manager.stopUpdatingLocation()
        }
        
        self.opportunisticTrace()
        self.checkHardTraceLocation()
        let newLocation = locations.last
        
        print("enter didUpdateToLocation")
        let conf = self.getConf()
        let positionEnabled = self.getBoolean(dict: conf["position"] as! NSDictionary, key: "enabled")
        if(conf.count > 0 && positionEnabled) {
            let payload = NSMutableDictionary()
            payload.setObject(newLocation!.coordinate.latitude, forKey: "latitude" as NSCopying)
            payload.setObject(newLocation!.coordinate.longitude, forKey: "longitude" as NSCopying)
            payload.setObject(newLocation!.altitude, forKey: "altitude" as NSCopying)
            
            self.crunchEvent(event: "position", payload: payload)
            
            self.stillLocationSent = (manager == self.stillLocationManager)
        }
        print("didUpdateToLocation exit")
        
        
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError")
    }
    
    public func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        print("didFinishDeferredUpdatesWithError")
    }
    
    public func opportunisticTrace(){
        
        //self.tracePower()
        self.traceActivity()
        
        var locationAuth = "notAuthorized"
        let st: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
        if(st == .authorizedAlways){
            locationAuth = "authorized"
        }else if(st == .authorizedWhenInUse){
            locationAuth = "whenInUse"
        }
        var lastLocationAuth: String!
        
        if let lastlocAuth = self.getLastLocationAuth(){
            lastLocationAuth = lastlocAuth
        }
        
        if(lastLocationAuth == nil || locationAuth != lastLocationAuth){
            self.setLastLocationAuth(locationAuth)
            let payload = NSMutableDictionary()
            
            payload.setObject(locationAuth, forKey:"status" as NSCopying)
            self.sendEvent(event: "locationAuth", payload: payload)
        }
        
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
            
            let pushAuth = (settings.authorizationStatus == UNAuthorizationStatus.authorized) ? "authorized" : "notAuthorized"
            
            var lastPushAuth: String!
            //let lastPushAuth = self.getLastPushAuth()
            
            if let lastPAuth = self.getLastPushAuth(){
                lastPushAuth = lastPAuth
            }
                        
            if(lastPushAuth == nil || pushAuth != lastPushAuth){
                self.setLastPushAuth(pushAuth)
                let payload = NSMutableDictionary()
                payload.setObject(pushAuth, forKey:"status" as NSCopying)
                self.sendEvent(event: "pushAuth", payload: payload)
            }
            
        })
        
    }
    
    public func setLastLocationAuth(_ locationAuth: String?){
        if(locationAuth != nil){
            UserDefaults.standard.set(locationAuth, forKey: "NSR_locationAuth")
        }
    }

    public func getLastLocationAuth()->String?{
        let NSR_locationAuth = UserDefaults.standard.object(forKey: "NSR_locationAuth") as? String ?? nil
        return NSR_locationAuth
    }

    public func setLastPushAuth(_ pushAuth: String) {
        UserDefaults.standard.set(pushAuth, forKey: "NSR_pushAuth")
    }

    public func getLastPushAuth()->String?{
        let NSR_pushAuth = UserDefaults.standard.object(forKey: "NSR_pushAuth") as? String ?? nil
        return NSR_pushAuth
    }

    
    
    /* *** ACTION *** */
    
    public func sendAction(action: String, code: String, details: String){
        
        print("sendAction action " + action)
        print("sendAction policyCode " + code)
        print("sendAction details " + details)
        
        /* Authorize */
        self.authorize(completionHandler: { authorized in
            
            if(!authorized){
                return
            }
                        
            /* REQUEST_PAYLOAD */
            let requestPayload = NSMutableDictionary()
            requestPayload.setObject(action, forKey: "action" as NSCopying)
            requestPayload.setObject(code, forKey: "code" as NSCopying)
            requestPayload.setObject(details, forKey: "details" as NSCopying)
            requestPayload.setObject(NSTimeZone.local.localizedName(for: .standard, locale: .current)!, forKey: "timezone" as NSCopying)
            requestPayload.setObject(NSDate().timeIntervalSince1970 * 1000, forKey: "action_time" as NSCopying)
            
            /* REQUEST_HEADERS */
            let headers = NSMutableDictionary()
            headers.setObject(self.getToken(), forKey: "ns_token" as NSCopying)
            headers.setObject(self.getLang(), forKey: "ns_lang" as NSCopying)
        
            self.securityDelegate.secureRequest(endpoint: "action", payload: requestPayload, headers: headers, completionHandler: { responseObject, error in
                if(error == nil){
                    print("sendAction ", responseObject);
                }else{
                    print("sendAction - error: ", error ?? "")
                }
            })
            
            
        })
        
    }
    
    
    
    /* *** EVENT *** */
    
    public func crunchEvent(event: String, payload: NSDictionary){
        
        if (self.getBoolean(dict: getConf(), key: "local_tracking")) {
            print("crunchEvent event " + event)
            print("crunchEvent payload " + payload.description)
            _ = self.snapshot(event: event, payload:payload)
            self.localCrunchEvent(event: event, payload:payload)
        }else{
            self.sendEvent(event: event, payload:payload)
        }
    }
    
    public func localCrunchEvent(event: String, payload: NSDictionary){
        if(self.eventWebView == nil) {
            print("localCrunchEvent Making NSREventWebView")
            self.eventWebView = NSREventWebView()
        }
        print("localCrunchEvent call eventWebView")
        self.eventWebView.crunchEvent(event: event, payload: payload)
    }
    
    
    public func sendEvent(event: String, payload: NSDictionary){
        
        print("sendEvent event: " + event)
        print("sendEvent payload: " + self.dictToJSONString(dictionary: payload))
                
        /* Authorize */
        self.authorize(completionHandler: { authorized in
            
            if(!authorized){
                return
            }
            print( "sendEvent - authorized: " + String(authorized) )
            _ = self.snapshot(event: event, payload: payload)
            
            let eventPayload = NSMutableDictionary()
            eventPayload.setValue(event, forKey: "event")
            let timeZone = NSTimeZone.local.localizedName(for: .standard, locale: .current)! == "Central European Standard Time" ? "Europe/Rome" : NSTimeZone.local.localizedName(for: .standard, locale: .current)!
            eventPayload.setValue(timeZone, forKey: "timezone")
            eventPayload.setValue(Int64.init(NSDate().timeIntervalSince1970 * 1000), forKey: "event_time")
            eventPayload.setObject(payload, forKey: "payload" as NSCopying)
                        
            let devicePayLoad = self.getDevicePayload()
                     
            /* REQUEST_PAYLOAD */
            let requestPayload = NSMutableDictionary()
            requestPayload.setObject(eventPayload, forKey: "event" as NSCopying)
            
            let user = self.getUser()
            let userPayload = NSMutableDictionary()
            userPayload.setValue(user.email, forKey: "email")
            userPayload.setValue(user.code, forKey: "code")
            
            requestPayload.setObject(userPayload, forKey: "user" as NSCopying) //self.getUser().toDict(withLocals: false)
            requestPayload.setObject(devicePayLoad, forKey: "device" as NSCopying)
            if(self.getBoolean(dict: self.getConf(), key: "send_snapshot")){
                requestPayload.setObject(self.snapshot(), forKey: "snapshot" as NSCopying)
            }
            
            /* REQUEST_HEADERS */
            let headers = NSMutableDictionary()
            headers.setObject(self.getToken(), forKey: "ns_token" as NSCopying)
            headers.setObject(self.getLang(), forKey: "ns_lang" as NSCopying)
            
            self.securityDelegate.secureRequest(endpoint: "event", payload: requestPayload, headers: headers, completionHandler: { (responseObject, error) in
                
                if(error == nil && responseObject.count > 0){
                    
                    let pushes = (responseObject["pushes"] != nil) ? responseObject["pushes"] as! NSArray : NSArray()
                    
                    if(!self.getBoolean(dict: responseObject, key: "skipPush")){
                        
                        if(pushes.count > 0){
                            let pushTmp = pushes[0] as! NSDictionary
                            self.showPush(push: pushTmp)
                            if(self.getBoolean(dict: self.getConf(), key: "local_tracking")){
                                self.localCrunchEvent(event: "pushed", payload: pushTmp)
                            }
                        }
                        
                    }else{
                        if(pushes.count > 0){
                            let pushTmp = pushes[0] as! NSDictionary
                            let pushUrl = pushTmp["url"] as! String
                            self.showUrl(url: pushUrl)
                        }
                    }
                    
                }else if(error != nil){
                    print("sendEvent - error: ", error?.localizedFailureReason! ?? "ERROR")
                }
                
            })
            
        })
        
        
    }
    
    public func policies(criteria: NSDictionary, completionHandler: @escaping(_ responseObject: NSDictionary, _ error: NSError?)->()){
         
        print("sendEvent criteria ", criteria);
        
        /* Authorize */
        self.authorize(completionHandler: { authorized in
            
            if(!authorized){
                return
            }
            
            /* REQUEST_PAYLOAD */
            let requestPayload = NSMutableDictionary()
            requestPayload.setObject(criteria, forKey: "criteria" as NSCopying)
            
            /* REQUEST_HEADERS */
            let headers = NSMutableDictionary()
            headers.setObject(self.getToken(), forKey: "ns_token" as NSCopying)
            headers.setObject(self.getLang(), forKey: "ns_lang" as NSCopying)
            
            self.securityDelegate.secureRequest(endpoint: "policies", payload: requestPayload, headers: headers, completionHandler: completionHandler)
            
        })
        
    }
    
    public func archiveEvent(event: String, payload: NSDictionary){
    
        print("archiveEvent event " + event)
        print("archiveEvent payload ", payload)
        
        /* Authorize */
        self.authorize(completionHandler: { authorized in
            
            if(!authorized){
                return
            }
            
            let eventPayload = NSMutableDictionary()
            eventPayload.setObject(event, forKey: "event" as NSCopying)
            eventPayload.setObject(NSTimeZone.local.localizedName(for: .standard, locale: .current)!, forKey: "timezone" as NSCopying)
            eventPayload.setObject(NSDate().timeIntervalSince1970 * 1000, forKey: "event_time" as NSCopying)
            eventPayload.setObject(payload, forKey: "payload" as NSCopying)
                        
            let devicePayLoad = NSMutableDictionary()
            devicePayLoad.setObject(self.uuid(), forKey: "uid" as NSCopying)
            
            let userPayLoad = NSMutableDictionary()
            userPayLoad.setObject(self.getUser().code!, forKey: "code" as NSCopying)
            
                     
            /* REQUEST_PAYLOAD */
            let requestPayload = NSMutableDictionary()
            requestPayload.setObject(eventPayload, forKey: "event" as NSCopying)
            requestPayload.setObject(userPayLoad, forKey: "user" as NSCopying)
            requestPayload.setObject(devicePayLoad, forKey: "device" as NSCopying)
            requestPayload.setObject(self.snapshot(event: event, payload: payload), forKey: "snapshot" as NSCopying)
            
            
            /* REQUEST_HEADERS */
            let headers = NSMutableDictionary()
            headers.setObject(self.getToken(), forKey: "ns_token" as NSCopying)
            headers.setObject(self.getLang(), forKey: "ns_lang" as NSCopying)
        
            
            
            self.securityDelegate.secureRequest(endpoint: "archiveEvent", payload: requestPayload, headers: headers, completionHandler: { responseObject, error in
                if(error != nil){
                    print("archiveEvent - error: ", error ?? "")
                }
            })
            
            
        })
        
    }
    
    
    public func snapshot(event: String, payload:NSDictionary)->NSMutableDictionary{
        let snapshot = self.snapshot()
        snapshot.setValue(payload, forKey: event)
    
        do {
            let encodedData = try NSKeyedArchiver.archivedData(withRootObject: snapshot, requiringSecureCoding: false)
            UserDefaults.standard.set(encodedData, forKey: "NSR_snapshot")
        } catch {
            print("NSR_snapshot set error")
        }
        
        return snapshot
    }

    public func snapshot()->NSMutableDictionary{
        
        var snapshot = NSMutableDictionary()
        
        do {
            if let decoded = UserDefaults.standard.object(forKey: "NSR_snapshot") as? Data{
                snapshot = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSMutableDictionary.self, from: decoded) ?? NSMutableDictionary()
            }
        } catch {
            print("NSR_snapshot get error")
        }
        
        return snapshot
        
    }
    
    
    
    /* *** USER *** */
    
    public func registerUser(user: NSRUser){
    
        print( "registerUser: ", user.toDict(withLocals: true) )
        UserDefaults.standard.removeObject(forKey: "NSR_auth")
        
        self.setUser(user: user)
        
        /* Authorize */
        self.authorize(completionHandler: { authorized in
            
            print( "registerUser - authorized: " + String(authorized) )
            
            if(authorized && self.getBoolean(dict: self.getConf(), key: "send_user")){
                
                print( "sendUser")
                
                let devicePayLoad = self.getDevicePayload()
                                
                let requestPayload = NSMutableDictionary()
                requestPayload.setObject(self.getUser().toDict(withLocals: false), forKey: "user" as NSCopying)
                requestPayload.setObject(devicePayLoad, forKey: "device" as NSCopying)
                
                let headers = NSMutableDictionary()
                headers.setObject(self.getToken(), forKey: "ns_token" as NSCopying)
                headers.setObject(self.getLang(), forKey: "ns_lang" as NSCopying)
                
                self.securityDelegate.secureRequest(endpoint: "register", payload: requestPayload, headers: headers, completionHandler: { responseObject, error in
                    if (error != nil) {
                        print( "sendUser - ", error!)
                    }
                })
                
                
            }
            
        })
                
    }
    
    public func setUser(user: NSRUser){
        UserDefaults.standard.set(user.toDict(withLocals: true), forKey: "NSR_user")
    }

    public func getUser()->NSRUser{
        
        if let userDict = UserDefaults.standard.object(forKey: "NSR_user") as? NSDictionary{
            return NSRUser().initWithDict(dict: userDict)
        }
        
        return NSRUser()
    }
    
    public func forgetUser(){
        
        print("forgetUser")
        
        UserDefaults.standard.removeObject(forKey: "NSR_conf")
        UserDefaults.standard.removeObject(forKey: "NSR_auth")
        UserDefaults.standard.removeObject(forKey: "NSR_appUrl")
        UserDefaults.standard.removeObject(forKey: "NSR_user")
        
        self.initJob()
        
    }
    
    public func authorize(completionHandler: @escaping (_ authorized: Bool)->()) {
        
        let auth = self.getAuth()
        
        if(auth.count > 0 && (auth["expire"] as! Int64)/1000 > Int(round(NSDate().timeIntervalSince1970)) ){
            completionHandler(true)
        } else {
            
            let user = self.getUser()
            let settings = self.getSettings()
            
            if(user.toDict(withLocals: true).count > 0 && settings.count > 0) {
                
                let payload = NSMutableDictionary()
                payload.setObject(user.code!, forKey: "user_code" as NSCopying)
                payload.setObject(settings["code"] as! String, forKey: "code" as NSCopying)
                payload.setObject(settings["secret_key"] as! String, forKey: "secret_key" as NSCopying)
                
                let sdkPayload = NSMutableDictionary()
                sdkPayload.setObject(self.version(), forKey: "version" as NSCopying)
                sdkPayload.setObject(settings["dev_mode"] as! Bool, forKey: "dev" as NSCopying)
                sdkPayload.setObject(self.os(), forKey: "os" as NSCopying)
                
                payload.setObject(sdkPayload, forKey: "sdk" as NSCopying)
                
                _ = NSR.getSharedInstance()
                print("security delegate: " + self.securityDelegate.description)
                
                self.securityDelegate.secureRequest(endpoint: "authorize", payload: payload, headers: NSDictionary(), completionHandler: { responseObject, error in
                
                    if(error != nil){
                        completionHandler(false)
                    }else{
                        
                        let response = NSMutableDictionary.init(dictionary: responseObject)
                        
                        let auth = response["auth"] as! NSDictionary
                        print("authorize auth: ", auth)
                        
                        self.setAuth(auth: auth)
                        
                        let oldConf = self.getConf()
                        let conf = response["conf"] as! NSDictionary
                        print("authorize conf: ", conf)
                        self.setConf(conf: conf)
                        
                        let appUrl = response["app_url"] as! String
                        print("authorize appUrl: ", appUrl)
                        self.setAppUrl(appUrl: appUrl)
                        
                        if( self.needsInitJob(conf: conf, oldConf: oldConf) ){
                            print("authorize needsInitJob")
                            self.initJob()
                        }else{
                            _ = self.synchEventWebView()
                        }
                        
                        completionHandler(true)
                        
                    }
                    
                })
                
            }
            
        }
        
    }
    
    
    
    public func needsInitJob(conf: NSDictionary, oldConf: NSDictionary)->Bool{
        return (oldConf.count == 0 || !conf.isEqual(to: oldConf as! [AnyHashable : Any]) || (eventWebView == nil && getBoolean(dict: conf, key: "local_tracking")) )
    }

    public func showApp(){
        
        let urlTmp = self.getAppUrl()
        
        if(urlTmp != nil){
            self.showUrl(url: urlTmp!, params: nil)
        }
        
    }

    public func showApp(params: NSDictionary){
        
        let urlTmp = self.getAppUrl()
        
        if(urlTmp != nil){
            self.showUrl(url: urlTmp!, params: params)
        }
                
    }

    public func showUrl(url: String){
        self.showUrl(url: url, params: nil)
    }

    public func showUrl(url: String, params: NSDictionary?){
        
        var urlTmp = url
        
        let paramsString = self.dictToJSONString(dictionary: params)
        print("showUrl: " + urlTmp + ", params: " + paramsString)
        
        if(params != nil){
            
            for (key, value) in params!{
                
                let keyString = key as? String ?? ""
                var valueString = value as? String ?? ""
                
                valueString = valueString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
                
                if(urlTmp.contains("?")){
                    urlTmp = urlTmp + "&"
                }else{
                    urlTmp = urlTmp + "?"
                }
                urlTmp = urlTmp + keyString
                urlTmp = urlTmp + "="
                urlTmp = urlTmp + valueString
            }
            
        }
        
        if(self.controllerWebView != nil) {
            self.controllerWebView.navigate(url: urlTmp)
        }else{
            
            self.getMainThreadFromBackground().async{
            
                let rootViewController = UIApplication.shared.keyWindow?.rootViewController ?? UIViewController()
                let topController = self.topViewController(rootViewController: rootViewController)
                
                let controller = NSRControllerWebView()
                controller.url = URL.init(string: urlTmp)
                
                let settingsTmp = self.getSettings()
                    
                if(settingsTmp.count > 0 && settingsTmp["bar_style"] != nil){
                    controller.barStyle = settingsTmp["bar_style"] as? UIStatusBarStyle
                }else{
                    controller.barStyle = topController.preferredStatusBarStyle
                }
                
                if(settingsTmp.count > 0 && settingsTmp["back_color_r"] != nil){
                    let r = settingsTmp["back_color_r"] as! CGFloat
                    let g = settingsTmp["back_color_g"] as! CGFloat
                    let b = settingsTmp["back_color_b"] as! CGFloat
                    let a = settingsTmp["back_color_a"] as! CGFloat
                    let c = UIColor.init(red: r, green: g, blue: b, alpha: a)
                    controller.view.backgroundColor = c
                }else{
                    controller.view.backgroundColor = topController.view.backgroundColor
                }
                
                /* obj-c case fullScreen = 0 */
                controller.modalPresentationStyle = .fullScreen
                
                topController.present(controller, animated: true, completion: nil)
                
            }
            
        }
        
    }

    
    
    /* *** WEB_VIEW *** */
    
    public func closeView(){
        if(self.controllerWebView != nil){
            self.controllerWebView.close()
        }
    }
    
    public func registerWebView(newWebView: NSRControllerWebView){
        if(self.controllerWebView != nil){
            self.controllerWebView.close()
        }
        self.controllerWebView = newWebView
    }

    public func clearWebView(){
        controllerWebView = nil
    }
    
    public func dictToJSONString(dictionary: NSDictionary?)->String{
        
        var dictToJSONString = ""
        
        do {
            
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary ?? NSDictionary(), options: JSONSerialization.WritingOptions.prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8){
                dictToJSONString = jsonString
                return dictToJSONString
            }
            
        } catch {
            print("dictToJSONString - JSONSerialization error")
        }
        
        return dictToJSONString
    }
    
    public func topViewController(rootViewController: UIViewController)->UIViewController{
        
        //return self.topViewController(rootViewController: UIApplication.shared.keyWindow?.rootViewController ?? UIViewController())
        
        if(rootViewController is UINavigationController){
            let navigationController = rootViewController as! UINavigationController
            return self.topViewController(rootViewController: navigationController.viewControllers.last!)
        }
        
        if(rootViewController is UITabBarController){
            let tabBarController = rootViewController as! UITabBarController
            return self.topViewController(rootViewController: tabBarController.selectedViewController!)
        }
        
        if(rootViewController.presentedViewController != nil){
            return self.topViewController(rootViewController: rootViewController.presentedViewController!)
        }
        
        return rootViewController
        
    }
    
    /*
    public func topViewController(rootViewController: UIViewController)->UIViewController{
        
        if(rootViewController is UINavigationController){
            let navigationController = rootViewController as! UINavigationController
            return self.topViewController(rootViewController: navigationController.viewControllers.last!)
        }
        
        if(rootViewController is UITabBarController){
            let tabBarController = rootViewController as! UITabBarController
            return self.topViewController(rootViewController: tabBarController.selectedViewController!)
        }
        
        if(rootViewController.presentedViewController != nil){
            return self.topViewController(rootViewController: rootViewController.presentedViewController!)
        }
        
        return rootViewController
        
    }
    */
    
    /* keys: uid, push_token, os, version, model */
    public func getDevicePayload()->NSMutableDictionary{
        
        let devicePayLoad = NSMutableDictionary()
        
        /* UID */
        let uuid = self.uuid()
        devicePayLoad.setObject(uuid, forKey: "uid" as NSCopying)
        
        /* PUSH_TOKEN */
        let pushToken = self.getPushToken()
        if(!pushToken.isEmpty){
            devicePayLoad.setObject(pushToken, forKey: "push_token" as NSCopying)
        }
        
        /* OS */
        devicePayLoad.setObject(self.os(), forKey: "os" as NSCopying)
        
        /* OS_VERSION */
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let osVersionStringFormat = "[sdk:" + self.version() + "] " + osVersion + " "
        devicePayLoad.setValue(osVersionStringFormat, forKey: "version")
        
        /* System_INFO_MODEL */
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        
        devicePayLoad.setObject(modelCode!, forKey: "model" as NSCopying)
        
        return devicePayLoad
        
    }
    
    
    
    /* *** LOGIN *** */
    public func loginExecuted(url: String){
        let params = NSMutableDictionary()
        params.setObject("yes", forKey:"loginExecuted" as NSCopying)
        self.showUrl(url: url, params: params)
    }

    public func paymentExecuted(paymentInfo: NSDictionary, url: String){
        let params = NSMutableDictionary()
        params.setObject(self.dictToJson(dict: paymentInfo), forKey:"paymentExecuted" as NSCopying)
        self.showUrl(url: url, params: params)
    }
    
    
    
    /* *** PUSHES *** */
    
    public func forwardNotification(response: UNNotificationResponse)->Bool{
        
        let userInfo = response.notification.request.content.userInfo
        if(userInfo.count > 0 && "NSR" == userInfo["provider"] as! String) {
            if(userInfo["url"] != nil){
                self.showUrl(url: userInfo["url"] as! String)
            }
            return true
        }
        
        return false
    }
    
    public func showPush(pid: String, push: NSDictionary, delay: Int){
        
        let mPush = NSMutableDictionary.init(dictionary: push)
        mPush.setObject("NSR", forKey:"provider" as NSCopying)
        let content = UNMutableNotificationContent()
        
        content.title = mPush["title"] as! String
        content.body = mPush["body"] as! String
        content.userInfo = mPush as! [AnyHashable : Any]
        content.sound = UNNotificationSound.init(named: UNNotificationSoundName.init("NSR_push.wav"))
        
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: TimeInterval(delay), repeats: false)
        
        let del = UNUserNotificationCenter.current().delegate
        print("push delegate ", del ?? "")
        
        let request = UNNotificationRequest.init(identifier: pid, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { error in
            if (error != nil) {
                print("push error! ", error?.localizedDescription ?? "UNUserNotificationCenter.current().add - ERROR")
            }
        })
        
    }

    public func killPush(pid: String){
        if(!pid.isEmpty){
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pid])
        }
    }

    public func showPush(push: NSDictionary){
        self.showPush(pid: "NSR", push: push, delay: 1)
    }
    
    
    
    /* *** CONNECTION *** */
    
    public func traceConnection(){
        
        let conf = self.getConf()
        
        if((conf.count > 0)){
            
            var connectionDict: NSDictionary!
            var connEnabled = false
            
            if(conf["connection"] != nil){
                connectionDict = conf["connection"] as? NSDictionary
                if(connectionDict["enabled"] != nil){
                    connEnabled = connectionDict["enabled"] as! Bool
                }
            }
            
            if(connEnabled){
        
                let payload = NSMutableDictionary()
                var connection: String!
                
                if(NSR.nwPathMonitor == nil){
                    NSR.nwPathMonitor = NWPathMonitor()
                }
                
                NSR.nwPathMonitor.pathUpdateHandler = { path in
                   
                    if path.status == .satisfied {
                        
                        print("There is a connection!")
                        
                        if path.usesInterfaceType(.wifi) {
                            // Correctly goes to Wi-Fi via Access Point or Phone enabled hotspot
                            print("Path is Wi-Fi")
                            connection = "wi-fi"
                        } else if path.usesInterfaceType(.cellular) {
                            print("Path is Cellular")
                            connection = "mobile"
                        } else if path.usesInterfaceType(.wiredEthernet) {
                            print("Path is Wired Ethernet")
                            connection = "ethernet"
                        } else if path.usesInterfaceType(.loopback) {
                            print("Path is Loopback")
                            connection = "loopback"
                        } else if path.usesInterfaceType(.other) {
                            print("Path is other")
                            connection = "other"
                        }
                    
                        let lastConnection = self.getLastConnection()
                        
                        if(connection != nil && connection != lastConnection){
                            payload.setObject(connection ?? "", forKey: "type" as NSCopying)
                            self.crunchEvent(event: "connection", payload: payload)
                            self.setLastConnection(lastConnection: connection)
                        }
                        
                        print("traceConnection: " + connection)
                        self.opportunisticTrace()
                        
                    }else{
                        print("No connection!")
                    }
                    
                }
                
                NSR.nwPathMonitor.start(queue: .main)
                
            }
            
        }
       
    }

    public func stopTraceConnection(){
        print("stopTraceConnection")
        
        if(NSR.nwPathMonitor != nil){
            NSR.nwPathMonitor.cancel()
        }
    }

    public func setLastConnection(lastConnection: String){
        UserDefaults.standard.setValue(lastConnection, forKey: "NSR_lastConnection")
    }

    public func getLastConnection()->String?{
        let NSR_lastConnection =  UserDefaults.standard.value(forKey: "NSR_lastConnection")
        
        if(NSR_lastConnection != nil){
            return NSR_lastConnection as? String
        }
        
        return nil
    }
    
    
    
    /* *** ACTIVITY *** */
    
    public func traceActivity(){
        
        let conf = self.getConf()
        
        let activityEnabled = self.getBoolean(dict: conf["activity"] as! NSDictionary, key: "enabled")
        
        if(conf.count > 0 && activityEnabled) {
            self.initActivity()
            
            self.motionActivityManager.startActivityUpdates(to: OperationQueue.main, withHandler: { activity in
                
                print("traceActivity IN")
                
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.sendActivity), object: nil)
                self.perform(#selector(self.sendActivity), with: nil, afterDelay: 8)
                
                if(self.motionActivities.count == 0){
                    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.recoveryActivity), object: nil)
                    self.perform(#selector(self.recoveryActivity), with: nil, afterDelay: 16)
                }
                
                
                self.motionActivities.add(activity!)
                
            })
            
        }
    }
    
    public func initActivity(){
        if(self.motionActivityManager == nil){
            print("initActivity")
            self.motionActivityManager = CMMotionActivityManager()
            self.motionActivities = NSMutableArray()
        }
    }

    @objc public func sendActivity(){
        print("sendActivity")
        self.innerSendActivity()
    }

    @objc public func recoveryActivity(){
        print("recoveryActivity")
        self.innerSendActivity()
    }
    
    public func activityType(activity: CMMotionActivity)->String?{
        if(activity.stationary) {
            return "still"
        } else if(activity.walking) {
            return "walk"
        } else if(activity.running) {
            return "run"
        } else if(activity.cycling) {
            return "bicycle"
        } else if(activity.automotive) {
            return "car"
        }
        return nil
    }
    
    public func activityConfidence(activity: CMMotionActivity)->Int{
        
        if(activity.confidence == CMMotionActivityConfidence.low) {
            return 25
        } else if(activity.confidence == CMMotionActivityConfidence.medium) {
            return 50
        } else if(activity.confidence == CMMotionActivityConfidence.high) {
            return 100
        }
        
        return 0
    }

    public func setLastActivity(lastActivity: String){
        UserDefaults.standard.set(lastActivity, forKey: "NSR_lastActivity")
    }

    public func getLastActivity()->String{
        let NSR_lastActivity = UserDefaults.standard.object(forKey: "NSR_lastActivity") as! String
        return NSR_lastActivity
    }
    
    public func innerSendActivity(){
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(recoveryActivity), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(sendActivity), object: nil)
        
        let conf = self.getConf()
        
        if(conf.count == 0 || self.motionActivities.count == 0){
            return
        }
        
        let confidences = NSMutableDictionary()
        let counts = NSMutableDictionary()
        var candidate: String = ""
        var maxConfidence: Int = 0
        
        for activityTmp in self.motionActivities {
            
            let activity = activityTmp as! CMMotionActivity
            let activityType = self.activityType(activity: activity) ?? ""
            let activityConfidence = self.activityConfidence(activity: activity)
            
            print("activity type " + String(activityType) + " confidence " + String(activityConfidence))
            
            
            let type = self.activityType(activity:activity)
            
            if(type != nil) {
                
                let confidencesTypeInt: Int = Int(confidences[type!] as! String) ?? 0
                let activityConfidenceInt: Int = self.activityConfidence(activity: activity)
                
                let confidence: Int = confidencesTypeInt + activityConfidenceInt
                confidences.setValue(confidence, forKey: type!)
                
                let count = Int(counts[type!] as! String) ?? 0 + 1
                counts.setValue(count, forKey: type!)
                
                
                let weightedConfidence: Int = confidence/count + (count*5)
                if(weightedConfidence > maxConfidence){
                    candidate = type ?? ""
                    maxConfidence = weightedConfidence
                }
            }
        }
        
        self.motionActivities.removeAllObjects()
        
        if(maxConfidence > 100) {
            maxConfidence = 100
        }
        
        let confActivity = conf["activity"] as! NSDictionary
        let confActivityConfidence: Int = confActivity["confidence"] as! Int
        
        let minConfidence: Int = confActivityConfidence
        
        print("candidate " + candidate)
        print("maxConfidence " + String(maxConfidence))
        print("minConfidence " + String(minConfidence))
        print("lastActivity " + self.getLastActivity())
        
        if(!candidate.isEmpty && candidate.compare(self.getLastActivity()) != .orderedSame && maxConfidence >= minConfidence){
            let payload = NSMutableDictionary()
            payload.setObject(candidate, forKey: "type" as NSCopying)
            payload.setObject(maxConfidence, forKey: "confidence" as NSCopying)
            
            self.setLastActivity(lastActivity: candidate)
            self.crunchEvent(event: "activity", payload: payload)
            
            let conf = self.getConf()
            let positionEnabled = self.getBoolean(dict: conf["position"] as! NSDictionary, key: "enabled")
            
            if(positionEnabled && !stillLocationSent && candidate.compare("still") == .orderedSame) {
                self.initStillLocation()
                self.stillLocationManager.startUpdatingLocation()
            }
            
        }
        
        self.motionActivityManager.stopActivityUpdates()
        
    }
    
    
    
    /* *** UTILS *** */
    
    public func logDisabled()->Bool{
        return NSR._logDisabled
    }
    
    public func version()->String{
        return "3.0.1"
    }
    
    public func os()->String{
        return "iOS"
    }
    
    public func getBoolean(dict: NSDictionary, key: String)->Bool{
        
        var boolTmp = false
        
        if(dict.count > 0 && dict[key] != nil) {
            boolTmp = dict[key] as! Bool
        }
        
        return boolTmp
    }
    
    public func getLang()->String{
        return self.getSettings().object(forKey: "ns_lang") as! String
    }
    
    public func setAuth(auth: NSDictionary){
        UserDefaults.standard.set(auth, forKey: "NSR_auth")
    }

    public func getAuth()->NSDictionary{
        return UserDefaults.standard.object(forKey: "NSR_auth") as? NSDictionary ?? NSDictionary()
    }
    
    public func getToken()->String{
        let token = self.getAuth()["token"] as! String
        return token
    }
    
    public func getPushToken()->String{
        let push_token = (self.getSettings()["push_token"] != nil) ? self.getSettings()["push_token"] as! String : ""
        return push_token
    }
    
    public func uuid()->String{
        let uuid = UIDevice.current.identifierForVendor!.uuidString + ""
        print("uuid: " + uuid)
        return uuid
    }
    
    public func setAppUrl(appUrl: String){
        UserDefaults.standard.set(appUrl, forKey: "NSR_appUrl")
    }

    public func getAppUrl()->String?{
        
        var NSR_appUrl: String!
        
        if(UserDefaults.standard.object(forKey: "NSR_appUrl") != nil){
            NSR_appUrl = UserDefaults.standard.object(forKey: "NSR_appUrl") as? String
        }
        
        return NSR_appUrl
    }
    
    public func dictToJson(dict: NSDictionary)->String{
        let jsonData =  (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()
        let jsonDataString = String.init(data: jsonData, encoding: String.Encoding.utf8) ?? ""
        return jsonDataString
    }
    
    
    
    /* *** FENCES *** */
    /*
    public func traceFence(){
        
        let conf = self.getConf()
        
        if(conf.count > 0 && conf["fence"] != nil && self.getBoolean(dict: conf["fence"] as! NSDictionary, key: "enabled")) {
            if(self.fenceLocationManager == nil){
                self.fenceLocationManager = CLLocationManager()
            }
            self.fenceLocationManager.delegate = self
            
            //if(self.fenceLocationManager.responds(to: #selector(requestAlwaysAuthorization)){
                self.fenceLocationManager.requestAlwaysAuthorization()
            //}
            
            self.fenceLocationManager.startUpdatingLocation()
            //self.fenceLocationManager.buildFencesAndRegions()
            
        }
    
    }
    */
    
    
    /* *** POWER *** */
    /*
    public func tracePower(){
        NSDictionary* conf = [self getConf];
        if(conf != nil && [self getBoolean:conf[@"power"] key:@"enabled"]) {
            UIDevice* currentDevice = [UIDevice currentDevice];
            [currentDevice setBatteryMonitoringEnabled:YES];
            UIDeviceBatteryState batteryState = [currentDevice batteryState];
            int batteryLevel = (int)([currentDevice batteryLevel]*100);
            NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
            [payload setObject:[NSNumber numberWithInteger: batteryLevel] forKey:@"level"];
            if(batteryState == UIDeviceBatteryStateUnplugged) {
                [payload setObject:@"unplugged" forKey:@"type"];
            } else {
                [payload setObject:@"plugged" forKey:@"type"];
            }
            if([payload[@"type"] compare:[self getLastPower]] != NSOrderedSame || abs(batteryLevel - [self getLastPowerLevel]) > 5) {
                [self setLastPower:payload[@"type"]];
                [self setLastPowerLevel:batteryLevel];
                [self crunchEvent:@"power" payload:payload];
            }
        }
    }
    */
    
    public func getMainThreadFromBackground()->DispatchQueue{
        if UIApplication.shared.applicationState == .active  {
            return DispatchQueue.main
        }else{
            return DispatchQueue.global(qos: .userInteractive)
        }
    }
    
    
    
}


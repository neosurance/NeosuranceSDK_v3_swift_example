//
//  WFDelegate.swift
//  NSR SDK SwiftExample
//
//  Created by ok_neosurance on 03/11/20.
//

import Foundation
import NSR_SDK_v3_swift

class WFDelegate: NSObject, NSRWorkflowDelegate{
    
    
    func executeLogin(url: String) -> (Bool) {
        UserDefaults.standard.set(url, forKey: "login_url")
        return true
    }
    
    func executePayment(payment: NSDictionary, url: String) -> (NSDictionary) {
        UserDefaults.standard.set(url, forKey: "payment_url")
        return NSDictionary()
    }
    
    func confirmTransaction(paymentInfo: NSDictionary) {
        
    }
    
    func keepAlive(){
        print("keepAlive")
    }
    
    func goTo(area: String){
        print("goTo: " + area)
    }
    
}

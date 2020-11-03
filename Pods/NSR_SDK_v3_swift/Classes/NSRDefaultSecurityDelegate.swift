//
//  NSRDefaultSecurityDelegate.swift
//  NSR SDK
//
//  Created by ok_neosurance on October 2020.
//

import UIKit
import WebKit

public class NSRDefaultSecurityDelegate: NSObject, NSRSecurityDelegate{
    
    public func secureRequest(endpoint: String, payload: NSDictionary, headers: NSDictionary, completionHandler: @escaping (NSDictionary, NSError?) -> ()) {
        
        print("NSRDefaultSecurityDelegate --> secureRequest --> endpoint: " + endpoint)
        
        let settings = NSR.getSharedInstance().getSettings()
                
        let base_url = settings["base_url"] as! String
        let url = base_url + endpoint
        
        callApi(payload: payload as! Dictionary<String, Any>, url: url, method: "POST", headers: headers, completionHandler: completionHandler)
        
    }
    
    public func callApi(payload:Dictionary<String,Any>, url:String, method:String, headers:NSDictionary, completionHandler: @escaping (NSDictionary, NSError?)->()) {
        
        let urlTmp = url.replacingOccurrences(of: " ", with: "%20")
        let urlObj = URL(string: urlTmp)!
        var request = URLRequest(url: urlObj)
        request.httpMethod = method
        
        for key in headers.allKeys{
            request.setValue((headers[key] as! String), forHTTPHeaderField: key as! String)
        }
        
        if(method == "POST" || method == "PUT"){
            do{
                request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            }catch {
                print(NSLocalizedString("Payload JSONFormatError", comment: ""))
            }
        }
        
        //[request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-type"];
        //[request setValue:[NSString stringWithFormat:@"%d", (int)[jsonString length]] forHTTPHeaderField:@"Content-length"];
        request.addValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")

        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            print(response ?? "")
            do {
                
                
                var errorTmp: NSError!
                var statusCode = -1
                
                if let httpResponse = response as? HTTPURLResponse {
                    statusCode = httpResponse.statusCode
                }
                
                if(error != nil){
                    print("Error: " + (error?.localizedDescription ?? "") )
                    errorTmp = error as NSError?
                    print("ErrorTmp: " + errorTmp.localizedDescription)
                    completionHandler(NSDictionary(), errorTmp)
                }
                
                if(data != nil && errorTmp == nil && statusCode == 200){
                    
                    //let dataString = String(data: data!, encoding: .utf8)
                    let json = try JSONSerialization.jsonObject(with: data!) as! NSDictionary
                    print(json)
                    completionHandler(json, nil)
                    
                }else{
                    print("Data is nil")
                    completionHandler(NSDictionary(), errorTmp)
                }
                
            } catch {
                print(error.localizedDescription)
                if(error.localizedDescription == NSLocalizedString("JSONFormatError", comment: "")){
                    print(error.localizedDescription)
                    let data = NSDictionary()
                    completionHandler(data, error as NSError)
                }else{
                    print(error.localizedDescription)
                    let data = NSDictionary()
                    completionHandler(data, error as NSError)
                }
            }
        })

        task.resume()
        
    }
    
}


//
//  NSRWebView.swift
//  NSR SDK
//
//  Created by ok_neosurance on October 2020.
//

import UIKit
import WebKit

public class NSRWebView: WKWebView{
    
    public func safeAreaInsets()->UIEdgeInsets{
        return UIEdgeInsets.init(top: CGFloat(0), left: CGFloat(0), bottom: CGFloat(0), right: CGFloat(0))
    }
    
}


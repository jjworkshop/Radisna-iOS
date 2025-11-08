//
//  SceneDelegate+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// SceneDelegateを拡張
extension SceneDelegate {
    
    static var shared: SceneDelegate {
        UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate
    }
    
}

//
//  LatLon.swift
//  共通メソッド群
//
//  Created by Mitsuhiro Shirai on 2019/01/31.
//  Copyright © 2019年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit
import CoreLocation

// 座標アイテム
class LatLon {
    var lat: Double!
    var lon: Double!
    
    // Constructor
    init (lat: Double, lon: Double) {
        self.lat  = lat
        self.lon = lon
    }
    init (location: CLLocationCoordinate2D) {
        self.lat  = location.latitude
        self.lon = location.longitude
    }
}

//
//  Array+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// Arrayを拡張
extension Array where Element: Hashable {
    
    // 配列の差分を取得
    typealias E = Element
    func diff(_ other: [E]) -> [E] {
        let all = self + other
        var counter: [E: Int] = [:]
        all.forEach { counter[$0] = (counter[$0] ?? 0) + 1 }
        return all.filter { (counter[$0] ?? 0) == 1 }
    }
    
}

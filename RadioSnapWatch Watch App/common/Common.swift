//
//  Common.swift
//  RadioSnapWatch Watch App
//
//  Created by Mitsuhiro Shirai on 2025/06/11.
//

import UIKit

struct Com {
    // デバッグプリント
    static func XLOG(_ obj: Any?,
              file: String = #file,
              function: String = #function,
              line: Int = #line) {
        #if DEBUG
        // デバッグモードのみ出力
        let pathItem = String(file).components(separatedBy: "/")
        let fname = pathItem[pathItem.count-1].components(separatedBy: ".")[0]
        if let obj = obj {
            print("D:[\(fname):\(function) #\(line)] : \(obj)")
        } else {
            print("D:[\(fname):\(function) #\(line)]")
        }
        #endif
    }
}

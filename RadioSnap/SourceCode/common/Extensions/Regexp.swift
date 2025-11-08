//
//  Regexp.swift
//   Regexp
//
//  Created by Mitsuhiro Shirai on 2019/03/11.
//  Copyright © 2019年 Mitsuhiro Shirai. All rights reserved.
//

/*
    Extensions.swiftのString拡張チェックに正規表現を利用するために利用している
    以下からコードは貰ってきてちょっと改良
    https://qiita.com/eKushida/items/24bb42ebc18d4eb69ef1
 
 */

import UIKit

infix operator =~
infix operator !~

func =~(lhs: String, rhs: String) -> Bool {
    guard let regex = try? NSRegularExpression(pattern: rhs,
                                               options: NSRegularExpression.Options()) else {
                                                return false
    }
    
    return regex.numberOfMatches(in: lhs,
                                 options: NSRegularExpression.MatchingOptions(),
                                 range: NSRange(location: 0, length: lhs.count)) > 0
}

func !~(lhs: String, rhs: String) -> Bool {
    return !(lhs=~rhs)
}


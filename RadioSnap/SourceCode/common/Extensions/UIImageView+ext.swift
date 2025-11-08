//
//  UIImageView+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit
import Alamofire
import AlamofireImage

// UIImageViewを拡張
extension UIImageView {
    
    // AlamofireImage を利用したイメージ設定
    // これを利用するには、pod で AlamofireImageライブラリを追加しなくてはダメ
    func af_setImage_ex(with url: URL,
                            imageDownloader: ImageDownloader?,
                            placeholderImage: UIImage? = nil,
                            imageTransition: ImageTransition = .noTransition,
                            progress: ImageDownloader.ProgressHandler? = nil,
                            completion: ((AFIDataResponse<UIImage>) -> Void)? = nil) {
        // イメージダウンローダーを設定
        af.imageDownloader = imageDownloader
        // イメージの取得＆設定
        af.setImage(
            withURL: url,
            placeholderImage: nil,
            filter: nil,
            progress: progress,
            progressQueue: DispatchQueue.main,
            imageTransition: imageTransition,
            runImageTransitionIfCached: false,
            completion: completion)
    }
    
}

//
//  UIImage+ext.swift
//
//  Created by Mitsuhiro Shirai on 2022/07/13.
//

import Foundation
import UIKit

// UIImageを拡張
extension UIImage {
    
    // イメージをURLから取得
    public convenience init(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            self.init(data: data)!
            return
        } catch let err {
#if DEBUG
            print("UIImage URL Error : \(err.localizedDescription)")
#endif
        }
        self.init()
    }
    
    // tintカラーを変更
    func tint(_ color: UIColor) -> UIImage {
        // 注意: 劣化するので、必要なら以下のように利用する
        // image?.resize(CGSize(..)).tint(UIColor...
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        let drawRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIRectFill(drawRect)
        draw(in: drawRect, blendMode: .destinationIn, alpha: 1)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage!
    }
    
    // 指定範囲をクリッピングして取得
    func cropping(to: CGRect) -> UIImage? {
        var opaque = false
        if let cgImage = cgImage {
            switch cgImage.alphaInfo {
            case .noneSkipLast, .noneSkipFirst:
                opaque = true
            default:
                break
            }
        }
        UIGraphicsBeginImageContextWithOptions(to.size, opaque, scale)
        draw(at: CGPoint(x: -to.origin.x, y: -to.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    // イメージをリサイズ
    func resize(_ reSize:CGSize)->UIImage {
        //UIGraphicsBeginImageContext(reSize);
        UIGraphicsBeginImageContextWithOptions(reSize,false,UIScreen.main.scale);
        self.draw(in: CGRect(x: 0, y: 0, width: reSize.width, height: reSize.height));
        let reSizeImage:UIImage! = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return reSizeImage;
    }
    
    // イメージを回転
    func rotatedByDegrees(degrees: CGFloat) -> UIImage {
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        bitmap.rotate(by: (degrees * CGFloat.pi / 180))
        bitmap.scaleBy(x: 1.0, y: -1.0)
        bitmap.draw(self.cgImage!, in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    // イメージを左右反転
    func flipHorizontal() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let imageRef = self.cgImage
        let context = UIGraphicsGetCurrentContext()
        context?.translateBy(x: size.width, y:  size.height)
        context?.scaleBy(x: -1.0, y: -1.0)
        context?.draw(imageRef!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let flipHorizontalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return flipHorizontalImage!
    }

    // イメージ保存（PNG）
    func saveImage2Png(_ url: URL) -> Bool {
        let data = self.pngData()  // to Data
        do {
            // save
            try data?.write(to: url, options: .atomic)
            return true
        }
        catch let error as NSError {
            // エラー
#if DEBUG
            print(error)
#endif
        }
        return false
    }

}


//
//  ProgramView.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/01.
//


import UIKit
import WebKit
import RxWebKit

class ProgramView: CommonView {
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var rightButton1: UIButton!
    @IBOutlet weak var rightButton2: UIButton!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var infoLabel: UILabel!
    
    // フレッシュコントローラー
    let refreshControl = UIRefreshControl()
    
    // レイアウト完了処理
    override func firstlayoutSubviews() {
        // ボタンにアイコン設定
        let size = CGSize(width: 22, height: 22)
        leftButton.setImage(named: AppCom.pdf_circle_down, color: UIColor.label, size: size)
        rightButton1.setImage(named: AppCom.pdf_arrow_left, color: UIColor.label, size: size)
        rightButton2.setImage(named: AppCom.pdf_arrow_right, color: UIColor.label, size: size)
        // WEBビューのスクローラーにリフレッシュコントローラーを付ける
        webView.scrollView.refreshControl = refreshControl
    }
}

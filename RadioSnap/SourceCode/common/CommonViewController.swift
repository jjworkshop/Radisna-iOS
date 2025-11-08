//
//  CommonViewController.swift
//  UIViewControllerのサブクラス（共通部分のインプリメント）
//
//  Created by Mitsuhiro Shirai on 2019/03/13.
//  Copyright © 2018年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Alamofire

/*
 アプリの、ViewControllerので共通化する部分をサブクラス化してインプリメントしておく
 */

class CommonViewController: UIViewController {
    
    var arg: Any?
    internal var isFirstLayout = true
    let disposeBag = DisposeBag()
        
    private let iconSize: CGSize = CGSize(width: 20, height: 20)
    var leftButtonItem:UIBarButtonItem? = nil       // ナビゲーションバーの左ボタン
    var titleButtonItem:UIBarButtonItem!            // ナビゲーションバーのタイトル
    var rightButtonItem1:UIBarButtonItem? = nil     // ナビゲーションバーの右ボタン1
    var rightButtonItem2:UIBarButtonItem? = nil     // ナビゲーションバーの右ボタン2
    var rightButtonItem3:UIBarButtonItem? = nil     // ナビゲーションバーの右ボタン3
    let barTitle = UILabel()
    private var titleWidth:CGFloat!
    
    // オフライン通知
    let offLine: PublishSubject<Bool> = PublishSubject()
    
    // アクセサリキーボード
    private var keyboardHeader: UIView!
    var kbAccessory:UIView {
        get {
            return keyboardHeader
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // アクセサリキーボードにCloseボタンを付けて用意しておく
        keyboardHeader = UIView(frame: CGRect(x:0, y:0, width:Com.windowSize().width, height:40))
        keyboardHeader.backgroundColor = UIColor.systemGray2
        let keyboardCloseButton = UIButton()
        keyboardCloseButton.setTitle(NSLocalizedString("↓ 閉じる", comment:""), for: .normal)
        keyboardCloseButton.contentHorizontalAlignment = .right
        keyboardCloseButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        keyboardCloseButton.frame = CGRect(x:keyboardHeader.frame.size.width - 208, y:0, width:200, height:40)
        keyboardCloseButton.setTitleColor(UIColor.label, for: .normal)
        keyboardHeader.addSubview(keyboardCloseButton)
        
        // アクセサリキーボードのCloseボタン押下処理
        keyboardCloseButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.closeSoftKyeboard()
            })
            .disposed(by: disposeBag)
        
        /*
         アクセサリキーボードをフィールドに付けるには、ViewControllerから以下のようにする
         ↓
         anyField.inputAccessoryView = kbAccessory
         */

    }
    
    // 左にボタン１つ、右に１つまでの場合
    func viewDidLoad(title:String?, L1:String?, R1:String?) {
        super.viewDidLoad()
        titleWidth = 220 + Com.windowSize().width - 320 // 220 は横 320サイズでの限界値（右にボタン1つまで）
        didLoad(title: title, L1: L1, R1: R1, R2: nil, R3: nil)
    }

    // 左にボタン１つ、右に２つまでの場合
    func viewDidLoad(title:String?, L1:String?, R1:String?, R2:String?) {
        super.viewDidLoad()
        titleWidth = 160 + Com.windowSize().width - 320 // 160 は横 320サイズでの限界値（右にボタン2つまで）
        didLoad(title: title, L1: L1, R1: R1, R2: R2, R3: nil)
    }
    
    // 左にボタン１つ、右に３つまでの場合
    func viewDidLoad(title:String?, L1:String?, R1:String?, R2:String?, R3:String?) {
        super.viewDidLoad()
        titleWidth = 100 + Com.windowSize().width - 320 // 100 は横 320サイズでの限界値（右にボタン3つまで）
        didLoad(title: title, L1: L1, R1: R1, R2: R2, R3: R3)
    }
    
    // viewDidLoad 完了時の処理
    private func didLoad(title:String?, L1:String?, R1:String?, R2:String?, R3:String?) {
        super.viewDidLoad()
        
        var leftButtons = Array<Any>()
        var rightButtons = Array<Any>()
        let caption = title != nil ? title : ""
        
        // タイトルのフォントサイズ計算（文字数により可変：何故かLabelの可変フォント設定が効かないので）
        let fontSize: CGFloat = AppCom.calcTextFontSize(caption, titleWidth: self.titleWidth)
        
        // デフォルトの戻るボタンは使わない
        self.navigationItem.hidesBackButton = true
        
        // タイトル作成
        barTitle.text = caption
        barTitle.frame = CGRect(x:0, y:0, width:titleWidth, height:44)
        barTitle.font = UIFont.systemFont(ofSize: fontSize)
        barTitle.textColor = UIColor.label
        barTitle.numberOfLines = 0
        barTitle.adjustsFontSizeToFitWidth = true
        barTitle.lineBreakMode = .byTruncatingTail          // 末尾に ...
        barTitle.textAlignment = .left  // 左詰
        let titleButtonItem = UIBarButtonItem(customView: barTitle)
        leftButtons.append(titleButtonItem)
        
        // ナビゲーションバーのボタンの作成
        if (L1 != nil) {
            let leftButtonImage = UIImage(named: L1!)?.withRenderingMode(.alwaysTemplate)
            leftButtonItem = UIBarButtonItem()
            leftButtonItem!.image = leftButtonImage?.resize(iconSize)
            leftButtonItem!.style = UIBarButtonItem.Style.plain
            leftButtonItem!.tintColor = UIColor.label
            leftButtons.insert(leftButtonItem!, at: 0)
        }
        if (R3 != nil) {
            let rightButtonImage3 = UIImage(named: R3!)?.withRenderingMode(.alwaysTemplate)
            rightButtonItem3 = UIBarButtonItem()
            rightButtonItem3!.image = rightButtonImage3?.resize(iconSize)
            rightButtonItem3!.style = UIBarButtonItem.Style.plain
            rightButtonItem3!.tintColor = UIColor.label
            rightButtons.append(rightButtonItem3!)
        }
        if (R2 != nil) {
            let rightButtonImage2 = UIImage(named: R2!)?.withRenderingMode(.alwaysTemplate)
            rightButtonItem2 = UIBarButtonItem()
            rightButtonItem2!.image = rightButtonImage2?.resize(iconSize)
            rightButtonItem2!.style = UIBarButtonItem.Style.plain

            rightButtonItem2!.tintColor = UIColor.label
            rightButtons.append(rightButtonItem2!)
        }
        if (R1 != nil) {
            let rightButtonImage1 = UIImage(named: R1!)?.withRenderingMode(.alwaysTemplate)
            rightButtonItem1 = UIBarButtonItem()
            rightButtonItem1!.image = rightButtonImage1?.resize(iconSize)
            rightButtonItem1!.style = UIBarButtonItem.Style.plain
            rightButtonItem1!.tintColor = UIColor.label
            rightButtons.append(rightButtonItem1!)
        }
        
        // ナビゲーションバーにボタンパーツ配置
        self.navigationItem.title = nil
        self.navigationItem.setLeftBarButtonItems(leftButtons as? [UIBarButtonItem], animated: true)
        self.navigationItem.setRightBarButtonItems(rightButtons as? [UIBarButtonItem], animated: true)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if (!isFirstLayout) {return}    // 最初だけ
        isFirstLayout = false

        // レイアウト確定後の最初の処理
        firstlayoutSubviews()
    }
    
    // サブクラスでオーバーライドする
    open func firstlayoutSubviews() {}
        
    // タイトル変更
    func setCaption(_ title: String?) {
        let fontSize: CGFloat = AppCom.calcTextFontSize(title, titleWidth: titleWidth)
        barTitle.font = UIFont.systemFont(ofSize: fontSize)
        barTitle.text = title ?? ""
    }
    
    // ボタンのイメージを変更
    func changeButtonImage(_ buttonItem: UIBarButtonItem?, imgName: String) {
        let image = UIImage(named: imgName)
        buttonItem?.image = image?.resize(iconSize)
    }
    
    // 戻る
    open func goBack() {
        self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - オフラインチェック（スレッドで処理）
    
    func checkOffline() {
        DispatchQueue.global(qos: .default).async {
            let net = NetworkReachabilityManager()
            net?.startListening(onUpdatePerforming: { [weak self]status in
                switch status {
                case .unknown:
                    self?.offLine.onNext(true)
                case .notReachable:
                    self?.offLine.onNext(true)
                case .reachable(_):
                    if ((net?.isReachableOnEthernetOrWiFi) != nil) {
                        Com.XLOG("ONLINE: Ethernet or WiFi")
                    }
                    else if(net?.isReachableOnCellular) != nil {
                        Com.XLOG("ONLINE: Career")
                    }
                    self?.offLine.onNext(false)
                }
            })
        }
    }
    
    // MARK: - キーボード関連
    
    // キーボードを閉じる
    func closeSoftKyeboard() {
        if let responder = Com.findFirstResponder(self.view) {
            responder.resignFirstResponder()
        }
    }
    
}

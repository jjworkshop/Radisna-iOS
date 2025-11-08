//
//  ModalViewController.swift
//  Modalで使うUIViewControllerのサブクラス（共通部分のインプリメント）
//
//  Created by Mitsuhiro Shirai on 2019/03/13.
//  Copyright © 2018年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Alamofire

class ModalViewController: UIViewController {

    let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let sceneDelegate = SceneDelegate.shared
    let ud = UserDefaults.standard
    var argument: Any? = nil    // 受け渡されるデータ

    internal var isFirstLayout = true
    var disposeBag = DisposeBag()
        
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
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if (!isFirstLayout) {return}    // 最初だけ
        isFirstLayout = false

        // レイアウト確定後の最初の処理
        firstlayoutSubviews()
    }
    
    // サブクラスでオーバーライドする
    open func firstlayoutSubviews() {}
            
    // 戻る
    open func goBack() {
        self.disposeBag = DisposeBag()  // シングルトンに対応するため、画面を閉じるときにクリアしている
        Com.XLOG("ModalViewController: disposeBag was cleared!")
        self.dismiss(animated: true, completion: nil)
    }
    
    deinit {
        Com.XLOG("ModalViewController: DEINIT!!")
    }
    
    // MARK: - キーボード関連
    
    // キーボードを閉じる
    func closeSoftKyeboard() {
        if let responder = Com.findFirstResponder(self.view) {
            responder.resignFirstResponder()
        }
    }
    
}

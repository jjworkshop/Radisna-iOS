//
//  AppCommonViewController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//  Copyright © 2019年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit
import RxSwift

class AppCommonViewController: CommonViewController {

    let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    let sceneDelegate = SceneDelegate.shared
    let ud = UserDefaults.standard
    var argument: Any? = nil    // 受け渡されるデータ
        
    override func firstlayoutSubviews() {
        super.firstlayoutSubviews()
        
        // デバイスのオフラインを通知
        offLine.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] off in
                Com.XLOG(off ? "×オフライン" : "●オンライン")
                if (off) {
                    self.oflineInformation()
                }
                else {
                    self.hasBeenOnline()
                }
            })
            .disposed(by: disposeBag)
        
    }
    
    // オフライン時の処理
    func oflineInformation() {
        let title = NSLocalizedString("オフラインではアプリを利用できません\n再チェック後、オンラインになったらリロードして下さい", comment:"")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("オンライン再チェック", comment:""), style: .default, handler: {
            (action: UIAlertAction!) in
            // オフラインチェック
            self.checkOffline()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("キャンセル", comment:""), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // 前面になった
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // オフラインチェック
        checkOffline()
    }
    
    // オンラインになった時の処理（サブクラスでオーバーライド）
    open func hasBeenOnline() {}

    deinit {
        Com.XLOG("AppCommonViewController: DEINIT!!")
    }
}

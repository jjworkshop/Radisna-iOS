//
//  PlaylistMenuViewController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/02.
//

import UIKit

class PlaylistMenuViewController: ModalViewController {
    
    var mainView: PlaylistMenuView!
    var delegate: PlaylistMenuViewControllerDelegate? = nil
    var item: DownloadItem? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mainView = self.view as? PlaylistMenuView
        
        // オブザーバー登録
        setupObservers()
        // 初期設定
        if let item = self.item {
            mainView.setup(item)
        }
    }
    
    // オブザーバーの登録
    private func setupObservers() {
        
        // 閉じるボタン
        mainView.closeBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.goBack()
            })
            .disposed(by: disposeBag)
        
        // 削除ボタン
        mainView.deleteBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                if let item = self.item {
                    delegate?.deleteItem(uuid: item.uuid)
                }
                self.goBack()
            })
            .disposed(by: disposeBag)
        
        // 共有ボタン
        mainView.shareBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                if let item = self.item {
                    delegate?.shareItem(uuid: item.uuid)
                }
                self.goBack()
            })
            .disposed(by: disposeBag)
    }

}

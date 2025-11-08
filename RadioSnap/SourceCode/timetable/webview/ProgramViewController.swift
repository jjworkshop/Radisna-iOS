//
//  ProgramViewController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/01.
//

import UIKit
import RxSwift
import RxCocoa
import WebKit

class ProgramViewController: ModalViewController {

    private var mainView: ProgramView!
    var urlStr: String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mainView = self.view as? ProgramView
        // target=_blank 対策
        mainView.webView.uiDelegate = self
        
        // オブザーバー登録
        setupObservers()
        
        // URLを読み込み
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 遅延処理（画面が表示されてからprogressを動かしたいので）
            self.loadUrl()
        }
    }
    
    // 初期ページ読込
    private func loadUrl() {
        Com.XLOG("番組情報 URL: \(urlStr ?? "none")")
        if let urlStr = self.urlStr {
            if let url = URL(string: urlStr) {
                let request = URLRequest(url: url)
                mainView.webView.load(request)
                return
            }
        }
        // エラーの場合
        mainView.infoLabel.isHidden = false
        mainView.infoLabel.text = "WEBページを表示できません"
        mainView.infoLabel.textColor = UIColor.systemRed
        if let urlStr = self.urlStr {
            SimplePopup.showAlert(
                on: self.view,
                title: "確認",
                message: "番組情報をアプリから開けません。ブラウザで開きますか？",
                confirmTitle: "はい",
                cancelTitle: "いいえ",
                onConfirm: { _ in
                    AppCom.showSite(url: urlStr)
                    super.goBack()
                }
            )
        }
    }
    
    // オブザーバーの登録
    private func setupObservers() {
        
        // 戻るボタン
        mainView.leftButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.goBack()
            })
            .disposed(by: disposeBag)
        
        // 前のWEBページへ
        mainView.rightButton1.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.mainView.webView.goBack()
            })
            .disposed(by: disposeBag)
        
        // 先のWEBページへ
        mainView.rightButton2.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.mainView.webView.goForward()
            })
            .disposed(by: disposeBag)
        
        // プログレスバーの表示制御、ゲージ制御、アクティビティインジケータ表示制御で使うため、一旦オブザーバを定義
        let loadingObservable = mainView.webView.rx.loading
            .share()
        
        // プログレスバーの表示・非表示
        loadingObservable
            .map { return !$0 }
            .observeOn(MainScheduler.instance)
            .bind(to: mainView.progressView.rx.isHidden)
            .disposed(by: disposeBag)

        // タイトル表示（サブタイトル）
        mainView.webView.rx.title
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] title in
                self.mainView.titleLabel.text = title
            })
            .disposed(by: disposeBag)
        
        // プログレスバーのゲージ制御
        mainView.webView.rx.estimatedProgress
            .map { return Float($0) }
            .observeOn(MainScheduler.instance)
            .bind(to: mainView.progressView.rx.progress)
            .disposed(by: disposeBag)
        
        // 前後のページ移動制御
        mainView.webView.rx.canGoBack
            .subscribe(onNext: { [unowned self] enabel in
                mainView.rightButton1?.isEnabled = enabel
            })
            .disposed(by: disposeBag)
        mainView.webView.rx.canGoForward
            .subscribe(onNext: { [unowned self] enabel in
                mainView.rightButton2?.isEnabled = enabel
            })
            .disposed(by: disposeBag)

        // リフレッシュコントローラー
        mainView.refreshControl.rx.controlEvent(.valueChanged).asObservable()
            .map({ [unowned self]() -> Bool in self.mainView.refreshControl.isRefreshing })
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG("refreshControl: [\(on)]")
                // リロード
                self.loadUrl()
                self.mainView.refreshControl.endRefreshing()
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - WKUIDelegate
// target=_blank 対策
extension ProgramViewController: WKUIDelegate {
   func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
       if navigationAction.targetFrame == nil {
           webView.load(navigationAction.request)
       }
       return nil
   }
}


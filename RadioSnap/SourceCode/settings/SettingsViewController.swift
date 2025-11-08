//
//  SettingsViewController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/09.
//

import UIKit
import FFPopup
import RxSwift
import RxCocoa

class SettingsViewController: AppCommonViewController {
    
    // デリゲート
    var delegate: SettingsViewControllerDelegate? = nil
    
    private var appNewsExist = false    // アプリニュースあり
    private var tapCount = 0
    private var restoredCount = -1
    private var licensed: Bool? = nil
    
    private var holder : SettingTableHolder!
    private let presenter = SettingsPresenter()
    
    override func viewDidLoad() {
        super.viewDidLoad(
            title: NSLocalizedString("設定", comment:""),
            L1:AppCom.pdf_circle_back, R1:nil, R2:nil)
        
        // SettingTableHolder（UITableVIewControllerのサブクラス）の参照を取得
        holder = children[0] as? SettingTableHolder

        // 設定の初期値
        setSettings()

        // オブザーバー登録
        setupObservers()
                
        // ロゴを配置
        let logoTextView = UILabel(frame: CGRect(x: 0, y: view.bounds.size.height - holder.sectionFooterHeight - Com.safeHightBottom,
                                                 width: view.bounds.width, height: holder.sectionFooterHeight))
        logoTextView.text = "© JJworkshop."
        logoTextView.textAlignment = .center
        logoTextView.textColor = UIColor.label
        logoTextView.backgroundColor = UIColor.systemGray6
        view.addSubview(logoTextView)
        
        // アプリニュースの最新投稿のチェック
        checkAppNewsExist()
        // ライセンスキーの確認
        checkLicense() { email in
            Com.XLOG(email != nil ? "ライセンス:\(email ?? "unknown")" : "ライセンス無し")
            self.licensed = (email != nil)
        }
    }
    
    deinit {
        Com.XLOG("Settings: DEINIT!!")
    }
    
    // オブザーバーの登録
    private func setupObservers() {
        
        // アプリの稼働状態チェック
        sceneDelegate.wakeupMain.asObservable()
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG(on ? "Setting-ウェイクアップ" : "Setting-スリープ")
                if on {
                    // アプリニュースの最新投稿のチェック
                    self.checkAppNewsExist()
                }
            })
            .disposed(by: disposeBag)
        
        // ナビゲーションバーの戻るボタン
        leftButtonItem?.rx.tap
            .subscribe(onNext: { [unowned self] in
                // 前の画面に戻る
                self.goBack()
            })
            .disposed(by: disposeBag)
        
        // キャッシュクリアボタン
        holder.clearCacheBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.cleatCache()
            })
            .disposed(by: disposeBag)
        
        // ログ共有ボタン
        holder.logShareBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.shareLogs()
            })
            .disposed(by: disposeBag)
        
        // セルのタップ
        holder.celTaped.asObserver()
            .subscribe(onNext: { [unowned self] indexPath in
                Com.XLOG("セルをタップ: [\(indexPath)]")
                switch (indexPath) {
                case IndexPath(row: 0, section: 1):
                    // カードのバックアップと復元
                    self.showCardBackupRestore()
                case IndexPath(row: 1, section: 1):
                    // ライセンスキー設定
                    self.showLicenseDialog()
                case IndexPath(row: 2, section: 1):
                    // 自前のヘルプページへ遷移
                    self.presenter.showSupportSite()
                case IndexPath(row: 3, section: 1):
                    // アプリの最新ニュースページへ遷移
                    self.presenter.showAppNewsSite()
                case IndexPath(row: 4, section: 1):
                    // 5タップアプリのUUIDをコピー
                    tapCount += 1
                    if tapCount >= 5 {
                        UIPasteboard.general.string = appDelegate.appUUID
                        Com.shortMessage("アプリ固有のIDをコピーしました")
                        tapCount = 0
                    }
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
        
        // 起動時にダウンロード画面を初期表示
        holder.startModeSwitch.rx.isOn
            .distinctUntilChanged()
            .subscribe(onNext: { /*[unowned self]*/ isOn in
                AppCom.downloadFirst = isOn
                Com.XLOG("startMode: [\(isOn)]")
            })
            .disposed(by: disposeBag)
        
        
        // ダウロード時に画面を暗くする
        holder.keepScreenSwitch.rx.isOn
            .distinctUntilChanged()
            .subscribe(onNext: { /*[unowned self]*/ isOn in
                AppCom.keepScreenOn = isOn
                Com.XLOG("keepScreen: [\(isOn)]")
            })
            .disposed(by: disposeBag)
        
        // ログモード
        holder.logModeSwitch.rx.isOn
            .distinctUntilChanged()
            .subscribe(onNext: { [unowned self] isOn in
                AppCom.logMode = isOn
                holder.logShareBtn.isEnabled = isOn
                Com.XLOG("logMode: [\(isOn)]")
            })
            .disposed(by: disposeBag)
    
        // アプリの外観
        holder.appearanceSegment.rx.selectedSegmentIndex
            .distinctUntilChanged()
            .subscribe(onNext: { [unowned self] idx in
                ud.set(idx, forKey: AppCom.USER_DEFKEY_APPEARANCE_MODE)
                Com.changAppearanceMode(idx)
                Com.XLOG("appearanceMode: [\(idx)]")
            })
            .disposed(by: disposeBag)

    }
    
    // ライセンス確認
    private func checkLicense(completion: ((String?) -> Void)? = nil) {
        if let key = AppCom.licenseKey {
            SettingsPresenter.checkLicenseKey(key) { email in
                if let email = email {
                    self.holder.licenseKeyLabel.text = "登録ユーザー: \(email)"
                    self.licensed = true
                }
                completion?(email)
            }
        } else {
            completion?(nil)
        }
    }
    
    // ライセンスキー設定ダイアログ
    private func showLicenseDialog() {
        if licensed == nil || licensed! { return }
        let alert = UIAlertController(
            title: "ライセンスキー設定",
            message: nil,
            preferredStyle: .alert
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let message = "\nドネーション完了通知メールに記載のライセンスキーをコピー＆ペーストして下さい。"
        let attributedMessage = NSAttributedString(
            string: message,
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 14)
            ]
        )
        alert.setValue(attributedMessage, forKey: "attributedMessage")
        alert.addTextField { textField in
            textField.placeholder = "ライセンスキーをここにペースト"
            textField.text = AppCom.licenseKey
        }
        alert.addAction(UIAlertAction(title: "設定", style: .default, handler: { _ in
            if let key = alert.textFields?.first?.text, !key.isEmpty {
                AppCom.licenseKey = key
                self.checkLicense() { email in
                    if email != nil {
                        AppCom.licenseKey = key
                        Com.shortMessage("ライセンスキーを設定しました")
                        self.delegate?.licensed()
                    }
                    else {
                        AppCom.licenseKey = nil
                        Com.shortMessage("有効なライセンスキーではありません")
                    }
                }
            } else {
                Com.shortMessage("ライセンスキーが無効です")
            }
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // アプリニュースの最新投稿のチェック
    private func checkAppNewsExist() {
        let oldText = ud.string(forKey: AppCom.USER_DEFKEY_APP_NEWS_TIMESTUMP)
        appNewsExist = appDelegate.appNewsSiteDate != oldText
        holder.newsInfoLabel(appNewsExist: appNewsExist)
    }
    
    // 設定の初期値
    private func setSettings() {
        // アプリバージョンを表示
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let bun = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        holder.appVersionLabel.text = "\(ver!)-R\(bun!)"
        // UIの初期設定
        holder.startModeSwitch.isOn = AppCom.downloadFirst
        holder.keepScreenSwitch.isOn = AppCom.keepScreenOn
        holder.logModeSwitch.isOn = AppCom.logMode
        holder.appearanceSegment.selectedSegmentIndex = ud.integer(forKey: AppCom.USER_DEFKEY_APPEARANCE_MODE)
        // ログ共有ボタンの有効無効
        holder.logShareBtn.isEnabled = holder.logModeSwitch.isOn
    }
    
    // 終了時の処理
    override func goBack() {
        if restoredCount > 0 {
            delegate?.restored(count: restoredCount)
        }
        // 戻る
        super.goBack()
    }
    
    // キャッシュクリア
    private func cleatCache() {
        // 再生中
        let audioPlayer = AudioPlayerManager.shared
        if audioPlayer.isPlaying.value {
            Com.shortMessage("番組再生中はキャッシュ削除できません")
            return
        }
        else if audioPlayer.isActive.value {
            Com.XLOG("プレイヤーを強制完了！")
            audioPlayer.audioPlayerForceStop()
        }
        // ダイアログで確認
        SimplePopup.showAlert(
            on: self.view,
            title: "確認",
            message: "一時的に保存したデータを削除します。\n番組情報と視聴履歴、確認スキップの情報も合わせてクリアします。",
            confirmTitle: "削除",
            cancelTitle: "キャンセル",
            onConfirm: { _ in
                // キャッシュクリア
                self.presenter.cleatCache()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // データ再ロード
                    Com.shortMessage("キャッシュを削除しました")
                }
            })
    }
    
    // ログをshare
    private func shareLogs() {
        Com.shareCompressedLogs(from: self)
    }
}

// MARK: - バックアップ処理系

extension SettingsViewController {
    
    // カードのバックアップと復元ダアクションシート処理
    private func showCardBackupRestore() {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "カードデータを保存する…", style: .default, handler: {
            (action: UIAlertAction!) in
            self.presenter.saveAllCardDataToJson(callback: { () -> Void in
                Com.shortMessage(NSLocalizedString("カードデータを保存しました", comment:""))
            })
        }))
        alert.addAction(UIAlertAction(title: "バックアップから復元…", style: .default, handler: {
            (action: UIAlertAction!) in
            self.showRestorePopup()
            
        }))
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // バックアップファイル選択ポップアップ
    private func showRestorePopup() {
        SelectFilePopup.show(from: self) { fileName in
            Com.XLOG("選択したJSON: \(fileName)")
            let fileManager = FileManager.default
            if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsURL.appendingPathComponent(fileName)
                do {
                    let jsonString = try String(contentsOf: fileURL, encoding: .utf8)
                    self.presenter.restore(jsonStr: jsonString, callback: { count, err in
                        self.restoredCount = count
                        if count == 0 {
                            Com.shortMessage("復元できませんでした（Err=\(err)）")
                        }
                        else {
                            // メインにっ戻る
                            self.goBack()
                        }
                    })
                } catch {
                    Com.XLOG("JOSNファイル読み込みエラー: \(error)")
                }
            }
        }

    }
}

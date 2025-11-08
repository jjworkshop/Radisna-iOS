//
//  ViewController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import RxGesture
import CoreLocation
import StoreKit
import CoreData
import MessageUI

protocol TimetableViewControllerDelegate {
    func finished(isAdded: Bool)
}

protocol PlaylistViewControllerDelegate {
    func finished(isRemoved: Bool)
}

protocol MainCardMenuViewControllerDelegate {
    func deleteItem(uuid: String)
    func updateItem(uuid: String)

}

protocol SettingsViewControllerDelegate {
    func restored(count: Int)
    func licensed()
}

class MainViewController: AppCommonViewController {
    
    let presenter = MainPresenter()
    let downloader = RadikoDownloader.shared
    //let downloader = RadikoDownloaderDummy.shared   // UI/UXテスト用ダミー
    var mainView: MainView!
    lazy var imageDownloader = appDelegate.getImageDownloader()
    private let customTransitioningDelegate = CustomTransitioningDelegate()
    
    // 位置情報関連
    private let locationManager = CLLocationManager()
    
    // iPhoneX系のセーフエリア
    var safeAreaView: UIView? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad(
            title: nil, L1:nil, R1: nil, R2: AppCom.pdf_swap, R3: AppCom.pdf_gear)
        
        // タイトル表示
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        setCaption(appName)
        // 位置情報のDeleGate設定
        locationManager.delegate = self
        // 以上終了等でダウンロード中が残っているのをクリーンアップ
        presenter.cleanUpDownloading()
        // メインビューを取得
        mainView = self.view as? MainView
        mainView.viewController = self
        // オブザーバー登録
        setupObservers()
        setupDownloaderObservers()
        // ライセンス状態表示
        mainView.showLicenseUser(licenseKey: AppCom.licenseKey)
        // デバッグ用データ操作
        forDebugging() {
            self.presenter.getAllStationAndSave(callback: {count in
                Com.XLOG("全放送局データ取得: \(count)")
            })
            // コレクションデータを表示
            self.presenter.loadItems()
            // 初期のメッセージを表示
            self.showFirstConfirmDialog()
            // 起動時にダウンロード数をチェック
            self.downloader.checkDownloadCount()
            // 初期画面がダウンロード一覧（データがある場合のみ）
            if AppCom.downloadFirst {
                let context = self.appDelegate.getMoContext()
                if Download.numberOfData(context) > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // 遅延処理
                        // ダウンロード一覧画面表示
                        self.showPlaylist()
                    }
                }
            }
        }
    }
    
    // 前面になろうとしている
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ディリークーポン取得
        let coupon = CouponDB.shared
        var count = CouponDB.DAILY_COUPON
        if mainView.donationBtn.isHidden == true {
            count = CouponDB.MAX
        }
        coupon.addOncePerDay(count)
        // アプリニュースの最終投稿日チェック
        self.presenter.chackAppNewsDate()
    }
    
    // 初期のメッセージ表示
    func showFirstConfirmDialog() {
        let udKey = "showFirstConfirmDialog"
        let notNeedDisplay = UserDefaults.standard.bool(forKey: udKey)
        if !notNeedDisplay {
            SimplePopup.showAlert(
                on: self.view,
                title: "⚠️ 注意",
                message: "保存した音声の個人的な聴取の範囲を超えた利用は著作権法で禁止されています。\n保存したデータを配布・再アップロードすることは著作権法違反になります。",
                showCheckbox: true,
                checkboxLabel: "今後表示しない",
                confirmTitle: "確認した",
                onConfirm: { isChecked in
                    Com.XLOG("チェック状態: \(isChecked)")
                    UserDefaults.standard.set(isChecked, forKey: udKey)
                }
            )
        }
    }
    
    // レイアウトが確定した
    override func viewDidLayoutSubviews() {
        // セーフエリアにビューをはめておく（他の画面から利用する場合に備えて）
        if (safeAreaView == nil) {
            let safeHightBottom = Com.safeHightBottom
            safeAreaView = UIView(frame:CGRect(x: 0, y: mainView.frame.height - safeHightBottom, width: self.view.frame.width, height: safeHightBottom))
            safeAreaView?.backgroundColor = UIColor.systemBackground
            safeAreaView?.tag = AppCom.safearea_view_tag
            safeAreaView?.isHidden = true
            if (safeAreaView != nil) {
                self.navigationController?.view.addSubview(safeAreaView!)
            }
            // 画面サイズ確認
            Com.XLOG("ステータスバー    : \(Com.statusBarHeight )]")
            Com.XLOG("ナビゲーションバー : \(Com.navigationBarHeight(self) )]")
            Com.XLOG("セーフエリアTop   : \(Com.safeHightTop )]")
            Com.XLOG("セーフエリアBottom: \(safeHightBottom )]")
        }
        super.viewDidLayoutSubviews()
        
    }
    
    // 最初に各サブビューのレイアウトが確認した直後の処理
    override func firstlayoutSubviews() {
        super.firstlayoutSubviews()
        // なにかあれば
    }
    
    // オブザーバーの登録
    private func setupObservers() {
        
        // アプリの稼働状態チェック
        sceneDelegate.wakeupMain.asObservable()
        
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG(on ? "Main-ウェイクアップ" : "Main-スリープ")
                if on  {
                    Com.XLOG("位置情報のユーザー認証")
                    self.locationManager.requestAlwaysAuthorization()
                    self.startUpdatingLocation("for WAKE UP")
                    // ダウンロード予約の期限が切れているデータの予約を取り消す（ダウンロード中以外）
                    if downloader.satus.value != .downloading {
                        if self.presenter.cancelExpiredDownload() {
                            // 予約キャンセルしたので、リストを更新
                            self.mainView.updateNumberOfDownloadCoupon()
                            self.presenter.cleanUpDownloading()
                            self.mainView.tableView.reloadData()
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
        
        // 位置情報の結果通知受取
        presenter.resultGeoLocation.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] location in
                presenter.getStationData(location: location, callback: {pName in
                    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    self.setCaption("\(appName ?? "") - \(pName ?? "不明")")
                })
            })
            .disposed(by: disposeBag)
        
        // アプリ最新ニュース監視
        presenter.appNewsExist.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] on in
                self.rightButtonItem3!.tintColor = on ? UIColor.systemOrange : UIColor.label
            })
            .disposed(by: disposeBag)
        
        // スペシャルユーザー監視
        presenter.specialUser.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [/* unowned self */] on in
                // スペシャルユーザー
                UserDefaults.standard.set(on, forKey: AppCom.USER_DEFKEY_SPECIAL_USER)
            })
            .disposed(by: disposeBag)
        
        // ナビゲーションバーの並び替えボタン
        rightButtonItem2?.rx.tap
            .subscribe(onNext: { [unowned self] in
                // 編集モードスイッチ
                self.presenter.editing.accept(!self.presenter.editing.value)
            })
            .disposed(by: disposeBag)
        
        // ナビゲーションバーの設定ボタン
        rightButtonItem3?.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.cancelSortMode()
                // 設定画面表示
                self.showSettings()
                
            })
            .disposed(by: disposeBag)
        
        // donationボタン
        mainView.donationBtn.rx.tapGesture()
            .when(.recognized)  // 起動時に処理されるのを防止
            .subscribe(onNext: { [unowned self] _ in
                self.showDonation()
            })
            .disposed(by: disposeBag)
        
        // リフレッシュコントローラー
        mainView.refreshControl.rx.controlEvent(.valueChanged).asObservable()
            .map({ () -> Bool in self.mainView.refreshControl.isRefreshing })
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG("refreshControl: [\(on)]")
                self.presenter.loadItems()
                self.cancelSortMode()
                self.mainView.refreshControl.endRefreshing()
            })
            .disposed(by: disposeBag)
        
        // カード追加ボタン
        mainView.plusBtn.button.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.cancelSortMode()
                // 番組一覧画面表示
                self.showTimetable()
            })
            .disposed(by: disposeBag)
        
        // ダウンロード一覧表示ボタン
        mainView.playListBtn.button.rx.tap
            .subscribe(onNext: { [unowned self] _ in
                self.cancelSortMode()
                // ダウンロード一覧画面表示
                self.showPlaylist()
            })
            .disposed(by: disposeBag)
        
        // ダウンロード／キャンセルボタン
        mainView.recBtn.button.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.cancelSortMode()
                if self.downloader.satus.value == DataLoaderStatus.downloading {
                    // ダウンロード中はキャンセル
                    self.cancelDownload()
                }
                else {
                    // ダウンロード開始
                    self.showStartDownloadDialog {
                        self.startDownload()
                    }
                }
            })
            .disposed(by: disposeBag)
        
        
        // カード更新のリクエスト
        Observable.combineLatest(
            presenter.requestReload.asObservable(),
            downloader.satus.asObservable()
        )
        .observeOn(MainScheduler.asyncInstance)
        .subscribe(onNext: { [unowned self] (on, status) in
            if on && status != .downloading {
                self.presenter.loadItems()
                self.cancelSortMode()
                presenter.requestReload.onNext(false)   // フラグを落としておく
            }
        })
        .disposed(by: disposeBag)
        
        // 編集モードの監視
        presenter.editing.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] on in
                self.mainView.tableView.setEditing(on, animated: true)
                self.rightButtonItem2!.tintColor = on ? UIColor.systemOrange : UIColor.label
            })
            .disposed(by: disposeBag)
        
        // コンテンツの数を監視
        presenter.contentCount.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] count in
                self.mainView.firstInfoLabel.isHidden = count > 2
                self.mainView.bImage.isHidden = count != 0
                if (count == 0 && self.presenter.editing.value) {
                    // 編集をやめる
                    self.presenter.editing.accept(false)
                }
                // 最大件数に達すると「＋」ボタンは消す
                self.mainView.plusBtn.isHidden = count >= self.presenter.maximumNumberOfCards
            })
            .disposed(by: disposeBag)
        
        // テーブルビューアイテムのバインド設定（subscribe）
        presenter.dataSource = RxTableViewSectionedReloadDataSource<SectionOfBookingData>(
            configureCell: { [unowned self] (dataSource, tableView, indexPath, item) in
                let cell = tableView.dequeueReusableCell(withIdentifier: "MainCard", for: indexPath)
                return self.setupCell(cell, listItem: item, row: indexPath.row)
            }, titleForHeaderInSection: { [] (dataSource, indexPath) in
                return dataSource.sectionModels[indexPath].header
            }, canEditRowAtIndexPath: { (_, _) in
                return true
            }, canMoveRowAtIndexPath: { (_, _) in
                return true
            })
        presenter.list
            .bind(to: mainView.tableView.rx.items(dataSource: presenter.dataSource!))
            .disposed(by: disposeBag)
        
        // テーブルビューアイテム削除
        mainView.tableView.rx.itemDeleted
            .subscribe(onNext: { [unowned self] indexPath in
                Com.XLOG("削除データ IDX: \(indexPath.row)")
                if (!self.presenter.removeData(index: indexPath.row)) {
                    Com.shortMessage(NSLocalizedString("データを削除できませんでした", comment:""))
                }
            })
            .disposed(by: disposeBag)
        
        // テーブルビューアイテム移動
        mainView.tableView.rx.itemMoved
            .subscribe(onNext: { [unowned self] sourceIndexPath, destinationIndexPath  in
                if (sourceIndexPath.row != destinationIndexPath.row) {
                    Com.XLOG("移動データ source: \(sourceIndexPath.row) destination: \(destinationIndexPath.row)")
                    if (self.presenter.moveData(srcIndex: sourceIndexPath.row, desIndex: destinationIndexPath.row)) {
                        // セルのダウンロードボタンと index をマッチさせるためリロード
                        presenter.loadItems()
                    }
                    else {
                        Com.shortMessage(NSLocalizedString("データを移動できませんでした", comment:""))
                    }
                }
            })
            .disposed(by: disposeBag)
    }
    
    // ダウンロードオブザーバーの登録
    func setupDownloaderObservers() {
        
        // ダウンロード予約数を監視
        downloader.reservedCount.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] count in
                self.downloader.satus.accept(count == 0 ? DataLoaderStatus.idle : DataLoaderStatus.selecting)
                self.mainView.updateNumberOfDownloadCoupon()
            })
            .disposed(by: disposeBag)
        
        // 処理モードを監視
        downloader.satus.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] status in
                // 処理モードによりUIを設定
                self.mainView.setControlAttributesByMode(status)
            })
            .disposed(by: disposeBag)
        
        // ダウンローダーからの進捗通知と完了通知を受ける
        downloader.notification.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] notification in
                let index = self.presenter.findIndexByCardID(uuid: notification.uuid)
                if (index >= 0) {
                    if let completion = notification.completion {
                        // DL開始通知 or DL完了通知：　データ更新
                        self.updateByNotification(uuid: notification.uuid, status: completion)
                        // 対象のセルを更新
                        self.mainView.updateCell(index)
                    }
                    else {
                        // 進捗通知：　プログレスバーを直接更新
                        Com.XLOG("DL[\(notification.uuid)]: \(notification.progress) ％")
                        var spd = self.presenter.dataSource!.sectionModels[0] as SectionOfBookingData
                        if (spd.items.indices.contains(index)) {
                            spd.items[index].progress = notification.progress
                            if let cell = self.mainView.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MainTableViewCell {
                                cell.loadingProgress.setProgress(Float(notification.progress) / 100.0, animated: false)
                            }
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
        
        
    }
    
    // カードのダウンロードボタンタップ
    func cellDownloadButtonTaped(index: Int, item: Booking?) {
        if downloader.satus.value == DataLoaderStatus.downloading {
            // ダウンロード中は無効
            return
        }
        let spd = presenter.dataSource!.sectionModels[0] as SectionOfBookingData
        if (spd.items.indices.contains(index)) {
            let uuid = spd.items[index].id
            Com.XLOG("ダウンロードボタンタップ[\(index)]: \(uuid)")
            let context = self.appDelegate.getMoContext()
            if let item = Booking.getItem(context, uuid: uuid) {
                var newStatus = 0
                switch item.status {
                case 0, 1, 2, 9:   // 0=未指定、1=ダウンロード済み（削除されている場合があるので）、2=ダウンロードキャンセル、9=ダウンロードエラーの場合は予約可能
                    // クーポンをチェック
                    let context = self.appDelegate.getMoContext()
                    let reservedCount = Booking.numberOfReservedData(context)
                    let coupon = CouponDB.shared
                    if coupon.getCount() < reservedCount + 1 {
                        // クーポンが足りない
                        showNotEnoughCouponDialog()
                        return
                    }
                    // ダウンロード予約
                    newStatus = 7
                    // プログレスを０に初期化
                    var spd = self.presenter.dataSource!.sectionModels[0] as SectionOfBookingData
                    if (spd.items.indices.contains(index)) {
                        spd.items[index].progress = 0
                    }
                default:
                    break
                }
                _ = Booking.updateStatus(context, uuid: uuid, status: newStatus)
                self.appDelegate.saveContext()
                // セルを更新
                mainView.updateCell(index)
                // ダウンロード予約数をチェック
                downloader.checkDownloadCount()
                
            }
        }
    }
    
    // ダウンロード予約時のクーポン不足メッセージ表示
    private func showNotEnoughCouponDialog() {
        SimplePopup.showAlert(
            on: self.view,
            title: "通知",
            message: "ダウンロードクーポンが足りません。\n翌日にクーポンが加算されますが、ドネーションによりライセンスを取得して毎日最大数までクーポンを増やすこともできます。",
            showCheckbox: true,
            confirmTitle: "閉じる",
        )
    }
    
    // ドネーション依頼ダイアログ
    private func showDonation() {
        SimplePopup.showAlert(
            on: self.view,
            title: "ドネーション",
            message: "いつも「らじすな」をご利用いただきありがとうございます。\nこのアプリを、より良いものにしていくために、皆様からのご寄付をいただけると大変助かります。いただいたご寄付は、今後の開発やバージョンアップに大切に活用させていただきます。\nご検討いただけますと幸いです。",
            confirmTitle: "寄付をする…",
            cancelTitle: "後で",
            onConfirm: { isChecked in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 遅延処理
                    self.donation()
                }
            }
        )
    }
    
    // ドネーションメール作成ダイアログ
    private func donation() {
        SimplePopup.showAlert(
            on: self.view,
            title: "ドネーション依頼メール",
            message: "[SAMPLE]\n寄付のご協力をお願いするメールを作成いたします。\n寄付額は***円で****による送金となります。\n送金確認後にライセンスキーをメールにて送付致しますので返信可能なメールアドレスで送信して下さい。",
            confirmTitle: "メール作成…",
            cancelTitle: "キャンセル",
            onConfirm: { isChecked in
                self.sendEmailViaMailer()
            }
        )
    }
    
    // ダウンロード開始の確認ダイアログ
    private func showStartDownloadDialog(onConfirm: @escaping () -> Void) {
        let udKey = "showStartDownloadDialog"
        let notNeedDisplay = UserDefaults.standard.bool(forKey: udKey)
        if !notNeedDisplay {
            var message = "ダウンロード中は、アプリを閉じたり他のアプリに切り替えたりしないで下さい。"
            if AppCom.keepScreenOn {
                message += "\nバッテリー節約のため、画面を暗くしますがダウンロード完了で元に戻ります。"
            }
            message += "\n（詳細は「使い方の説明」を参照）"
            SimplePopup.showAlert(
                on: self.view,
                title: "⚠️ 注意",
                message: message,
                showCheckbox: true,
                checkboxLabel: "今後表示しない",
                confirmTitle: "ダウンロード開始",
                cancelTitle: "キャンセル",
                onConfirm: { isChecked in
                    UserDefaults.standard.set(isChecked, forKey: udKey)
                    onConfirm()
                }
            )
        }
        else {
            // 確認無し
            onConfirm()
        }
    }
    
    // ダウンロード開始
    private func startDownload() {
        // license済みは同時ダウンロードを６にする
        if mainView.donationBtn.isHidden == true {
            downloader.maxDownloadCount = 6
        }
        downloader.satus.accept(DataLoaderStatus.downloading)
        presenter.loadItems()   // 全てのカードボタンを無効にするため
        downloader.startDownloads(
            keepScreenOn: AppCom.keepScreenOn,
            progressHandler: { current, total in    // 番組単位の処理通知
                if current == -1 && total == -1 {
                    // ログインエラー
                    self.showLoginErrorDialog()
                }
                else {
                    Com.XLOG("ダウンロード中: \(current)/\(total) downloading")
                }
            },
            completion: { results in                // ダウンロード完了通知
                Com.XLOG("✏️ ダウンロード結果レポート")
                for (i, cmd) in results.enumerated() {
                    Com.XLOG("DL-NO[\(i)][\(cmd.title)]: result = \(cmd.result)")
                }
                // 処理完了でアイドル（もしくは選択中）に戻し、ヘッダのダウンロード数を更新
                self.downloader.checkDownloadCount()
                // ダウンロード中で終わっているデータをクリーンアップしてリロード
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // 遅延処理: idleに戻るのに少し待つ
                    self.presenter.cleanUpDownloading()
                    self.mainView.tableView.reloadData()
                }
            }
        )
    }
    
    // ダウンローダーからの通知によDBとクーポンの更新
    private func updateByNotification(uuid: String, status: Int) {
        let context = self.appDelegate.getMoContext()
        var isUpdate = true
        switch status {
        case 0: // ダウンロード成功
            if Booking.updateStatus(context, uuid: uuid, status: 1) {
                // Downloadに追加
                if let booking = Booking.getItem(context, uuid: uuid) {
                    Download.storeDataByBooking(context, booking: booking)
                }
                // クーポンを消費
                let coupon = CouponDB.shared
                coupon.add(-1)
            }
        case 1: // ダウンロード失敗
            _ = Booking.updateStatus(context, uuid: uuid, status: 9)
        case 8: // ダウンロード中
            _ = Booking.updateStatus(context, uuid: uuid, status: 8)
        case 9: // ダウンロードキャンセル
            _ = Booking.updateStatus(context, uuid: uuid, status: 2)
            Com.shortMessage("ダウンロードキャンセルしました")
        default:
            isUpdate = false
            break
        }
        if isUpdate {
            self.appDelegate.saveContext()
        }
    }
    
    // ダウンロードキャンセル
    private func cancelDownload() {
        downloader.cancelDownload()
    }
    
    // ログインエラーダイアログ表示
    private func showLoginErrorDialog() {
        SimplePopup.showAlert(
            on: self.view,
            title: "通知",
            message: "ダウンロードを開始できません。\nしばらく待って再処理してみて下さい。",
            confirmTitle: "再処理",
            cancelTitle: "キャンセル",
            onConfirm: { _ in
                // ダウンロード開始（再処理）
                self.startDownload()
            })
    }
    
    // カードの詳細ボタンタップ
    func cellDetailButtonTaped(index: Int, item: Booking) {
        if downloader.satus.value == DataLoaderStatus.downloading {
            // ダウンロード中は無効
            return
        }
        let spd = presenter.dataSource!.sectionModels[0] as SectionOfBookingData
        if (spd.items.indices.contains(index)) {
            let uuid = spd.items[index].id
            Com.XLOG("カードの詳細ボタンタップ[\(index)]: \(uuid)")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let modalVC = storyboard.instantiateViewController(withIdentifier: "MainCardMenu") as? MainCardMenuViewController else {
                Com.XLOG("MainCardMenu のインスタンス化に失敗")
                return
            }
            modalVC.delegate = self
            modalVC.item = BookingItem.from(booking: item)
            modalVC.modalPresentationStyle = .custom
            modalVC.transitioningDelegate = customTransitioningDelegate
            present(modalVC, animated: true, completion: nil)
        }
    }
    
    // ソートモードをキャンセル
    private func cancelSortMode() {
        if presenter.editing.value {
            presenter.editing.accept(false)
        }
    }

    // 位置情報取得開始！
    private func startUpdatingLocation(_ comment: String) {
        if  CLLocationManager.locationServicesEnabled() &&
            (locationManager.authorizationStatus == .authorizedAlways ||
             locationManager.authorizationStatus == .authorizedWhenInUse)
        {
            Com.XLOG("位置情報取得開始！ \(comment)")
            locationManager.startUpdatingLocation()
        }
    }
    
    // オンライン通知
    override func hasBeenOnline() {
        super.hasBeenOnline()
        Com.XLOG("オンラインになった！")
    }
    
    // 設定画面表示
    private func showSettings() {
        Com.XLOG("設定画面表示")
        self.performSegue(withIdentifier: "settingsSegue", sender: nil)
    }
    
    // 番組一覧画面表示
    private func showTimetable() {
        Com.XLOG("番組一覧画面表示")
        self.performSegue(withIdentifier: "timetableSegue", sender: nil)
    }
    
    // ダウンロード一覧画面表示
    private func showPlaylist() {
        Com.XLOG("ダウンロード一覧画面表示")
        self.performSegue(withIdentifier: "playlistSegue", sender: nil)
    }
        
    // セグエ指定で次の画面が開く前に呼ばれる
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // セグエの識別子を確認
        switch segue.identifier {
        case "timetableSegue":
            // 番組一覧画面
            (segue.destination as? TimetableViewController)?.delegate = self
        case "playlistSegue":
            // ダウンロード一覧画面
            (segue.destination as? PlaylistViewController)?.delegate = self
        case "settingsSegue":
            // 設定画面
            (segue.destination as? SettingsViewController)?.delegate = self
        default:
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension MainViewController: CLLocationManagerDelegate {
    // 位置情報の許可のステータス変更で呼ばれる
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Com.XLOG("didChangeAuthorization status=\(status.description)")
        switch status {
        case .authorizedAlways:
            manager.requestLocation()
            break
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            break
        case .notDetermined:
            break
        case .restricted:
            break
        case .denied:
            break
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location2D = locations[locations.count-1].coordinate
        Com.XLOG("位置情報: LAT=\(location2D.latitude)  LON=\(location2D.longitude)")
        presenter.resultGeoLocation.onNext(LatLon(lat: location2D.latitude, lon: location2D.longitude))
        self.locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Com.XLOG("位置情報Error error: \(error.localizedDescription)")
        self.locationManager.stopUpdatingLocation()
    }
}

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "未選択"
        case .restricted:
            return "ペアレンタルコントロールなどの影響で制限中"
        case .denied:
            return "利用拒否"
        case .authorizedAlways:
            return "常に利用許可"
        case .authorizedWhenInUse:
            return "使用中のみ利用許可"
        default:
            return ""
        }
    }
}

// MARK: - MainViewControllerDelegate

extension MainViewController: TimetableViewControllerDelegate {
    // 番組の登録完了通知
    func finished(isAdded: Bool) {
        Com.XLOG("番組番組の登録完了通知中: \(isAdded) status=\(downloader.satus.value)")
        if isAdded {
            // ダウロード中メッセージ
            if downloader.satus.value == .downloading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // 遅延処理（モーダルが消えるまで）
                    Com.shortMessage("ダウンロード終了後にカード情報を更新します")
                }
            }
            // カード更新をリクエスト
            presenter.requestReload.onNext(true)
        }
    }
}

// MARK: - PlaylistViewControllerDelegate

extension MainViewController: PlaylistViewControllerDelegate {
    // 番組の登録完了通知
    func finished(isRemoved: Bool) {
        Com.XLOG("ダウンロード一覧削除通知: \(isRemoved) status=\(downloader.satus.value)")
        if isRemoved {
            // ダウロード中メッセージ
            if downloader.satus.value == .downloading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // 遅延処理（モーダルが消えるまで）
                    Com.shortMessage("ダウンロード終了後にカード情報を更新します")
                }
            }
            // カード更新をリクエスト
            presenter.requestReload.onNext(true)
        }
    }
}

// MARK: - MainCardMenuViewControllerDelegate

extension MainViewController: MainCardMenuViewControllerDelegate {
    
    // MainCardMenuViewController は「i」ボタンからのモーダルで、
    // 「i」ボタンはダウンロード中は無効になっているため、以下の処理はできなくなっている
    
    // カードの削除通知
    func deleteItem(uuid: String) {
        let index = presenter.findIndexByCardID(uuid: uuid)
        Com.XLOG("カードの削除通知: uuid=\(uuid) index=\(index)")
        if index != -1 {
            if (!self.presenter.removeData(index: index)) {
                Com.shortMessage(NSLocalizedString("データを削除できませんでした", comment:""))
            }
        }
    }
    // カードの更新通知
    func updateItem(uuid: String) {
        let index = presenter.findIndexByCardID(uuid: uuid)
        Com.XLOG("カードの更新通知: uuid=\(uuid) index=\(index)")
        if index != -1 {
            let indexPath = IndexPath(row: index, section: 0)
            mainView.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: SettingsViewControllerDelegate

extension MainViewController: SettingsViewControllerDelegate {
    
    // 番組カードrestore
    func restored(count: Int) {
        Com.XLOG("カードデータ復元: \(count)")
        // カード更新をリクエスト
        presenter.requestReload.onNext(true)
    }
    
    // ライセンス状態変更
    func licensed() {
        mainView.showLicenseUser(licenseKey: AppCom.licenseKey)
    }
}

// MARK: - メール連携

extension MainViewController: MFMailComposeViewControllerDelegate {
    // メーラーを起動してドネーションメールを作成
    fileprivate func sendEmailViaMailer() {
        guard MFMailComposeViewController.canSendMail() else {
            // メール送信不可（メールアカウント未設定など）
            Com.shortMessage("メールアカウントが設定されていません")
            showContact()
            return
        }
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        // TODO: メールアドレス設定（「your_email」はSAMPLE）
        mail.setToRecipients(["info@your_email.com"])
        mail.setSubject("らじすなドネーション")
        mail.setMessageBody("「らじすな」のドネーションの申し込みをします。", isHTML: false)
        present(mail, animated: true)
    }

    // メール送信画面のクローズ処理
    public func mailComposeController(_ controller: MFMailComposeViewController,
                                      didFinishWith result: MFMailComposeResult,
                                      error: Error?) {
        controller.dismiss(animated: true)
    }
    
    // メール送信できないときの処理
    private func showContact() {
        SimplePopup.showAlert(
            on: self.view,
            title: "通知",
            message: "メールの作成ができませんでした。\nドネーションの依頼は以下の連絡先までお願いします。",
            confirmTitle: "連絡先を表示",
            // TODO: URL設定（<your site>はSAMPLE）してコメント外す
            // onConfirm: { isChecked in
            //    AppCom.showSite(url: "https://<your site>/contact.html")
            //}
        )
    }
}
// MARK: - テスト用データの挿入

extension MainViewController {
    // サンプルデータ挿入
    private func forDebugging(callback: @escaping () -> Void) {
        let context = appDelegate.getMoContext()
        let dataCount = Booking.numberOfData(context)
        Com.XLOG("カードデータ数: \(dataCount)")
        
        // デバッグ用クーポン最大
        /*
        let coupon = CouponDB.shared
        let count = CouponDB.MAX - coupon.getCount() - 1
        coupon.add(count)
        */
        
        // デバッグ用データクリア
        /*
        if dataCount != 0 {
            Booking.removeAll(context)
            Download.removeAll(context)
            dataCount = 0
        }
        */
        
        callback()
    }
}

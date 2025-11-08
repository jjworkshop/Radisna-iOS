//
//  TimetableViewController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/23.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import RxGesture
import CoreData
import CoreLocation

class TimetableViewController: ModalViewController {
    
    var delegate: TimetableViewControllerDelegate? = nil

    let presenter = TimetablePresenter()
    private var mainView: TimetableView!
    lazy var imageDownloader = appDelegate.getImageDownloader()
    
    let locationManager = CLLocationManager()

    // 追加したかどうか
    private var isAdded = false
    // 終了時に確認不要
    private var isNotNeedCheckExit: Bool = false
    
    private lazy var weekStrTbl: [String] = [
        "全ての",
        "日","月","火","水","木","金","土"
    ]
    private let weekSuffix = "曜日"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mainView = self.view as? TimetableView
        mainView.viewController = self
        mainView.searchwordField.delegate = self
        
        // オブザーバー登録
        setupObservers()
        // 位置情報の許可を確認
        checkLocationInformationAvailable() {
            // 初期セットアップ
            self.setup()
            // コレクションデータを表示
            self.reloadCardData()
        }
    }
    
    // 初期セットアップ
    private func setup() {
        // 初期検索条件の画面設定
        mainView.searchwordField.text = presenter.currentSearchStr
        var dateLabel = weekStrTbl[0] + weekSuffix
        if let weekStr = presenter.currentWeekStr {
            dateLabel = weekStr + weekSuffix
        }
        mainView.weekLabel.text = dateLabel
        mainView.moveBottomFrameViewDown()
    }
    
    // 終了時の処理
    override func goBack() {
        if isNotNeedCheckExit {
            super.goBack()
        }
        if presenter.numberOfBookingItem > 0 {
            SimplePopup.showAlert(
                on: self.view,
                title: "確認",
                message: "選択済の番組がありますがキャンセルしますか？",
                confirmTitle: "はい",
                cancelTitle: "いいえ",
                onConfirm: { _ in
                    super.goBack()
                }
            )
        }
        else {
            super.goBack() 
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

        // フィルターボタン
        mainView.rightButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                presenter.currentSearchStr = nil
                presenter.currentWeekStr = nil
                reloadCardData()
                mainView.searchwordField.text = ""
                mainView.searchwordField.resignFirstResponder()
                presenter.searchText.onNext("")
                mainView.weekLabel.text = weekStrTbl[0] + weekSuffix
            })
            .disposed(by: disposeBag)
        
        // カレンダーボタン
        mainView.calendarButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.showDayOfWeekSelectionDialog()
            })
            .disposed(by: disposeBag)
        
        // 追加ボタン
        mainView.addButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.addSelectedProgram()
            })
            .disposed(by: disposeBag)
        
        // 追加キャンセルボタン
        mainView.addCancelButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.clearSelectedProgram()
            })
            .disposed(by: disposeBag)
        
        // 番組表ローディング中
        presenter.isLoading.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG("番組取得中: \(on)")
                if on {
                    mainView.showIndicator()
                    mainView.loadingLabel.showLoading()
                } else {
                    mainView.forceIndicatorToHide()
                    mainView.loadingLabel.isHidden = true
                }
                mainView.searchwordField.isEnabled = !on
                mainView.calendarButton.isEnabled = !on
                mainView.rightButton.isEnabled = !on
             })
            .disposed(by: disposeBag)
        
        // 検索フィルターチェック
        presenter.searchFilterCheck.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG("フィルターチェック: T=\(presenter.currentSearchStr ?? "") W=\(presenter.currentWeekStr ?? "")")
                let isOff = presenter.currentSearchStr.isNilOrEmpty && presenter.currentWeekStr.isNilOrEmpty
                mainView.rightButton.isHidden = isOff
             })
            .disposed(by: disposeBag)
        
        // 放送局の変更
        presenter.changedStationId.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] _ in
                reloadCardData()
             })
            .disposed(by: disposeBag)
        
        // 検索文字通知
        presenter.searchText.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] text in
                Com.XLOG("検索文字: \(text)")
                presenter.currentSearchStr = text
                reloadCardData()
             })
            .disposed(by: disposeBag)
        
        // カレンダー変更通知
        presenter.weekText.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] weekStr in
                Com.XLOG("曜日文字: \(weekStr.isEmpty ? "全ての曜日" : weekStr)")
                presenter.currentWeekStr = weekStr.isEmpty ? nil : weekStr
                reloadCardData()
             })
            .disposed(by: disposeBag)
        
        // サーチテキストエディット
        mainView.searchwordField.rx.searchButtonClicked
            .subscribe(onNext: { [unowned self] () in
                if let text = self.mainView.searchwordField.text {
                    presenter.searchText.onNext(text)
                }
            })
            .disposed(by: self.disposeBag)
        
        // リフレッシュコントローラー
        mainView.refreshControl.rx.controlEvent(.valueChanged).asObservable()
            .map({ () -> Bool in self.mainView.refreshControl.isRefreshing })
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG("refreshControl: [\(on)]")
                self.reloadCardData(forced: true)
                self.mainView.refreshControl.endRefreshing()
            })
            .disposed(by: disposeBag)
        
        // コンテンツの数を監視
        presenter.contentCount.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] count in
                Com.XLOG("コンテンツの数: \(count)")
                self.mainView.bImage.isHidden = count != 0
             })
            .disposed(by: disposeBag)
        
        // 追加コンテンツの数を監視
        presenter.addBookingCount.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] count in
                // 追加パネルの表示／非表示
                mainView.addCountLabel.text = "\(count)"
                if count == 0 {
                    mainView.moveBottomFrameViewDown()
                } else {
                    mainView.moveBottomFrameViewUp()
                }
             })
            .disposed(by: disposeBag)
        
        // テーブルビューアイテムのバインド設定（subscribe）
        presenter.dataSource = RxTableViewSectionedReloadDataSource<SectionOfTimetableData>(
            configureCell: { [unowned self] (dataSource, tableView, indexPath, item) in
                let cell = tableView.dequeueReusableCell(withIdentifier: "TimetableCard", for: indexPath)
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
        
    }
    
    // 位置情報の状態チェック
    private func checkLocationInformationAvailable(callback: @escaping () -> Void) {
        // 位置情報の状態を確認
        var isAvailable = false
        if CLLocationManager.locationServicesEnabled() {
            switch locationManager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                isAvailable = true
            default:
                break
            }
        }
        if isAvailable {
            callback()
        }
        else {
            SimplePopup.showAlert(
                on: self.view,
                title: "通知",
                message: "このアプリを使用するには、位置情報の許可が必要です。設定から許可をしてください。",
                confirmTitle: "設定を開く",
                cancelTitle: "キャンセル",
                onConfirm: { isChecked in
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        if UIApplication.shared.canOpenURL(appSettings) {
                            UIApplication.shared.open(appSettings)
                            self.goBack()
                        }
                    }
                },
                onCancel: {
                    self.goBack()
                }
            )
        }
    }
    
    // リロードカードデータ
    private func reloadCardData(forced: Bool = false) {
        Com.XLOG("カードリストリロード: \(presenter.currentStationId ?? "")")
        presenter.searchFilterCheck.onNext(true)
        presenter.loadItems(
            stationId: presenter.currentStationId,
            weekStr: presenter.currentWeekStr,
            searchStr: presenter.currentSearchStr, forced: forced) { result in
                Com.XLOG("リロード結果: \(result)")
            }
    }
    
    // カレンダーボタンをタップ
    private func showDayOfWeekSelectionDialog() {
        let currentIndex = convertWeekStrToWeekNum(presenter.currentWeekStr)
        WeekdayPopup.show(from: self, selectedIndex: currentIndex) { index, day in
            Com.XLOG("選択された曜日: \(day)（インデックス: \(index)）")
            let weekStr: String
            if index == 0 {
                weekStr = ""
                self.mainView.weekLabel.text = self.weekStrTbl[0] + self.weekSuffix
            } else {
                weekStr = day.replacingOccurrences(of: "曜日", with: "")
                self.mainView.weekLabel.text = day
            }
            self.presenter.weekText.onNext(weekStr)
        }
    }
    
    // 追加ボタンをタップ
    private func addSelectedProgram() {
        let count = presenter.numberOfBookingItem
        if count == 0 { return } // 番兵
        Com.XLOG("番組をカードに追加: \(count)")
        // Booking テーブルに追加
        let context = appDelegate.getMoContext()
        for item in presenter.bookingItemList {
            if Booking.exist(context, stationId: item.stationId, startDt: item.startDt) {
                // 本来は無いと思うけど念の為
                Com.XLOG("番組をカード既に存在: \(item.title)")
            } else {
                _ = Booking.storeData(context, item: item)
                isAdded = true
            }
        }
        appDelegate.saveContext()
        presenter.removeAllBookingItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 終了
            self.delegate?.finished(isAdded: self.isAdded)
            self.isNotNeedCheckExit = true
            self.goBack()
        }
    }
    
    // 追加キャンセルボタンをタップ
    private func clearSelectedProgram() {
        presenter.removeAllBookingItem()
        mainView.tableView.reloadData()
    }
    
    // セルの追加ボタンをタップ
    func cellAddButtonTaped(index: Int, item: ProgramItem) {
        Com.XLOG("番組追加[\(presenter.currentStationId ?? "")]:title=\(item.title)")
        if let stationId = presenter.currentStationId {
            // 追加か削除かモードを判定
            let alreadyAdded = presenter.existBookingItem(stationId: stationId, startDt: item.startDt)
            if alreadyAdded {
                // すでにあるので削除
                presenter.removeBookingItem(stationId: stationId, startDt: item.startDt)
            } else {
                // 追加のチェック
                let context = appDelegate.getMoContext()
                if Booking.exist(context, stationId: stationId, startDt: item.startDt) {
                    // すでに存在するの
                    Com.shortMessage("既に登録している番組です")
                    return
                } else {
                    presenter.addBookingItem(BookingItem(
                        uuid: "",  // DB追加時に決定
                        seqNo: -1, // DB追加時に決定
                        stationId: stationId,
                        startDt: item.startDt,
                        endDt: item.endDt,
                        title: item.title,
                        bcDate: item.bcDate,
                        bcTime: item.bcTime,
                        url: item.url ?? "",
                        pfm: item.pfm ?? "",
                        imgUrl: item.imgUrl ?? "",
                        status: 0
                    ))
                }
            }
            // リストを更新
            mainView.updateCell(index)
        }
    }
    
    // セルのイメージをタップ（番組のURLをWEBビューで表示）
    func cellBannerImageTaped(index: Int, item: ProgramItem) {
        Com.XLOG("番組情報表示 title=\(item.title)")
        if !item.url.isNilOrEmpty {
            self.performSegue(withIdentifier: "programSegue", sender: item)
        }
        else {
            Com.shortMessage("番組情報はありません")
        }
    }
    
    // セグエ指定で次の画面が開く前に呼ばれる
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // セグエの識別子を確認
        switch segue.identifier {
        case "programSegue":
            if let item = sender as? ProgramItem {
                (segue.destination as? ProgramViewController)?.urlStr = item.url
            }
        default:
            break
        }
    }
    
    // weekStr から weekNum への変換
    private func convertWeekStrToWeekNum(_ input: String?) -> Int {
        let num = weekStrTbl.firstIndex(of: input ?? "") ?? -1
        Com.XLOG("変換 str=\(input ?? "nil") -> num:\(num)")
        return max(0, num)
    }
    
}

// MARK: - UISearchBarDelegate

extension TimetableViewController: UISearchBarDelegate {
    // SearchBarでの入力を開始
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.setShowsCancelButton(true, animated: true)
        return true
    }
    // SearchBarでの入力を終了
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.setShowsCancelButton(false, animated: true)
        return true
    }
    // 検索ボタンをタップ
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.closeSoftKyeboard()
    }
    // キャンセルボタンをタップ
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.closeSoftKyeboard()
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            // Xボタンが押されたと推測できる
            Com.XLOG("Xボタンが押された（テキストが空になった）")
            presenter.searchText.onNext("")
        }
    }

}

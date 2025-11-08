//
//  MainCardMenuViewController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/02.
//

import UIKit
import RxSwift
import RxCocoa

class MainCardMenuViewController: ModalViewController {
    
    var mainView: MainCardMenuView!
    var delegate: MainCardMenuViewControllerDelegate? = nil
    var item: BookingItem? = nil
    
    // 番組情報のヘルパー
    private let isLoaded: PublishSubject<Bool> = PublishSubject()
    private var ttHelper: TimeTableHelper? = nil
    private let changedIndex: PublishSubject<Int> = PublishSubject()
    
    // 取得した番組で、同じ開始時間でタイトルが８０％マッチしたデータのリスト
    private var matchList: [[String: Any]]? = nil
    // 現在表示中の matchList のインデックス
    private var currentIdx: Int = -1
    private var originalIdx: Int = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mainView = self.view as? MainCardMenuView
        if let item = self.item {
            ttHelper = TimeTableHelper(stationId: item.stationId)
        }
        
        // オブザーバー登録
        setupObservers()
        // 初期設定
        if let item = self.item {
            mainView.setDetailsInfo(bookingItem: item)
        }
        // 番組ヘルパーにデータ読み込み（StationIDはコンストラクタで設定済）
        isLoaded.onNext(false)
        ttHelper?.getTimeTable { _ in
            self.isLoaded.onNext(true)
        }
    }
    
    // オブザーバーの登録
    private func setupObservers() {
        
        // 番組取得状態の監視
        isLoaded.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] finish in
                mainView.loadingLabel.isHidden = finish
                if (finish) {
                    // データ設定
                    dataSetUp()
                    selectedDataShow(originalIdx)
                    mainView.forceIndicatorToHide()
                }
                else {
                    mainView.showIndicator()
                }
             })
            .disposed(by: disposeBag)
        
        // 表示番組インデックスの変更
        changedIndex.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] idx in
                if (idx != currentIdx) {
                    Com.XLOG("インデックス変更: \(currentIdx) --> \(idx)")
                    currentIdx = idx
                    // 選択したインデクスのデータを表示
                    selectedDataShow(idx)
                }
             })
            .disposed(by: disposeBag)
        
        // Backボタン
        mainView.backBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                if let _ = matchList {
                    let idx = max(currentIdx - 1, 0)
                    changedIndex.onNext(idx)
                }
            })
            .disposed(by: disposeBag)
        
        // Nextボタン
        mainView.nextBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                if let list = matchList {
                    let idx = min(currentIdx + 1, list.count - 1)
                    changedIndex.onNext(idx)
                }
            })
            .disposed(by: disposeBag)
        
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
        
        // 更新ボタン
        mainView.updateBtn.rx.tap
            .subscribe(onNext: { [unowned self] in
                if let item = self.item {
                    self.updateBooking()
                    delegate?.updateItem(uuid: item.uuid)
                }
                self.goBack()
            })
            .disposed(by: disposeBag)
        
    }
    
    // 読み込んだ番組データから対象となるデータを抽出してセットアップ
    private func dataSetUp() {
        if matchList != nil { return }  // 番兵（一度だけ処理）
        guard let item = self.item else { return }
        let startTime = String(item.startDt.suffix(6))
        if startTime.count == 6 {
            matchList = ttHelper?.getMatchingData(searchStr: item.title, startTimeStr: startTime)
            if let matchList = matchList {
                currentIdx = matchList.firstIndex { ($0["ft"] as? String) == item.startDt } ?? -1
                Com.XLOG("マッチデータ[count=\(matchList.count) idx=\(currentIdx) time=\(startTime) - \(item.title)]\n\(matchList)")
                if currentIdx >= 0 {
                    originalIdx = currentIdx
                    Com.XLOG("カレントデータ:\(matchList[currentIdx])")
                }
            }
        }
    }
    
    // 選択したインデクスのデータを表示
    private func selectedDataShow(_ newIdx: Int) {
        // UIパーツの有効無効設定（矢印他…）
        mainView.nextBtn.isHidden = true
        mainView.backBtn.isHidden = true
        if let matchList = matchList, matchList.count > 1 {
            switch newIdx {
            case 0:
                mainView.nextBtn.isHidden = false
            case matchList.count - 1:
                mainView.backBtn.isHidden = false
            default:
                mainView.nextBtn.isHidden = false
                mainView.backBtn.isHidden = false
            }
        }
        let isCurrent = newIdx == originalIdx
        mainView.updateBtn.isHidden = isCurrent
        mainView.deleteBtn.isHidden = !isCurrent
        // 画面表示
        mainView.pageLabel.text = ""
        if newIdx < 0 {
            if let matchList = matchList, !matchList.isEmpty {
                mainView.pageLabel.text = "?/\(matchList.count)"
            }
            return
        }
        // MAPアイテムの辞書データからBookingI"temを作成
        if let bookingItem = makeBookingItem(at: newIdx) {
            // 更新による同一番組のチェック
            if !mainView.updateBtn.isHidden {
                let contxt = appDelegate.getMoContext()
                if Booking.exist(contxt, stationId: bookingItem.stationId, startDt: bookingItem.startDt) {
                    // 同じ番組がカードに既に有る
                    mainView.updateBtn.isHidden = true
                }
            }
            // 画面へ表示
            mainView.setDetailsInfo(bookingItem: bookingItem)
            // ページ表示
            mainView.pageLabel.text = "\(newIdx + 1)/\(matchList!.count)"
        }
    }
    
    // 番組データの更新
    private func updateBooking() {
        // カレントインデスクからBookingItemを作成する
        if let bookingItem = makeBookingItem(at: currentIdx) {
            // 最初に削除して（uuidとseqNoは引継ぐ）
            let context = appDelegate.getMoContext()
            if Booking.getItem(context, uuid: bookingItem.uuid) != nil {
                Booking.remove(context, uuid: bookingItem.uuid)
                _ = Booking.storeData(context, item: bookingItem, uuid: bookingItem.uuid, seqNo: bookingItem.seqNo)
                appDelegate.saveContext()
            }
            else {
                Com.XLOG("番組データの更新ができない: uuid=\(bookingItem.uuid)")
            }
            return
        }
        Com.XLOG("番組データの更新ができない: index=\(currentIdx)")
    }
    
    // 指定インデックスの番組データからBookingItemを作成する
    private func makeBookingItem(at index: Int) -> BookingItem? {
        guard let program = matchList?[index], let item = self.item else { return nil }
        guard index >= 0 && index < matchList!.count else { return nil }
        // MAPアイテムの辞書データからBookingI"temを作成
        return BookingItem(
            uuid: item.uuid,
            seqNo: Int(item.seqNo),
            stationId: item.stationId,
            startDt: program["ft"] as? String ?? "",
            endDt: program["to"] as? String ?? "",
            title: program["title"] as? String ?? "",
            bcDate: program["day"] as? String ?? "",
            bcTime: program["from_to"] as? String ?? "",
            url: program["url"] as? String ?? "",
            pfm: program["pfm"] as? String ?? "",
            imgUrl: program["img"] as? String ?? "",
            status: 0
        )
    }
}


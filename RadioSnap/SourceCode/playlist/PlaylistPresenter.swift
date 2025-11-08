//
//  PlaylistPresenter.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/14.
//

import UIKit
import RxSwift
import RxCocoa
import CoreData
import RxDataSources

struct SectionOfPlaylistData {
      var header: String
      var items: [Item]
}
extension SectionOfPlaylistData: SectionModelType {
    typealias Item = PlaylistPresenter.PlaylistListItem
    init(original: SectionOfPlaylistData, items: [Item]) {
        self = original
        self.items = items
    }
}

class PlaylistPresenter: PresenterCommon {
    // データソース
    var dataSource: RxTableViewSectionedReloadDataSource<SectionOfPlaylistData>? = nil
    
    // リストアイテム
    struct PlaylistListItem {
        var id: String
    }
    
    // UIに対応する Observable
    let isLoading: PublishSubject<Bool> = PublishSubject()                  // リストローディング中
    let list = PublishSubject<[SectionOfPlaylistData]>()
    let contentCount: PublishSubject<Int> = PublishSubject()                // カードの件数
    let playedCount: PublishSubject<Int> = PublishSubject()                 // 再生済み件数
    let isSliding: PublishSubject<Bool> = PublishSubject()                  // シークバーをスライド中

    // ソートパタン
    private let downloadDataSortPatternKey = "downloadDataSortPattern"
    var downloadDataSortPattern: Int {
        get {
            return UserDefaults.standard.integer(forKey: downloadDataSortPatternKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: downloadDataSortPatternKey)
        }
    }
    
    // 削除の確認
    private let showConfirmDeleteDialogKey = "showConfirmDeleteDialog"
    var showConfirmDeleteDialog: Bool {
        get {
            return UserDefaults.standard.bool(forKey: showConfirmDeleteDialogKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showConfirmDeleteDialogKey)
        }
    }
    
    // 共有の確認
    private let showConfirmShareDialogKey = "showConfirmShareDialog"
    var showConfirmShareDialog: Bool {
        get {
            return UserDefaults.standard.bool(forKey: showConfirmShareDialogKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showConfirmShareDialogKey)
        }
    }
    
    // コレクションのアイテム取得（スレッドで）
    func loadItems(callback: @escaping (Int) -> Void) {
        isLoading.onNext(true)
        Com.XLOG("ダウンロードアイテム取得")
        DispatchQueue.global(qos: .default).async {
            let bgContext = self.appDelegate.getMoContext()
            bgContext.perform {
                let allItem = Download.getAll(bgContext, sortPattern: self.downloadDataSortPattern)
                var newList: [PlaylistListItem] = []
                for uuid in allItem {
                    let listItem = PlaylistListItem(id: uuid)
                    newList.append(listItem)
                }
                self.list.onNext([SectionOfPlaylistData(header: "", items: newList)])
                self.contentCount.onNext(newList.count)
                self.isLoading.onNext(false)
                DispatchQueue.main.async {
                    callback(newList.count)
                }
            }
        }
    }
    
    // 再生時間を更新（DB処理）
    func updatePlayingTime(progress: PlProgress) {
        // Com.XLOG("再生時間を更新（DB処理）[\(progress.currentTime)]: \(progress.id)")
        let context = appDelegate.getMoContext()
        _ = Download.updatePlaybackSecs(
            context,
            uuid: progress.id,
            playbackSec: progress.currentTime,
            duration: progress.duration)
        appDelegate.saveContext()
    }
    
    // 再生済みに更新（DB処理）
    func updatePlayed(uuid: String) {
        // Com.XLOG("再生済みに更新（DB処理）: \(uuid)")
        let context = appDelegate.getMoContext()
        _ = Download.updatePlaybackSecs(
            context,
            uuid: uuid,
            playbackSec: 0,
            duration: 0)
        _ = Download.updateMediaStorePlayed(context, uuid: uuid, played: true)
        appDelegate.saveContext()
        checkPlayedCount()
    }
    
    // カードIDからindexを求める
    func findIndexByCardID(uuid: String) -> Int {
        var index = -1
        if dataSource == nil  {return index}    // 番兵
        let spd = dataSource!.sectionModels[0] as SectionOfPlaylistData
        for (idx, item) in spd.items.enumerated() {
            if (item.id == uuid) {
                index = idx
                break
            }
        }
        // Com.XLOG("ROW=\(index) ID:\(uuid)")
        return index
    }
    
    // データ削除
    // 削除の場合は SectionOfBookingData の item は未だ残っている（自前で削除が必要）
    func removeData(index: Int) -> Bool {
        if (dataSource == nil)  {return false}    // 番兵
        var spd = dataSource!.sectionModels[0] as SectionOfPlaylistData
        if (spd.items.indices.contains(index)) {
            let uuid = spd.items[index].id
            Com.XLOG("ダウンロードデータを削除: \(uuid)")
            remove(uuid: uuid)
            spd.items.remove(at: index) // 自前で削除が必要
            list.onNext([spd])          // 削除したのでデータ入れ換え
            self.appDelegate.saveContext()
            // リストのカウントを減算
            self.contentCount.onNext(spd.items.count)
            return true
        }
        return false
    }
    // 再生済みをチェック
    func checkPlayedCount() {
        let context = appDelegate.getMoContext()
        let count = Download.numberOfPlayedData(context)
        playedCount.onNext(count)
    }
    
    // 指定番組の削除
    private func remove(uuid: String) {
        let context = appDelegate.getMoContext()
        if Download.getItem(context, uuid: uuid) != nil {
            contentDelete(uuid: uuid)
        }
        appDelegate.saveContext()
        checkPlayedCount()
    }
    
    // 再生済みの番組を一括削除
    func removePlayed() {
        let context = appDelegate.getMoContext()
        let list = Download.getAllPlayed(context)
        for uuid in list {
            if Download.getItem(context, uuid: uuid) != nil {
                contentDelete(uuid: uuid)
            }
        }
        appDelegate.saveContext()
        checkPlayedCount()
    }
    
    // 番組DBと番組ファイルの削除
    private func contentDelete(uuid: String) {
        let context = appDelegate.getMoContext()
        let downloader = RadikoDownloader.shared
        if let item = Download.getItem(context, uuid: uuid) {
            // Com.XLOG("番組DBと番組ファイルの削除: stationId=\(item.stationId ?? "") startDt=\(item.startDt ?? "")")
            let fileName = downloader.makeDlFileName(stationId: item.stationId ?? "", startDt: item.startDt ?? "")
            // DBから削除
            Download.remove(context, uuid: uuid)
            // 番組ファイルを削除
            if downloader.isFileExists(fileName) {
                _ = downloader.deleteFile(fileName)
            }
        }
    }
    
    // ファイルの共有（実機でテスト）
    func contentsShare(viewController: PlaylistViewController, uudi: String) {
        // ファイルURLの取得
        let context = appDelegate.getMoContext()
        let downloader = RadikoDownloader.shared
        if let item = Download.getItem(context, uuid: uudi) {
            let fileName = downloader.makeDlFileName(stationId: item.stationId ?? "", startDt: item.startDt ?? "")
            if let fileURL = downloader.getAudioFileUri(fileName) {
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = viewController.view
                    popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                DispatchQueue.main.async {
                    viewController.present(activityVC, animated: true)
                }
            }
        }
    }
}

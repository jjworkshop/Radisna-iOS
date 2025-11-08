//
//  RadikoDownloaderDummy.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/22.
//

import UIKit
import RxSwift
import RxCocoa
import CoreData
import RxDataSources

// ラジコ番組のダウンローダー（UI/UXテスト用のダミーダウンローダー）
class RadikoDownloaderDummy: DownloaderBase {
    static let shared = RadikoDownloaderDummy() // シングルトンインスタンス
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var isScreenKeptOn = false
    private var isCancelled = false
    private let retryLimit = 2
        
    // OSによる強制終了を判定
    private var wasExpiredBySystem = false

    // UIに対応する Observable
    let satus: BehaviorRelay<DataLoaderStatus> = BehaviorRelay(value: DataLoaderStatus.idle)
    let reservedCount: PublishSubject<Int> = PublishSubject()
    let notification: PublishSubject<DataLoaderNotification> = PublishSubject()
    private var saveProgress: Int = -1
        
    private override init() {
        super.init()
    }
    
    // ダウンロード予約数をチェック
    func checkDownloadCount() {
        let context = self.appDelegate.getMoContext()
        let count = Booking.numberOfReservedData(context)
        reservedCount.onNext(count)
    }
    
    // ダウンロード開始
    func startDownloads(
        keepScreenOn: Bool = false,
        progressHandler: ((Int, Int) -> Void)? = nil,
        completion: @escaping ([CommandItem]) -> Void
    ) {
        makeCommandList()   // コマンドリストを作成
        guard !commands.isEmpty else {
            completion(commands)
            return
        }
        isCancelled = false
        Com.XLOG("🟢 ダウンロード開始 - \(commands.count)件")
        
        wasExpiredBySystem = false
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AudioBatchDownload") {
            self.wasExpiredBySystem = true
            self.finish(commands: self.commands, completion: completion)
        }

        if keepScreenOn {
            // スクリーンをONを維持し画面を暗くする
            isScreenKeptOn = true
            UIApplication.shared.isIdleTimerDisabled = true
            UIScreen.main.brightness = 0.1
        }

        // 最初のダウンロード開始
        self.downloadNext(
            index: 0,
            attempt: 0,
            progressHandler: progressHandler,
            completion: completion
        )
    }
    
    // コマンドリストを順次実行
    private func downloadNext(
        index: Int,
        attempt: Int,
        progressHandler: ((Int, Int) -> Void)?,
        completion: @escaping ([CommandItem]) -> Void
    ) {
        guard !isCancelled else {
            if index < commands.count {
                commands[index].result = 9 // Cancelled
            }
            finish(commands: commands, completion: completion)
            return
        }

        guard index < commands.count else {
            finish(commands: commands, completion: completion)
            return
        }
        // コマンドの進捗更新
        let currentIndex = index
        let totalCount = commands.count
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                progressHandler?(currentIndex + 1, totalCount)
            }
            // BGタスクの残り時間をログ
            if UIApplication.shared.applicationState == .background {
                let remaining = UIApplication.shared.backgroundTimeRemaining
                Com.XLOG("BGタスク残り時間: \(remaining) 秒")
            }
        }
        // ダウンロード開始を通知
        self.notification.onNext(
            DataLoaderNotification(
                uuid: self.commands[index].uuid,
                progress: 0,
                completion: 8)
        )
        // ダミーループ
        let command = self.commands[index]
        DispatchQueue.global().async {
            let success = true
            for i in 0..<100 {
                if self.isCancelled {
                    DispatchQueue.main.async {
                        self.commands[index].result = 9 // キャンセル
                        Com.XLOG("ダウンロード中キャンセル[\(command.title)]")
                        // 完了通知
                        self.notification.onNext(
                            DataLoaderNotification(
                                uuid: self.commands[index].uuid,
                                progress: 0,
                                completion: self.commands[index].result)
                        )
                        self.finish(commands: self.commands, completion: completion)
                    }
                    return
                }
                // Simulate progress update if needed
                Thread.sleep(forTimeInterval: 0.1)  // １ダウンロードで約２分（1.2 * 100 = 120秒）
                // 進捗をUIに通知
                self.notification.onNext(DataLoaderNotification(uuid: command.uuid, progress: i))
            }
            // Mark as success
            self.commands[index].result = 0 // 正常ダウンロード
            // ダミーファイルを作成
            self.createDummyFile(command.saveFile)
            Com.XLOG("ダウンロード完了[\(self.commands[index].title)]: success=\(success) cancel=\(self.isCancelled)")
            // 完了通知
            self.notification.onNext(
                DataLoaderNotification(
                    uuid: self.commands[index].uuid,
                    progress: 0,
                    completion: self.commands[index].result)
            )
            // Proceed to next command
            self.downloadNext(
                index: index + 1,
                attempt: 0,
                progressHandler: progressHandler,
                completion: completion
            )
        }
        
    }
    
    // ダウンロードが完了
    private func finish(commands: [CommandItem], completion: @escaping ([CommandItem]) -> Void) {
        // ダウンロードが完了したら、バックグラウンドタスクを終了
        endBackgroundTask()
        DispatchQueue.main.async {
            if self.isScreenKeptOn {
                // スクリーンをONの維持を解除
                UIApplication.shared.isIdleTimerDisabled = false
                UIScreen.main.brightness = self.originalBrightness
                self.isScreenKeptOn = false
            }
            completion(commands)
        }
    }

    // バックグラウンドタスクを終了
    private func endBackgroundTask() {
        if wasExpiredBySystem {
            Com.XLOG("⚠️ BGタスクはシステムにより期限切れで終了！")
        } else {
            Com.XLOG("✅ BGタスクは正常に完了！")
        }
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // ダウンロードキャンセル
    func cancelDownload() {
        isCancelled = true
    }
        
    // ダミーファイル作成
    func createDummyFile(_ fileName: String) {
        guard let fileURL = getAudioFileUri(fileName) else { return }
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        }
    }
}

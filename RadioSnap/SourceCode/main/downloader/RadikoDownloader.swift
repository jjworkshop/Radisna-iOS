//
//  RadikoDownloader.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/19.
//

import UIKit
import RxSwift
import RxCocoa
import CoreData
import RxDataSources
import Alamofire
import CoreLocation
import ffmpegkit

// ラジコ番組のダウンローダー（Single）
// このクラスは、RadikoDownloaderPara とどちらかしかインスタンス化できない
// 使うときは、こちらを RadikoDownloader に変更する
class RadikoDownloaderSingle: DownloaderBase {
    static let shared = RadikoDownloaderSingle()  // シングルトンインスタンス
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var isScreenKeptOn = false
    private var isCancelled = false
    private var currentSession: FFmpegSession? = nil
    
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
        Com.XLOG("🔴 ダウンロード開始 - \(commands.count)件")
        
        wasExpiredBySystem = false
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AudioBatchDownload") {
            self.wasExpiredBySystem = true
            Com.XLOG("🙅‍♀️ダウンロード強制終了")
            if self.currentSession != nil {
                Com.XLOG("ダウンロード中キャンセル[by system]")
                self.currentSession?.cancel()
                self.currentSession = nil
                self.finish(commands: self.commands, completion: completion)
            }
            else {
                self.endBackgroundTask()
            }
        }

        if keepScreenOn {
            // スクリーンをONを維持し画面を暗くする
            isScreenKeptOn = true
            UIApplication.shared.isIdleTimerDisabled = true
            UIScreen.main.brightness = 0.1
        }

        // ラジコログイン
        Com.XLOG("ログイン開始")
        login() { success in
            if success {
                Com.XLOG("ログイン成功")
                // 最初のダウンロード開始
                self.downloadNext(
                    index: 0,
                    progressHandler: progressHandler,
                    completion: completion
                )
            }
            else {
                Com.XLOG("ログイン失敗")
                DispatchQueue.main.async {
                    progressHandler?(-1, -1)
                }
            }
        }
    }
    
    // コマンドリストを順次実行
    private func downloadNext(
        index: Int,
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
        // 既存ファイルがあれば削除
        let saveFile = commands[index].saveFile
        if isFileExists(saveFile) {
            if deleteFile(saveFile) {
                Com.XLOG("既存ファイル削除: \(saveFile)")
            }
        }
        // ダウンロード開始を通知
        Com.XLOG("ダウンロード開始[\(commands[index].title)] - \(commands[index].uuid)")
        self.notification.onNext(
            DataLoaderNotification(
                uuid: self.commands[index].uuid,
                progress: 0,
                completion: 8)
        )
        // ラジコのトークンをパラメタに設定
        let token = authtoken ?? ""
        let parameter = commands[index].command.replacingOccurrences(of: "%token%", with: token)
        saveProgress = -1
        // FFmpegKitを使用してダウンロードを実行
        currentSession = FFmpegKit.executeAsync(parameter) { session in
            let success = ReturnCode.isSuccess(session?.getReturnCode())
            // ダウンロード完了通知
            self.notification.onNext(
                DataLoaderNotification(
                    uuid: self.commands[index].uuid,
                    progress: 0,
                    completion: self.isCancelled ? 9 : (success ? 0: 1))
            )
            Com.XLOG("ダウンロード完了[\(self.commands[index].title)]: \(success ? "⭕️" : "❌️") cancel=\(self.isCancelled)")
            // 次の処理をチェック
            if self.isCancelled {
                self.commands[index].result = 9 // Cancelled
                self.finish(commands: self.commands, completion: completion)
                return
            }
            if success {
                self.commands[index].result = 0 // Success
                self.downloadNext(
                    index: index + 1,
                    progressHandler: progressHandler,
                    completion: completion
                )
            }
            else {
                self.commands[index].result = 1 // Fail
                self.finish(commands: self.commands, completion: completion)
            }
        } withLogCallback: { log in
            // ログ出力（必要あれば）
        } withStatisticsCallback: { statistics in
            guard let stats = statistics else { return }
            let time = stats.getTime() // ミリ秒単位
            DispatchQueue.main.async {
                let command = self.commands[index]
                if self.isCancelled {
                    // ダウンロード途中でキャンセルされた場合
                    if self.currentSession != nil {
                        Com.XLOG("ダウンロード中キャンセル[\(command.title)]")
                        self.currentSession?.cancel()
                        self.currentSession = nil
                    }
                    else {
                        Com.XLOG("すでにキャンセル済み")
                    }
                    return
                }
                // 進捗状況
                if self.commands[index].playSeconds > 0 {
                    let progress = Int(Double(time) / Double(command.playSeconds * 1000) * 100)
                    if progress != self.saveProgress {
                        self.saveProgress = progress
                        // Com.XLOG("ダウンロード中[\(command.title)]: \(command.playSeconds) - \(time)")
                        // 進捗をUIに通知
                        self.notification.onNext(DataLoaderNotification(uuid: command.uuid, progress: progress))
                    }
                }
            }
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
}


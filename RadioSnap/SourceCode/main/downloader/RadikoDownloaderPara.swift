//
//  RadikoDownloaderPara.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/05.
//

import UIKit
import RxSwift
import RxCocoa
import CoreData
import RxDataSources
import Alamofire
import CoreLocation
import ffmpegkit

// ラジコ番組のダウンローダー（Parallels）
class RadikoDownloader: DownloaderBase {
    static let shared = RadikoDownloader()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    
    // 最大並行稼働数
    var maxDownloadCount = 3
    private var semaphore: DispatchSemaphore
    
    private var activeTasks: [UUID: FFmpegSession] = [:]
    // シリアルキュー＋QoS指定
    private let queue = DispatchQueue(label: "radiko.download.queue", qos: .userInitiated)
    private var isCancelled = false
    private var isScreenKeptOn = false
    
    // UIに対応する Observable
    let satus: BehaviorRelay<DataLoaderStatus> = BehaviorRelay(value: DataLoaderStatus.idle)
    let reservedCount: PublishSubject<Int> = PublishSubject()
    let notification: PublishSubject<DataLoaderNotification> = PublishSubject()
    
    private override init() {
        Com.XLOG("MAX DL同時処理 - \(maxDownloadCount)")
        self.semaphore = DispatchSemaphore(value: maxDownloadCount)
        super.init()
    }
    
    // ダウンロード予約数をチェック
    func checkDownloadCount() {
        let context = self.appDelegate.getMoContext()
        let count = Booking.numberOfReservedData(context)
        DispatchQueue.main.async {
            self.reservedCount.onNext(count)
        }
    }
    
    // ダウンロード開始
    func startDownloads(
        keepScreenOn: Bool = false,
        progressHandler: ((Int, Int) -> Void)? = nil,
        completion: @escaping ([CommandItem]) -> Void
    ) {
        self.semaphore = DispatchSemaphore(value: maxDownloadCount)
        makeCommandList()   // コマンドリストを作成
        guard !commands.isEmpty else {
            completion(commands)    // 完了通知（空）
            return
        }
        isCancelled = false
        Com.XLOG("🟠 ダウンロード開始 - \(commands.count)件")

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AudioBatchDownload") {
            Com.XLOG("🙅‍♀️ダウンロード強制終了")
            self.cancelDownload()
            self.finish(commands: self.commands, completion: completion)
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
                // ダウンロード開始
                self.start(progressHandler: progressHandler ,completion: completion)
            }
            else {
                Com.XLOG("ログイン失敗")
                DispatchQueue.main.async {
                    progressHandler?(-1, -1)    // 進捗通知（ログインエラー）
                }
            }
        }
    }
    
    // ダウンロードスタート
    private func start(
        progressHandler: ((Int, Int) -> Void)?,
        completion: @escaping ([CommandItem]) -> Void
    ) {
        let group = DispatchGroup()
        for (index, _) in commands.enumerated() {
            if isCancelled {
                commands[index].result = 9
                break
            }
            group.enter()
            queue.async {
                self.semaphore.wait()
                // defer { self.semaphore.signal() } は削除

                // コマンドの進捗更新
                DispatchQueue.main.async {
                    if UIApplication.shared.applicationState == .active {
                        // 進捗通知（処理開始 n/n 件目）
                        progressHandler?(index + 1, self.commands.count)
                    }
                    // BGタスクの残り時間をログ
                    if UIApplication.shared.applicationState == .background {
                        let remaining = UIApplication.shared.backgroundTimeRemaining
                        Com.XLOG("BGタスク残り時間: \(remaining) 秒")
                    }
                }
                // 既存ファイルがあれば削除
                let saveFile = self.commands[index].saveFile
                if self.isFileExists(saveFile) {
                    if self.deleteFile(saveFile) {
                        Com.XLOG("既存ファイル削除: \(saveFile)")
                    }
                }
                // ダウンロード開始を通知
                DispatchQueue.main.async {
                    self.notification.onNext(
                        DataLoaderNotification(
                            uuid: self.commands[index].uuid,
                            progress: 0,
                            completion: 8)
                    )
                }
                // ラジコのトークンをパラメタに設定
                let token = self.authtoken ?? ""
                let parameter = self.commands[index].command.replacingOccurrences(of: "%token%", with: token)
                // 並行処理でダウンロード
                let sessionId = UUID()
                var oldProgress = -1
                var session: FFmpegSession? = nil
                session = FFmpegKit.executeAsync(
                    parameter,
                    withCompleteCallback: { session in
                        // ダウンロード完了通知
                        let success = ReturnCode.isSuccess(session?.getReturnCode())
                        DispatchQueue.main.async {
                            self.notification.onNext(
                                DataLoaderNotification(
                                    uuid: self.commands[index].uuid,
                                    progress: 0,
                                    completion: self.isCancelled ? 9 : (success ? 0: 1))
                            )
                        }
                        Com.XLOG("ダウンロード完了[\(self.commands[index].title)]: \(success ? "⭕️" : "❌️") cancel=\(self.isCancelled)")
                        self.commands[index].result = success ? 0 : 1
                        self.activeTasks.removeValue(forKey: sessionId)
                        group.leave()
                        self.semaphore.signal() // ここでsignal
                    },
                    withLogCallback: { log in
                        // ログ出力（必要あれば）
                        // Com.XLOG("Log: \(log?.getMessage() ?? "")")
                    },
                    withStatisticsCallback: { statistics in
                        guard let stats = statistics else { return }
                        let time = stats.getTime() // ミリ秒単位
                        DispatchQueue.main.async {
                            let command = self.commands[index]
                            if self.isCancelled {
                                // ダウンロード途中でキャンセルされた場合
                                if session != nil {
                                    Com.XLOG("ダウンロード中キャンセル[\(command.title)]")
                                    self.commands[index].result = 9
                                    session?.cancel()
                                    session = nil
                                }
                                else {
                                    Com.XLOG("すでにキャンセル済み")
                                }
                                return
                            }
                            // 進捗状況
                            if self.commands[index].playSeconds > 0 {
                                let progress = Int(Double(time) / Double(command.playSeconds * 1000) * 100)
                                if progress != oldProgress {
                                    oldProgress = progress
                                    // Com.XLOG("ダウンロード中[\(command.title)]: \(command.playSeconds) - \(time)")
                                    // 進捗をUIに通知
                                    self.notification.onNext(DataLoaderNotification(uuid: command.uuid, progress: progress))
                                }
                            }
                        }
                    }
                )
                if let session = session {
                    self.activeTasks[sessionId] = session
                }
            } // end queue.async...
        } // end For..
        group.notify(queue: .main) {
            self.finish(commands: self.commands, completion: completion)
        }
    }

    // ダウンロード完了
    private func finish(commands: [CommandItem], completion: @escaping ([CommandItem]) -> Void) {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        for (_, session) in activeTasks {
            session.cancel()
        }
        self.activeTasks.removeAll()
        DispatchQueue.main.async {
            if self.isScreenKeptOn {
                // スクリーンをONの維持を解除
                UIApplication.shared.isIdleTimerDisabled = false
                UIScreen.main.brightness = self.originalBrightness
                self.isScreenKeptOn = false
            }
        }
        completion(commands)    // 完了通知（OK or ERR）
        Com.XLOG("✅ 全てのダウンロードが完了")
    }

    // ダウンロードキャンセル（システムからの矯正終了でも呼ばれる）
    func cancelDownload() {
        isCancelled = true
        Com.XLOG("⚠️ 全ての、処理中と処理予約のダウンロードをキャンセル[\(activeTasks.count)]")
    }
}

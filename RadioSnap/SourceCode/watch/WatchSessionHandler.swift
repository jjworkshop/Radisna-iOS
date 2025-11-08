//
//  WatchSessionHandler.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/11.
//

import UIKit
import RxSwift
import WatchConnectivity

// [Watch] セションハンドラ
class WatchSessionHandler: NSObject, WCSessionDelegate {
    
    static let shared = WatchSessionHandler()
    
    let watchCommandNotification: PublishSubject<String> = PublishSubject() 
    
    private override init() {
        super.init()
        activateSession()
    }

    private func activateSession() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // メッセージ受信（応答あり）
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let command = message["command"] as? String else { return }
        switch command {
        case "getCurrentAndList":
            // 番組リストと現在の番組を返す
            handleGetCurrentAndList(replyHandler: replyHandler)
        default:
             break
        }
    }

    // メッセージ受信（応答なし）
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let command = message["command"] as? String else { return }
        DispatchQueue.main.async {
            let audioPlayer = AudioPlayerManager.shared

            switch command {
            case "play":
                if let uuid = message["uuid"] as? String {
                    if audioPlayer.currentItem?.uuid == uuid {
                        if audioPlayer.isPlaying.value {
                            Com.XLOG("[WSH-iOS] pause")
                            audioPlayer.pause()
                        } else {
                            Com.XLOG("[WSH-iOS] resume")
                            audioPlayer.resume()
                        }
                    } else {
                        Com.XLOG("[WSH-iOS] new play: \(uuid)")
                        self.playAudio(uuid)
                    }
                }
            case "seek":
                if let offset = message["offset"] as? Int {
                    Com.XLOG("[WSH-iOS] seek:\(offset > 0 ? "forward10" : "rewind10")")
                    if offset > 0 {
                        audioPlayer.forward10Seconds()
                    } else {
                        audioPlayer.rewind10Seconds()
                    }
                }
            default:
                break
            }
        }
        // PlaylistViewControllerに通知
        watchCommandNotification.onNext(command)
    }


    // 番組リストと現在の番組を返す（バックグラウンドで処理される：AI回答）
    private func handleGetCurrentAndList(replyHandler: @escaping ([String: Any]) -> Void) {
        let sortPattern = UserDefaults.standard.integer(forKey: "downloadDataSortPattern")
        let backgroundContext = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            let programList = Download.getProgramList(backgroundContext, sortPattern: sortPattern)
            // replyHandler はメインスレッドで呼び出す
            DispatchQueue.main.async {
                let audioPlayer = AudioPlayerManager.shared
                let currentUUID = audioPlayer.currentItem?.uuid ?? ""
                let currentIndex = programList.firstIndex { $0["uuid"] == currentUUID } ?? -1
                replyHandler([
                    "currentIndex": currentIndex,
                    "list": programList,
                    "isPlaying": audioPlayer.isPlaying.value
                ])
            }
        }
    }

    
    // 新しい番組をプレイヤーで再生依頼
    private func playAudio(_ uuid: String) {
        let backgroundContext = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            guard let item = Download.getItem(backgroundContext, uuid: uuid),
                  let stationId = item.stationId,
                  let startDt = item.startDt else {
                return
            }
            let downloadItem = DownloadItem.from(download: item)
            let downloader = RadikoDownloader.shared
            let fileName = downloader.makeDlFileName(stationId: stationId, startDt: startDt)
            guard let audioUrl = downloader.getAudioFileUri(fileName) else {
                return
            }
            // AudioPlayerManager はメインスレッドで呼び出す
            DispatchQueue.main.async {
                let audioPlayer = AudioPlayerManager.shared
                Com.XLOG("[WSH-iOS] playAudio: \(downloadItem.title)")
                audioPlayer.playAudio(with: audioUrl, item: downloadItem)
            }
        }
    }

}

// MARK: - WCSessionDelegate その他

extension WatchSessionHandler {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Com.XLOG("[WSH-iOS] セッションがアクティブになった")
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        Com.XLOG("[WSH-iOS] セッション接続状態が変更になった")
    }
    func sessionDidBecomeInactive(_ session: WCSession) {
        Com.XLOG("[WSH-iOS] セッションが非アクティブになった")
    }
    func sessionDidDeactivate(_ session: WCSession) {
        Com.XLOG("[WSH-iOS] セッションが無効になった")
    }
}

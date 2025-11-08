//
//  WatchSessionManager.swift
//  RadioSnapWatch Watch App
//
//  Created by Mitsuhiro Shirai on 2025/06/11.
//

import WatchConnectivity

class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {
        
    @Published var currentIndex: Int? = nil
    @Published var programList: [(uuid: String, title: String, played: Bool)] = []
    @Published var errorMessage: String? = nil
    @Published var isSessionActivated = false
    @Published var isPlaying = false
    @Published var didReceiveCurrentAndList: Bool = false
    
    private var connectionErrorCount = 0
    private let maxConnectionErrorCount = 3

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func requestCurrentAndList() {
        // Com.XLOG("[Watch] iPhoneへリクエスト")
        guard WCSession.default.isReachable else {
            DispatchQueue.main.async {
                if self.connectionErrorCount < self.maxConnectionErrorCount {
                    self.errorMessage = "M:iPhoneと接続中…"
                    self.connectionErrorCount += 1
                } else {
                    self.errorMessage = "iPhoneと通信中断"
                }
            }
            return
        }

        WCSession.default.sendMessage(["command": "getCurrentAndList"], replyHandler: { response in
            DispatchQueue.main.async {
                // 通信成功時はエラーをクリア
                self.errorMessage = nil
                self.connectionErrorCount = 0
            }
            // Com.XLOG("[Watch] 番組リクエストリザルト: response.count=\(response.count)")
            if let list = response["list"] as? [[String: String]] {
                let parsedList = list.compactMap { item in
                    if let uuid = item["uuid"], let title = item["title"], let playedStr = item["played"] {
                        let played = (playedStr == "true")
                        return (uuid: uuid, title: title, played: played)
                    }
                    return nil
                }
                DispatchQueue.main.async {
                    self.programList = parsedList
                }
            }
            if let index = response["currentIndex"] as? Int {
                DispatchQueue.main.async {
                    self.currentIndex = index
                }
            }
            if let isPlaying = response["isPlaying"] as? Bool {
                DispatchQueue.main.async {
                    self.isPlaying = isPlaying
                }
            }
            DispatchQueue.main.async {
                // MainViewにレスポンスがあったことを通知
                self.didReceiveCurrentAndList = true
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.errorMessage = "Reconnecting…"
            }
        })
    }

    var currentProgramTitle: String {
        guard let index = currentIndex, 0 <= index && index < programList.count else {
            return ""   // 番組未選択
        }
        return programList[index].title
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error = error {
            Com.XLOG("[Watch] Err:\(error.localizedDescription)")
        } else {
            Com.XLOG("[Watch] セッションがアクティブになった")
            DispatchQueue.main.async {
                self.isSessionActivated = true
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            Com.XLOG("[Watch] セッションは到達可能")
        } else {
            Com.XLOG("[Watch] セッションは到達不可能")
        }
    }
}

// MARK: - iPhoneへコマンド送信

extension WatchSessionManager {
    
    /// iPhoneにコマンドを送信する共通メソッド
    func sendCommand(_ command: String, parameters: [String: Any] = [:]) {
        guard WCSession.default.isReachable else {
            DispatchQueue.main.async {
                self.errorMessage = "iPhoneと通信できません"
            }
            return
        }

        var message = parameters
        message["command"] = command

        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            DispatchQueue.main.async {
                self.errorMessage = "送信エラー"
            }
        }
    }

    /// 現在選択中の番組を再生とポーズ（どちらを処理するかは iPhone 側で判定）
    func sendPlayCommand() {
        guard let index = currentIndex, 0 <= index && index < programList.count else { return }
        let uuid = programList[index].uuid
        sendCommand("play", parameters: ["uuid": uuid])
    }

    /// 明示的にUUIDを指定して番組を再生（新規選択時など）
    func sendPlayCommand(uuid: String) {
        sendCommand("play", parameters: ["uuid": uuid])
    }

    /// シーク（±秒）
    func sendSeekCommand(offset: Int) {
        sendCommand("seek", parameters: ["offset": offset])
    }
}

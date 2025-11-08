//
//  DownloaderBase.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/04.
//

import UIKit
import Alamofire
import ffmpegkit

// ダウンローダーステータス
enum DataLoaderStatus: Int {
    case idle = 0
    case selecting = 1
    case downloading = 2
}

// コマンドアイテム
struct CommandItem {
    var uuid: String
    var title: String
    var saveFile: String
    var command: String
    var playSeconds: Int64
    var result: Int             // -1=未処理、0=成功、1=失敗、9=キャンセル
}

// UI通知
struct DataLoaderNotification {
    var uuid: String
    var progress: Int
    var completion: Int? = nil  // nil=progresが有効、0=成功、1=失敗、8=ダウンロード中、9=キャンセル
}

// ダウンローダーベースクラス
class DownloaderBase: PresenterCommon {
    
    // ラジコ認証関連
    private var isNoLoginMode = false
    var authtoken: String? = nil
  
    // 保存パス
    let saveFolderName = "audio"
    var savePath: String? = nil
    
    // コマンドリスト
    var commands: [CommandItem] = []
    
    override init() {
        super.init()
        // 番組の保存パスを作成
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let audioURL = documentsURL.appendingPathComponent(saveFolderName)
            savePath = audioURL.path
            if !fileManager.fileExists(atPath: audioURL.path) {
                do {
                    // ディレクトリを作成
                    try fileManager.createDirectory(at: audioURL, withIntermediateDirectories: true, attributes: nil)
                    // バックアップ対象から除外
                    var resourceValues = URLResourceValues()
                    resourceValues.isExcludedFromBackup = true
                    var mutableAudioURL = audioURL
                    try mutableAudioURL.setResourceValues(resourceValues)

                } catch {
                    savePath = nil
                    Com.XLOG("Failed to create audio directory or set backup exclusion: \(error)")
                }
            }
        }
        Com.XLOG("番組保存パス: \(savePath ?? "No Path")")
    }
    
    // 予約データを取得してコマンドリストを作成
    func makeCommandList() {
        commands.removeAll()
        let context = self.appDelegate.getMoContext()
        let list = Booking.getAllDesignated(context, status: 7) // ダウンロード予約
        for uuid in list {
            if let item = Booking.getItem(context, uuid: uuid) {
                let saveFile = makeDlFileName(stationId: item.stationId ?? "", startDt: item.startDt ?? "")
                createFFmpegCommand(item: item, saveFile: saveFile) { command, playSeconds in
                    let commandList = CommandItem(
                        uuid: uuid,
                        title: item.title ?? "",
                        saveFile: saveFile,
                        command: command,
                        playSeconds: playSeconds,
                        result: -1)
                    self.commands.append(commandList)
                }
            }
        }
    }

    // FFmpegのコマンド作成（トークンはあとから設定: %token% を置換する）
    func createFFmpegCommand(item: Booking, saveFile: String, completion: @escaping ((String, Int64) -> Void)) {
        let ft =        item.startDt ?? ""
        let to =        item.endDt ?? ""
        let title =     item.title ?? ""
        let stationId = item.stationId ?? ""
        let imgUrl =    item.imgUrl ?? ""
        // 空白項目がある場合は、コマンドを作成しない
        if ft.isEmpty || to.isEmpty || title.isEmpty || stationId.isEmpty || imgUrl.isEmpty {
            completion("", 0)
            return
        }
        Com.XLOG("FFmpeg[\(title)] \(ft) 〜 \(to)")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        guard let ftDate = formatter.date(from: ft),
              let toDate = formatter.date(from: to) else {
            completion("", 0)
            return
        }
        let playSeconds = Int64(toDate.timeIntervalSince(ftDate))
        let artist = AppCom.getStationNameById(stationId)
        let album = title
        guard let fileURL = getAudioFileUri(saveFile) else {
            completion("", playSeconds)
            return
        }
        let outputPath = fileURL.path
        let inputUrl = "https://radiko.jp/v2/api/ts/playlist.m3u8?station_id=\(stationId)&l=15&ft=\(ft)&to=\(to)"
        getCoverImage(imgUrl: imgUrl) { coverImagePath in
            let command = """
            -headers "X-RADIKO-AUTHTOKEN: %token%" -i "\(inputUrl)" -i "\(coverImagePath)" -map 0 -map 1 -c copy -metadata artist="\(artist)" -metadata album="\(album)" -disposition:v attached_pic "\(outputPath)"
            """
            completion(command, playSeconds)
        }
    }
    
    // 番組カバーイメージを一時ファイルとしてダウンロード（ファイルはメタ情報として音声ファイルに保存される）
    func getCoverImage(imgUrl: String, completion: @escaping (String) -> Void) {
        let fileName = Com.getFileNameWithExtension(url: imgUrl)
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let coverImageFile = cacheDir.appendingPathComponent(fileName)
        completion(coverImageFile.path) // 完了を待たずに返す
        if FileManager.default.fileExists(atPath: coverImageFile.path) {
            Com.XLOG("カバーIMG[\(fileName)] 既に存在")
            return
        }
        AF.download(imgUrl).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    try data.write(to: coverImageFile)
                    Com.XLOG("カバーIMG[\(fileName)] 取得")
                } catch {
                    Com.XLOG("カバーIMG[\(fileName)] エラー(\(error.localizedDescription))")
                }
            case .failure(let error):
                Com.XLOG("カバーIMG[\(fileName)] エラー(\(error.localizedDescription))")
            }
        }
    }
    
    // ダウンロードファイル名の組み立て
    func makeDlFileName(stationId: String, startDt: String) -> String {
        return "\(stationId)-\(startDt).m4a"
    }
    
    // ファイルのURIを取得
    func getAudioFileUri(_ fileName: String) -> URL?{
        guard let audioPath = savePath else { return nil }
        return URL(fileURLWithPath: audioPath).appendingPathComponent(fileName)
    }
                
    // ファイルの存在チェック
    func isFileExists(_ fileName: String) -> Bool {
        guard let fileURL = getAudioFileUri(fileName) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // ファイルを削除
    func deleteFile(_ fileName: String) -> Bool {
        guard let fileURL = getAudioFileUri(fileName) else { return false }
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - ラジコサイトの認証処理関連

extension DownloaderBase {
    // ログイン
    func login(_ email: String = "", _ psw: String = "", completion: @escaping (Bool) -> Void) {
        if email.isEmpty && psw.isEmpty {
            // R11 ログイン無しで処理可能に！
            isNoLoginMode = true
            // ダウンロードトークン取得
            getAuthToken(sessionId: nil) { token in
                self.authtoken = token
                if let token = token {
                    Com.XLOG("authtoken(no login): \(token)")
                    completion(true)
                } else {
                    Com.XLOG("authtoken(no login): auth error-1!")
                    completion(false)
                }
            }
            return
        }
        // radikoセションID取得
        getSessionId(email: email, psw: psw) { sessionId in
            if let sessionId = sessionId {
                Com.XLOG("sessionId: \(sessionId)")
                // ダウンロードトークン取得
                self.getAuthToken(sessionId: sessionId) { token in
                    self.authtoken = token
                    if let token = token {
                        Com.XLOG("authtoken(use login): \(token)")
                        completion(true)
                    } else {
                        Com.XLOG("authtoken(use login): auth error-1!")
                        completion(false)
                    }
                }
            } else {
                Com.XLOG("authtoken: auth error-2!")
                completion(false)
            }
        }
    }

    // radikoセッションID取得（ステップ１: R11-ログイン無しの場合は処理しない）
    private func getSessionId(email: String, psw: String, completion: @escaping (String?) -> Void) {
        let url = "https://radiko.jp/v4/api/member/login"
        let parameters: [String: String] = [
            "mail": email,
            "pass": psw
        ]
        AF.request(url, method: .post, parameters: parameters)
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let sid = dict["radiko_session"] as? String {
                            completion(sid)
                        } else {
                            completion(nil)
                        }
                    } catch {
                        completion(nil)
                    }
                case .failure:
                    completion(nil)
                }
            }
    }

    // radikoのauthTokenを取得（ステップ２: R11-ログイン無しの場合、[sid]radiko_sessionは不要）
    private func getAuthToken(sessionId: String?, completion: @escaping (String?) -> Void) {
        let UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36"
        let AUTHKEY = "bcd151073c03b352e1ef2fd66c32209da9ca0afa"

        let headers1: HTTPHeaders = [
            "User-Agent": UA,
            "Accept": "*/*",
            "x-radiko-user": "dummy_user",
            "x-radiko-app": "pc_html5",
            "x-radiko-app-version": "0.0.1",
            "x-radiko-device": "pc"
        ]
        let url1 = "https://radiko.jp/v2/api/auth1"
        AF.request(url1, headers: headers1).response { response in
            guard let httpResponse = response.response else {
                completion(nil)
                return
            }
            guard let token = httpResponse.value(forHTTPHeaderField: "X-Radiko-AUTHTOKEN"),
                  let lengthStr = httpResponse.value(forHTTPHeaderField: "X-Radiko-KeyLength"),
                  let offsetStr = httpResponse.value(forHTTPHeaderField: "X-Radiko-KeyOffset"),
                  let length = Int(lengthStr),
                  let offset = Int(offsetStr) else {
                completion(nil)
                return
            }
            let partialKeyData = AUTHKEY.dropFirst(offset).prefix(length).data(using: .utf8) ?? Data()
            let partialKey = partialKeyData.base64EncodedString()
            Com.XLOG("Auth Token: \(token)")
            Com.XLOG("Encoded Key: \(partialKey)")

            let headers2: HTTPHeaders = [
                "User-Agent": UA,
                "Accept": "*/*",
                "x-radiko-user": "dummy_user",
                "X-RADIKO-AUTHTOKEN": token,
                "x-radiko-partialkey": partialKey,
                "X-Radiko-App": "pc_html5",
                "X-Radiko-App-Version": "0.0.1",
                "x-radiko-device": "pc"
            ]
            var url2 = "https://radiko.jp/v2/api/auth2"
            if let sessionId = sessionId {
                url2 += "?radiko_session=\(sessionId)"
            }
            AF.request(url2, headers: headers2).response { response2 in
                if let httpResponse2 = response2.response, httpResponse2.statusCode == 200 {
                    completion(token)
                } else {
                    completion(nil)
                }
            }
        }
    }
}

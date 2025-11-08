//
//  AudioPlayerManager.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/04.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation
import MediaPlayer

// 再生時のプログレス情報
struct PlProgress: Equatable {
    var id: String              // Downloadデータの uuid
    var currentTime: Int        // currentTime: 再生している位置（秒）
    var duration: Int           // duration: 番組の長さ（秒）
    static func == (lhs: PlProgress, rhs: PlProgress) -> Bool {
        return lhs.id == rhs.id && lhs.currentTime == rhs.currentTime && lhs.duration == rhs.duration
    }
}

class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()  // シングルトンインスタンス
    
    let isActive: BehaviorRelay<Bool>  = BehaviorRelay(value:false)     // プレイヤーアクティブ
    let isPlaying: BehaviorRelay<Bool> = BehaviorRelay(value:false)     // 再生中
    let playerProgress: PublishSubject<PlProgress> = PublishSubject()   // 再生中のプログレス通知
    let playerFinished: PublishSubject<String> = PublishSubject()       // 再生完了通知（完了したUUIDを通知）
    
    // キャッシュ
    var currentItem: DownloadItem? = nil
    var currentItemImage: UIImage? = nil

    var audioPlayer: AVAudioPlayer?
    var progressTimer: Timer?

    private override init() {
        super.init()
        // イヤホンからのコントロール
        setupRemoteCommandCenter()
        // イヤホンが抜けたときを監視するため
        setupAudioRouteChangeObserver()
    }

    // 再生開始（既に再生中の場合は切り替えて再生）
    func playAudio(with url: URL, item: DownloadItem) {
        isPlaying.accept(false)
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            progressTimer?.invalidate()
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Com.XLOG("Audio session error: \(error)")
            return
        }

        do {
            Com.XLOG("再生開始: \(item.title) playbackSec=\(item.playbackSec)")
            currentItem = item
            currentItemImage = getArtworkImage(imgUrl: item.imgUrl)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            setCurrent(Double(item.playbackSec))    // 再生位置に移動
            audioPlayer?.play()
            startProgressTimer()
            // ロック画面への表示
            updateNowPlayingInfo(
                title: item.title,
                artist: item.pfm,
                duration: audioPlayer?.duration ?? 0,
                artworkImage: currentItemImage
            )
            // プレイヤーアクティブとプレイ中
            isPlaying.accept(true)
            isActive.accept(true)
        } catch {
            Com.XLOG("Audio player error: \(error)")
        }
    }

    // 再生再開
    func resume() {
        guard let player = audioPlayer, !player.isPlaying else { return }
        player.play()
        startProgressTimer()
        isPlaying.accept(true)
    }

    // 停止
    func pause() {
        guard let player = audioPlayer, player.isPlaying else { return }
        player.pause()
        progressTimer?.invalidate()
        isPlaying.accept(false)
    }

    // 10秒進める
    func forward10Seconds() {
        guard let player = audioPlayer else { return }
        // 最大を１秒前にしているのは、通知を通して終了を発火させるため
        player.currentTime = min(player.currentTime + 10, player.duration - 1)
    }

    // 10秒戻す
    func rewind10Seconds() {
        guard let player = audioPlayer else { return }
        player.currentTime = max(player.currentTime - 10, 0)
    }
    
    // 指定の再生位置へ移動
    func setCurrent(_ currentTime: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = max(min(currentTime, player.duration), 0)
    }

    // プログレスを通知
    func updateNotification() {
        guard let player = audioPlayer else { return }
        // let progress = player.currentTime / player.duration
        // let percent = Int(progress * 100)
        // let remainingTime = Int(player.duration - player.currentTime)
        // Com.XLOG("AudioPlayer-再生進捗: \(percent)% - 残り: \(remainingTime)秒")
        if let item = currentItem {
            playerProgress.onNext(
                PlProgress(id: item.uuid,
                           currentTime: Int(player.currentTime),
                           duration: Int(player.duration)))
        }
        // ロック画面への表示
        if let item = self.currentItem {
            updateNowPlayingInfo(
                title: item.title,
                artist: item.pfm,
                duration: audioPlayer?.duration ?? 0,
                artworkImage: currentItemImage
            )
        }
    }

    // プログレス通知用タイマー
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNotification()
        }
    }

    // 再生完了（終了時にシステムが呼び出す）
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Com.XLOG("AP-再生完了[\(currentItem?.title ?? "none")]")
        progressTimer?.invalidate()
        isPlaying.accept(false)
        if let item = currentItem {
            // 完了の通知
            self.playerFinished.onNext(item.uuid)
        }
        self.isActive.accept(false)
        self.currentItem = nil
        self.currentItemImage = nil
        // ロック画面の情報を消す
        wipeNowPlayingInfo()
    }
    
    // 強制再生終了
    func audioPlayerForceStop() {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            audioPlayerDidFinishPlaying(player, successfully: false)
        } else if let player = audioPlayer {
            audioPlayerDidFinishPlaying(player, successfully: false)
        }
    }
}

// MARK: - イヤホンからの制御とイヤホンの取り外し監視

extension AudioPlayerManager {
    // イヤフォンからのコントロール（実機でテスト）
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            self.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            self.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            if let player = self.audioPlayer, player.isPlaying {
                self.pause()
            } else {
                self.resume()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            self.forward10Seconds()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            self.rewind10Seconds()
            return .success
        }
    }
    
    // イヤフォンが外れた時の停止処理（実機でテスト）
    func setupAudioRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        if reason == .oldDeviceUnavailable {
            Com.XLOG("イヤホンが外れたので再生を一時停止")
            pause()
        }
    }

}

// MARK: - ロック画面に再生コントロール表示

extension AudioPlayerManager {
    
    // アートワークイメージ（キャッシュ）の取得
    func getArtworkImage(imgUrl: String?) -> UIImage? {
        var image: UIImage? = nil
        if !imgUrl.isNilOrEmpty {
            let fileName = Com.getFileNameWithExtension(url: imgUrl!)
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let coverImageFile = cacheDir.appendingPathComponent(fileName)
            if let data = try? Data(contentsOf: coverImageFile) {
                image = UIImage(data: data)
            }
        }
        if image == nil, let baseImage = UIImage(named: "img_radio")?.withRenderingMode(.alwaysOriginal) {
            image = baseImage.tint(.systemOrange)
        }
        return image
    }
    
    // ロック画面の更新
    func updateNowPlayingInfo(title: String, artist: String, duration: TimeInterval, artworkImage: UIImage?) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: AudioPlayerManager.shared.audioPlayer?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: AudioPlayerManager.shared.audioPlayer?.isPlaying == true ? 1.0 : 0.0
        ]
        if let image = artworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // ロック画面から情報をワイプ
    func wipeNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
}

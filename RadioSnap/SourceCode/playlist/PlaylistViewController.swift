//
//  PlaylistViewController.swift
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

protocol PlaylistMenuViewControllerDelegate {
    func deleteItem(uuid: String)
    func shareItem(uuid: String)
}

class PlaylistViewController: ModalViewController {
    
    var delegate: PlaylistViewControllerDelegate? = nil
    let audioPlayer = AudioPlayerManager.shared
    let watchSessionHandler = WatchSessionHandler.shared    // [Watch]

    private let presenter = PlaylistPresenter()
    private var mainView: PlaylistView!
    lazy var imageDownloader = appDelegate.getImageDownloader()
    private let customTransitioningDelegate = CustomTransitioningDelegate()
    
    // 削除したかどうか
    private var isRemoved = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mainView = self.view as? PlaylistView
        mainView.viewController = self
        
        // オブザーバー登録
        setupObservers()
        setupObserversForPlayer()
        // 初期設定
        setup()
        // コレクションデータを表示
        reloadCardData()
        // プレイコントロールの再表示（一度画面を閉じて、再表示された場合）
        if audioPlayer.isActive.value, let playingItem = audioPlayer.currentItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // コントローラの表示を回復
                let isPlaying =  self.audioPlayer.isPlaying.value
                self.mainView.setInfomation(item: playingItem)
                self.mainView.moveBottomFrameViewUp()
                self.mainView.changePlayPauseButton(isPlaying: isPlaying)
                if !isPlaying {
                    // 停止している場合は１度プログレス通知を送って表示を回復
                    self.audioPlayer.updateNotification()
                }
            }
        }
    }
    
    // 初期セットアップ
    private func setup() {
        // 再生済みをチェック
        presenter.checkPlayedCount()
    }
    
    override func goBack() {
        delegate?.finished(isRemoved: isRemoved)
        super.goBack()
    }
    
    // オブザーバーの登録
    private func setupObservers() {
        
        // 戻るボタン
        mainView.leftButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.goBack()
            })
            .disposed(by: disposeBag)
        
        // 再生終了一括削除ボタン
        mainView.rightButton1.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.showRemovePlayed()
            })
            .disposed(by: disposeBag)
        
        // ソート選択ボタン
        mainView.rightButton2.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.selectSortPattern()
            })
            .disposed(by: disposeBag)

        // プレイヤーのActiveチェック
        audioPlayer.isActive.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] on in
                if on {
                    mainView.moveBottomFrameViewUp()
                } else {
                    mainView.moveBottomFrameViewDown()
                }
             })
            .disposed(by: disposeBag)
        
        // [Watch] ウォッチからの通知
        watchSessionHandler.watchCommandNotification.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] command in
                Com.XLOG("ウォッチからの通知:\(command)")
                mainView.updateInfomation(command)
             })
            .disposed(by: disposeBag)
        
        // 再生済み削除ボタンの有効無効（複合条件の完了チェック）
        Observable.combineLatest(audioPlayer.isPlaying, presenter.playedCount)
            .map { isPlaying, playedCount in
                return !isPlaying && playedCount != 0
            }
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] possible in
                Com.XLOG("再生済み削除ボタン:\(possible)")
                self?.mainView.rightButton1.isHidden = !possible
            })
            .disposed(by: disposeBag)
        
        // リフレッシュコントローラー
        mainView.refreshControl.rx.controlEvent(.valueChanged).asObservable()
            .map({ () -> Bool in self.mainView.refreshControl.isRefreshing })
            .subscribe(onNext: { [unowned self] on in
                Com.XLOG("refreshControl: [\(on)]")
                self.reloadCardData()
                self.mainView.refreshControl.endRefreshing()
            })
            .disposed(by: disposeBag)
        
        // コンテンツの数を監視
        presenter.contentCount.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] count in
                self.mainView.bImage.isHidden = count != 0
             })
            .disposed(by: disposeBag)
        
        // テーブルビューアイテムのバインド設定（subscribe）
        presenter.dataSource = RxTableViewSectionedReloadDataSource<SectionOfPlaylistData>(
            configureCell: { [unowned self] (dataSource, tableView, indexPath, item) in
                let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCard", for: indexPath)
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
    
    // リロードカードデータ
    private func reloadCardData() {
        Com.XLOG("カードリストリロード")
        presenter.loadItems() { count in
            Com.XLOG("リロード結果: \(count)件")
        }
    }
    
    // ソート選択ボタンをタップ
    private func selectSortPattern() {
        let currentIndex = presenter.downloadDataSortPattern
        PlaylistSortPopup.show(from: self, selectedIndex: currentIndex) { index, patan in
            Com.XLOG("選択したソート: \(patan)（インデックス: \(index)）")
            self.presenter.downloadDataSortPattern = index
            self.reloadCardData()
        }
    }
    
    // 再生終了一括削除ボタンをタップ
    private func showRemovePlayed() {
        SimplePopup.showAlert(
            on: self.view,
            title: "確認",
            message: "再生済みの番組を全て削除しますか？",
            confirmTitle: "はい",
            cancelTitle: "いいえ",
            onConfirm: { _ in
                self.presenter.removePlayed()
                self.reloadCardData()
                self.isRemoved = true
            }
        )
    }
    
    // セルのプレイボタンをタップ
    func cellPlayButtonTaped(index: Int, item: Download) {
        if let stationId = item.stationId, let startDt = item.startDt {
            let downloader = RadikoDownloader.shared
            let fileName = downloader.makeDlFileName(stationId: stationId, startDt: startDt)
            if let audioUrl = downloader.getAudioFileUri(fileName) {
                let downloadItem = DownloadItem.from(download: item)
                Com.XLOG("再生開始[\(downloadItem.uuid)]: \(item.title ?? "none") file=\(fileName)")
                Com.XLOG("再生位置[\(downloadItem.playbackSec)/\(downloadItem.duration)] played=\(downloadItem.played)")
                audioPlayer.playAudio(with: audioUrl, item: downloadItem)
                // プレイマークを更新するためリロード
                mainView.tableView.reloadData()
                // プログレスを設定
                let progress = PlProgress(id:downloadItem.uuid, currentTime: downloadItem.playbackSec, duration: downloadItem.duration)
                mainView.updatePlayingTime(progress: progress)
                // タイトルを設定
                mainView.setInfomation(item: downloadItem)
                return
            }
        }
        Com.XLOG("再生開始エラー: \(item.title ?? "none")")
    }
    
    // セルのメニューボタンをタップ
    func cellMenuButtonTaped(index: Int, item: Download) {
        Com.XLOG("カードのメニューボタンをタップ[\(index)]: \(item.title ?? "none")")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let modalVC = storyboard.instantiateViewController(withIdentifier: "PlaylistMenu") as? PlaylistMenuViewController else {
            Com.XLOG("PlaylistMenu のインスタンス化に失敗")
            return
        }
        modalVC.delegate = self
        modalVC.item = DownloadItem.from(download: item)
        modalVC.modalPresentationStyle = .custom
        modalVC.transitioningDelegate = customTransitioningDelegate
        present(modalVC, animated: true, completion: nil)
    }
}

// MARK: - プレイヤーのコントロール関連

extension PlaylistViewController {
    
    private func setupObserversForPlayer() {
        
        // 再生中チェック
        audioPlayer.isPlaying.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] playing in
                mainView.changePlayPauseButton(isPlaying: playing)
             })
            .disposed(by: disposeBag)
        
        // 再生中のプログレス（値に変化があった場合のみ処理）
        Observable.combineLatest(
            audioPlayer.playerProgress.asObservable().distinctUntilChanged(),
            presenter.isLoading.asObservable() )
            .filter { _, isLoading in !isLoading }
            .map { progress, _ in progress }
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] progress in
                if !audioPlayer.isActive.value { return }
                // 再生時間とスライダーの更新
                mainView.updatePlayingTime(progress: progress)
                // 再生次回をDBに書き込み
                presenter.updatePlayingTime(progress: progress)
                // セルの進捗情報（％と"played"）をダイレクト更新（ちらつき防止のため）
                let index = presenter.findIndexByCardID(uuid: progress.id)
                if index != -1 {
                    let indexPath = IndexPath(row: index, section: 0)
                    if let cell = mainView.tableView.cellForRow(at: indexPath) as? PlaylistTableViewCell {
                        if progress.duration > 0 {
                            let progress = Double(progress.currentTime) / Double(progress.duration)
                            let percent = Int(progress * 100)
                            cell.statusLabel.text = "\(percent)%"
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
        
        // 再生完了の通知
        audioPlayer.playerFinished.asObservable()
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] uuid in
                Com.XLOG("再生完了[\(uuid)]")
                // 再生済みのDB書き込み
                presenter.updatePlayed(uuid: uuid)
                // セルの更新
                let index = presenter.findIndexByCardID(uuid: uuid)
                if index != -1 {
                    let indexPath = IndexPath(row: index, section: 0)
                    mainView.tableView.reloadRows(at: [indexPath], with: .automatic)
                }
             })
            .disposed(by: disposeBag)
        
        // 巻き戻しボタン
        mainView.ctrlRewindButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.rewindSound()
            })
            .disposed(by: disposeBag)
        
        // 再生・停止ボタン
        mainView.ctrlPlayButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                if audioPlayer.isPlaying.value {
                    self.pauseSound()
                    // 再生済みをチェック（再生済みを再生している場合があるので）
                    presenter.checkPlayedCount()
                }
                else {
                    self.resumeSound()
                }
            })
            .disposed(by: disposeBag)
        
        // 早送りしボタン
        mainView.ctrlForwardButton.rx.tap
            .subscribe(onNext: { [unowned self] in
                self.forwardSound()
            })
            .disposed(by: disposeBag)
        
        // スライダーをタップし始めたとき
        mainView.plSlider.rx.controlEvent(.touchDown)
            .subscribe(onNext: { [unowned self] in
                // タップ開始時の処理
                presenter.isLoading.onNext(true)
            })
            .disposed(by: disposeBag)

        // スライダーを離したとき（指を離した場所がスライダー内外どちらでも）
        mainView.plSlider.rx.controlEvent([.touchUpInside, .touchUpOutside])
            .subscribe(onNext: { [unowned self] in
                // タップ終了時の処理
                changedSeekBar(mainView.plSlider.value)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // 遅延処理（Mainスレッド）
                    self.presenter.isLoading.onNext(false)
                }
            })
            .disposed(by: disposeBag)
    }
    
    // 巻き戻しボタンタップ
    private func rewindSound() {
        Com.XLOG("巻き戻し")
        audioPlayer.rewind10Seconds()
    }
    
    // 停止ボタンタップ
    private func pauseSound() {
        Com.XLOG("停止")
        audioPlayer.pause()
    }
    
    // 再生ボタンタップ
    private func resumeSound() {
        Com.XLOG("再生")
        audioPlayer.resume()
    }
    
    // 早送りボタンタップ
    private func forwardSound() {
        Com.XLOG("早送り")
        audioPlayer.forward10Seconds()
    }
    
    // シークバー（スライダー）の変更通知処理
    private func changedSeekBar(_ value: Float) {
        Com.XLOG("シーク位置変更: \(value)")
        audioPlayer.setCurrent(Double(value))
        if !audioPlayer.isPlaying.value {
            // 停止中は戻ってしまうので、再生している
            audioPlayer.resume()
        }
    }
}

// MARK: - MainCardMenuViewControllerDelegate

extension PlaylistViewController: PlaylistMenuViewControllerDelegate {
    // カード削除通知
    func deleteItem(uuid: String) {
        let index = presenter.findIndexByCardID(uuid: uuid)
        Com.XLOG("DLカード削除通知: uuid=\(uuid) index=\(index)")
        if index != -1 {
            _ = presenter.removeData(index: index)
            isRemoved = true
        }
    }
    // カード共有通知
    func shareItem(uuid: String) {
        Com.XLOG("DLカード共有通知: uuid=\(uuid)")
        presenter.contentsShare(viewController: self, uudi: uuid)
    }
}



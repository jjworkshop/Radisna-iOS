//
//  SettingTableHolder.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/09.
//

/*
 このクラスのベースは見ての通り、UITableViewController
 このUITableViewControllerは、SettingsViewControllerの中にあるContainerViewのコンテンツとなっている
 そのコンテンツのUIパーツへのアクセスするためのホールダークラスとして利用している
 なので、このViewControllerはViewControllerそのものの機能としてはたいしたことをしていない
 位置づけとしては、他のビューコントローラーのMainView と同じになる
 */

import UIKit
import RxSwift

class SettingTableHolder: UITableViewController {
    private let sectionHeaderHight: CGFloat = 40
    let sectionFooterHeight: CGFloat = 30
    
    @IBOutlet weak var clearCacheBtn: UIButton!
    @IBOutlet weak var startModeSwitch: UISwitch!
    @IBOutlet weak var keepScreenSwitch: UISwitch!
    @IBOutlet weak var appearanceSegment: UISegmentedControl!
    @IBOutlet weak var logModeSwitch: UISwitch!
    @IBOutlet weak var logShareBtn: UIButton!
    @IBOutlet weak var newsInfoLabel: UILabel!
    @IBOutlet weak var newsInfoLabel_R: UILabel!
    @IBOutlet weak var appVersionLabel: UILabel!
    @IBOutlet weak var licenseKeyLabel: UILabel!
    
    // セルタップのオブザーバル
    let celTaped: PublishSubject<IndexPath> = PublishSubject()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // セクションヘッダ＆フッタ（最後の）の高さを変更
        tableView.sectionHeaderHeight = sectionHeaderHight
        tableView.sectionFooterHeight = sectionFooterHeight
                
        // UIコントロールのカラー変更
        startModeSwitch.onTintColor = UIColor.systemOrange
        keepScreenSwitch.onTintColor = UIColor.systemOrange
        logModeSwitch.onTintColor = UIColor.systemOrange
        appearanceSegment.setTitleTextAttributes(
            [.foregroundColor: UIColor.systemOrange], for: .selected) // 選択時の文字色

        // テーブルビューの不要な横線を消す
        tableView.tableFooterView = UIView(frame: .zero)
        // テーブルビューの下部にパディングを設定
        let insets: UIEdgeInsets = tableView.contentInset
        tableView.contentInset = UIEdgeInsets(
            top: insets.top, left: insets.left,
            bottom: insets.bottom + sectionFooterHeight, right: insets.right)
    }
    
    // ニュースありの場合のlabel点滅
    func newsInfoLabel(appNewsExist: Bool) {
        if appNewsExist {
            newsInfoLabel.textColor = UIColor.systemOrange
            newsInfoLabel.text = "☆アプリの最新ニュースがあります…"
            newsInfoLabel_R.text = "←"
            // 点滅アニメーション
            UIView.animate(withDuration: 2.0,
                           delay: 0.0,
                           options: .repeat,
                           animations: {
                            self.newsInfoLabel_R.alpha = 0.0
            }) { (_) in
                self.newsInfoLabel_R.alpha = 1.0
            }
        }
        else {
            newsInfoLabel.textColor = UIColor.label
            newsInfoLabel.text = "アプリのニュース…"
            newsInfoLabel_R.text = ""
        }
    }
    
    // MARK: - UITableViewDelegate
    
    // ヘッダのカスタマイズ
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: UIView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: sectionHeaderHight))
        headerView.backgroundColor = UIColor.systemGray6
        let label: UILabel = UILabel(frame: CGRect(x: 15, y: sectionHeaderHight - 20, width: tableView.frame.size.width, height: 16))
        label.textColor = UIColor.label
        label.font = UIFont.systemFont(ofSize: 15)
        switch (section) {
        case 0:
            label.text = "基本設定"
        default:
            label.text = "アプリケーションについて"
        }
        headerView.addSubview(label)
        return headerView
    }
        
    // セルがタップされた時の処理
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)    // 選択解除
        // イベントを送る
        celTaped.onNext(indexPath)
    }
}

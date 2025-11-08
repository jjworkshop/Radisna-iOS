//
//  AppCommon.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//  Copyright © 2018年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit

struct AppCom {

    // ユーザー設定値の各キー
    static let USER_DEFKEY_WAKEUP_CNT           = "WakeupCnt"
    static let USER_DEFKEY_SPECIAL_USER         = "SpecialUser"
    // 設定用の各キー
    static let USER_DEFKEY_APPEARANCE_MODE      = "Appearance"
    static let USER_DEFKEY_APP_NEWS_TIMESTUMP   = "AppNewsTS"

    // radikoのURL（getStationListAt.py で取得して保存）
    static var radikoUrl: String = ""
    
    // Region情報を保存
    // この値が null の場合は場所からの情報が拾えていない
    // StationLocalDB データは直近の情報を持つキャッシュとなってる
    static var region: Region? = nil

    // 設定なし文字列
    static public let none_text = "---"
    static public let na_text = "N/A"

    // 各定数
    static public let safearea_view_tag: Int = 9999 // iPhoneXのsafeareaにはめたViewのtag識別番号
    
#error("以下の行を参考に、自分のサーバのURLとAPI_PATHを設定してください。「domain」と「API_PATH」を修正しないとアプリは動作しません。修正済みでしたらこの行は削除下さい。")
    // TODO: 自分のサーバに設定を変更
    static public let domain = "https://hogehoge.com"
    static public let API_PATH = "\(domain)/API/"
     
    // PDFファイル
    /*
     PDFファイルの作成方法
     １，SVGイメージを探してダウンロード
         https://icooon-mono.com/
         https://www.iconfinder.com/
     ２，SVGファイルを正規化（640サイズのスクエアにして保存:Chromeで！）
        https://vectr.com/jjwhiro/b3sfKwwjJh
     ３，PDFにコンバート
        https://tools.pdf24.org/ja/svg-to-pdf
    */
    static public let pdf_arrow_back        = "pdf_arrow_back"
    static public let pdf_arrow_forward     = "pdf_arrow_forward"
    static public let pdf_arrow_left        = "pdf_arrow_left"
    static public let pdf_arrow_right       = "pdf_arrow_right"
    static public let pdf_calendar          = "pdf_calendar"
    static public let pdf_check             = "pdf_check"
    static public let pdf_circle_back       = "pdf_circle_back"
    static public let pdf_circle_down       = "pdf_circle_down"
    static public let pdf_circle_next       = "pdf_circle_next"
    static public let pdf_close             = "pdf_close"
    static public let pdf_ctl_forward       = "pdf_ctl_forward"
    static public let pdf_ctl_pause         = "pdf_ctl_pause"
    static public let pdf_ctl_play          = "pdf_ctl_play"
    static public let pdf_ctl_rewind        = "pdf_ctl_rewind"
    static public let pdf_detail            = "pdf_detail"
    static public let pdf_download          = "pdf_download"
    static public let pdf_edit              = "pdf_edit"
    static public let pdf_filter_off        = "pdf_filter_off"
    static public let pdf_gear              = "pdf_gear"
    static public let pdf_info              = "pdf_info"
    static public let pdf_link              = "pdf_link"
    static public let pdf_menu              = "pdf_menu"
    static public let pdf_na                = "pdf_na"
    static public let pdf_play_circle       = "pdf_play_circle"
    static public let pdf_playlist_delete   = "pdf_playlist_delete"
    static public let pdf_playlist          = "pdf_playlist"
    static public let pdf_plus              = "pdf_plus"
    static public let pdf_rec               = "pdf_rec2"
    static public let pdf_plus_circle       = "pdf_plus_circle"
    static public let pdf_reload            = "pdf_reload"
    static public let pdf_search            = "pdf_search"
    static public let pdf_sort              = "pdf_sort"
    static public let pdf_stop              = "pdf_stop2"
    static public let pdf_swap              = "pdf_swap"
    static public let pdf_trash             = "pdf_trash"


    // 文字列表示カラー設定
    static public let rgb_text_black:           String = "rgb_text_black"           // ブラックテキスト（darkカラーではホワイト）
    static public let rgb_text_white:           String = "rgb_text_white"           // ホワイトテキスト（darkカラーではブラック）
    static public let rgb_text_gray:            String = "rgb_text_gray"            // グレーテキスト（darkカラーではホワイトに近い）
    static public let rgb_text_disable:         String = "rgb_text_disable"         // ディセーブルテキスト
    static public let rgb_popup_bg:             String = "rgb_popup_bg"             // ポップアップダイアログBG
    static public let rgb_card:                 String = "rgb_card"                 // カードカラー
    static public let rgb_card_busy:            String = "rgb_card_busy"            // カードカラー（処理中）
    static public let rgb_card_err:             String = "rgb_card_err"             // カードカラー（エラー）
    
    // 放送局名を取得（StationDBの全放送局データより）
    static func getStationNameById(_ id: String) -> String {
        let sdb = StationDB.shared
        return sdb.getName(stationId: id)
    }
    // URLをBrowserで表示
    static func showSite(url: String) {
        let url = URL(string: url)!
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
        }
        else {
            Com.XLOG("Can not show support site!")
        }
    }
    
    // 起動時にダウンロード画面を表示するかどうか
    static private let downloadFirstKey = "downloadFirst"
    static var downloadFirst: Bool {
        get {
            if UserDefaults.standard.object(forKey: downloadFirstKey) == nil {
                return false // デフォルト値
            }
            return UserDefaults.standard.bool(forKey: downloadFirstKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: downloadFirstKey)
        }
    }

    // ダウンロード中に画面を暗くするかどうか
    static private let keepScreenOnKey = "keepScreenOn"
    static var keepScreenOn: Bool {
        get {
            if UserDefaults.standard.object(forKey: keepScreenOnKey) == nil {
                return true // デフォルト値
            }
            return UserDefaults.standard.bool(forKey: keepScreenOnKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: keepScreenOnKey)
        }
    }
    
    // ログを出力するかどうか
    static private let logModeKey = "logMode"
    static var logMode: Bool {
        get {
            if UserDefaults.standard.object(forKey: logModeKey) == nil {
                return false // デフォルト値
            }
            return UserDefaults.standard.bool(forKey: logModeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: logModeKey)
        }
    }
    
    // テキストのフォントサイズを幅により決定
    static func calcTextFontSize(_ title: String?, titleWidth: CGFloat) -> CGFloat {
        var fontSize: CGFloat = 16.0
        if let caption = title {
            while (true) {
                let size = caption.size(withAttributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: fontSize)])
                if (size.width > titleWidth && fontSize > 12.0)    {
                    fontSize -= 0.5
                }
                else {
                    break
                }
            }
        }
        return fontSize
    }
    
    // ライセンスキー
    static private let licenseKeyKey = "licenseKey"
    static var licenseKey: String? {
        get {
            return UserDefaults.standard.string(forKey: licenseKeyKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: licenseKeyKey)
        }
    }
    
}

// イベントを透過させるビュー
class TouchEventThroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}


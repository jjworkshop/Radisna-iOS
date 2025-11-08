//
//  EtcTools.swift
//  共通メソッド群
//
//  Created by Mitsuhiro Shirai on 2019/01/31.
//  Copyright © 2019年 Mitsuhiro Shirai. All rights reserved.
//

import UIKit
import AudioToolbox
import CoreLocation
import ZIPFoundation

/*
    頻繁につかう処理などをここに記述してある
    そのまま自分のprojectにファイル毎コピーすれば使える
 */

struct Com {

    static var logging: Bool = false
    
    // ログファイルをスレッドセーフにするため
    private static let logQueue = DispatchQueue(label: "com.yourapp.XLOGQueue")

    
    // デバッグプリント（ファイル書き込みスレッドセーフ版）
    // 使用例：XLOG(String(format: "abc - %d", 10))
    static func XLOG(_ obj: Any?,
                     file: String = #file,
                     function: String = #function,
                     line: Int = #line) {
        logQueue.async {
            if !Com.logging { return }
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let timeString = timeFormatter.string(from: Date())
            let timestamp = "[\(timeString)]- "

            let pathItem = String(file).components(separatedBy: "/")
            let fname = pathItem.last?.components(separatedBy: ".").first ?? "UnknownFile"
            let logMessage: String
            if let obj = obj {
                logMessage = "[\(fname):\(function) #\(line)] : \(obj)"
            } else {
                logMessage = "[\(fname):\(function) #\(line)]"
            }

            print(logMessage)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            let fileName = "log_\(dateString).txt"

            if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let logFileURL = cachesDir.appendingPathComponent(fileName)
                let logWithNewline = timestamp + logMessage + "\n"
                if let data = logWithNewline.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: logFileURL.path) {
                        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                            defer { fileHandle.closeFile() }
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                        }
                    } else {
                        try? data.write(to: logFileURL)
                    }
                }

                // 古いログファイルの削除（7日以上前）
                let fileManager = FileManager.default
                if let files = try? fileManager.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: [.creationDateKey], options: []) {
                    let calendar = Calendar.current
                    let now = Date()
                    for file in files {
                        if file.lastPathComponent.hasPrefix("log_") && file.pathExtension == "txt" {
                            if let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                               let creationDate = attrs.creationDate,
                               let diff = calendar.dateComponents([.day], from: creationDate, to: now).day,
                               diff >= 7 {
                                try? fileManager.removeItem(at: file)
                            }
                        }
                    }
                }
            }
        }
    }

    
    // ログを共有
    static func shareCompressedLogs(from viewController: UIViewController) {
        let fileManager = FileManager.default
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        // ログファイル一覧を取得
        let logFiles = (try? fileManager.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("log_") && $0.pathExtension == "txt" } ?? []

        guard !logFiles.isEmpty else {
            print("ログファイルが見つかりません")
            return
        }
        // ZIPファイルの保存先（例：logs_2025-05-22.zip）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let zipFileURL = cachesDir.appendingPathComponent("logs_\(dateString).zip")
        // 既存のZIPファイルがあれば削除
        try? fileManager.removeItem(at: zipFileURL)
        // ZIPファイル作成（非推奨でない初期化子を使用）
        do {
            let archive = try Archive(url: zipFileURL, accessMode: .create)
            for logFile in logFiles {
                try archive.addEntry(with: logFile.lastPathComponent, fileURL: logFile)
            }
            // 共有（AirDropなど）
            let activityVC = UIActivityViewController(activityItems: [zipFileURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            viewController.present(activityVC, animated: true)

        } catch {
            print("ZIPアーカイブの作成に失敗しました: \(error)")
        }
    }

    // スレッドチェック
    // UIの更新はメインスレッドでしか許されない
    // RXや通信ライブラリのコールバック処理で、どのスレッドで処理されているか解らない時はこれでチェック
    static func checkThread(tag: String) {
        if (Thread.isMainThread) {
            XLOG("\(tag): ここはメインスレッド内")
        }
        else {
            XLOG("\(tag): ここはワーカースレッド内")
        }
    }

    // ファーストレスポンダーを探す
    // 入力フィールド等で現在フォーカスのあるオブジェクトね
    static func findFirstResponder(_ view: UIView!) -> UIView? {
        if (view.isFirstResponder) {
            return view
        }
        for subView in view.subviews {
            if (subView.isFirstResponder) {
                return subView
            }
            let responder = findFirstResponder(subView)
            if (responder != nil) {
                return responder;
            }
        }
        return nil;
    }
    
    // 現在の最前面に表示中の画面クラスを取得する（上記は TabViewCやNavicationViewC には対応してないので）
    static func getTopViewController(vc: UIViewController? = getCurrentWindow()?.rootViewController) -> UIViewController? {
        if let navigationController = vc as? UINavigationController {
            return getTopViewController(vc: navigationController.visibleViewController)
        }
        if let tabBarController = vc as? UITabBarController,
            let selectedViewController = tabBarController.selectedViewController {
            return getTopViewController(vc: selectedViewController)
        }
        if let presentedViewController = vc?.presentedViewController {
            return getTopViewController(vc: presentedViewController)
        }
        return vc
    }
    
    // トースト表示
    // トーストは自動で消える画面下部に表示するメッセージ
    static func shortMessage(_ message: String, bottomMargin: CGFloat = 0.0) {
        if let controller = getTopViewController() {
            Toast.show(message: message, bottomMargin: bottomMargin, controller: controller)
        }
    }
    
    // ショートバイブレーション
    static func shortVibration() {
        AudioServicesPlaySystemSound( 1519 )
    }

    // デバイスのサイズ
    static func windowSize()  -> CGSize {
        // 画面がローテーションする場合は注意
        return UIScreen.main.bounds.size
    }
    
    // pixelからpointに変換
    static func pix2Point(_ pix: CGFloat) -> Int {
        let screenScale = UIScreen.main.scale
        return Int(pix / screenScale)
    }
    
    // ナビゲーションバーの高さを取得（システムのデフォルトは 44）
    static func navigationBarHeight(_ viewController: UIViewController?) -> CGFloat {
        if (viewController == nil) {
            return 44
        }
        return viewController!.navigationController?.navigationBar.frame.size.height ?? 44
    }
    
    // 現在の　Windows を取得
    static func getCurrentWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.filter {$0.isKeyWindow}.first
        return window
    }
    
    // アピアランスを変更（0=システム設定、1=ライト、2=ダーク）
    static func changAppearanceMode(_ index: Int) {
        if let window = getCurrentWindow() {
            switch (index) {
            case 1:
                window.overrideUserInterfaceStyle = .light
            case 2:
                window.overrideUserInterfaceStyle = .dark
            default:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
    static func getAppearanceMode() -> UIUserInterfaceStyle {
        if let window = getCurrentWindow() {
            return window.overrideUserInterfaceStyle
        }
        return .unspecified
    }

    // ステータスバーの高さを取得（iOS15以上）
    static let statusBarHeight: CGFloat = {
        let window = getCurrentWindow()
        let height: CGFloat = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        if height == 0 {
            Com.XLOG("Couldn't get statusBarHeight, size was zero.")
        }
        return height
    }()
    
    // トップのセーフエリア（iPhoneX系のみ、それ以外はゼロ）を取得
    // 注意: viewWillLayoutSubviews が呼ばれるまでは値が取れない
    static let safeHightTop: CGFloat = {
        let window = getCurrentWindow()
        let height: CGFloat = window?.safeAreaInsets.top ?? 0
        return height
    }()

    // ボトムのセーフエリア（iPhoneX系のみ、それ以外はゼロ）を取得
    // 注意: viewWillLayoutSubviews が呼ばれるまでは値が取れない
    static let safeHightBottom: CGFloat = {
        let window = getCurrentWindow()
        let height: CGFloat = window?.safeAreaInsets.bottom ?? 0
        return height
    }()
        
    // 日本語環境か？
    static let isJapanese: Bool = {
        guard let prefLang = Locale.preferredLanguages.first else {
            return false
        }
        return prefLang.hasPrefix("ja")
    }()
    
    // ドキュメントパスを取得
    static func getDocumentPath() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    // URL表記のファイル名から、ファイル名（拡張子付き）で取り出す
    static func getFileNameWithExtension(url: String) -> String {
        return url.components(separatedBy: "/").last ?? url
    }

    // 日付フォーマット文字列をDateへ変換
    // format 例
    //  yyyy/MM/dd HH:mm
    static func dateFromString(string: String, format: String) -> Date? {
        let formatter: DateFormatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = format
        return formatter.date(from: string)
    }

    // 時間のみ取り出し（HH:mm）
    static func getHHMM_S(_ date: Date, isJP: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJP ? "ja_JP" : "en_US")
        formatter.dateFormat = isJP ? "HH:mm": "HH:mm"
        return formatter.string(from: date)
    }

    // 月日のみ取り出し（HH:mm）
    static func getMD_S(_ date: Date, isJP: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJP ? "ja_JP" : "en_US")
        formatter.dateFormat = isJP ? "M/d": "M/d"
        return formatter.string(from: date)
    }

    // ローカル日付フォーマット（yyyy/mm/dd）: DBへの保存形式
    static func getYYYYMMDD_S(_ date: Date, isJP: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJP ? "ja_JP" : "en_US")
        formatter.dateFormat = isJP ? "yyyy/MM/dd": "yyyy/MM/dd"
        return formatter.string(from: date)
    }
    
    // ローカル日付フォーマット（yyyy/mm/dd hh:mm）: DBへの保存形式
    static func getYYYYMMDDHHMM_S(_ date: Date, isJP: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJP ? "ja_JP" : "en_US")
        formatter.dateFormat = isJP ? "yyyy/MM/dd HH:mm": "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    // ローカル日付フォーマット（年月日、曜日、時分秒）: 主にデバッグ用
    static func getYYMMDDEEHHMMSS(_ date: Date, isJP: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJP ? "ja_JP" : "en_US")
        formatter.dateFormat = isJP ? "Y年M月d日(EE) HH:mm:ss": "EE, MMM d, Y HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // ローカル日付フォーマット（日、時）
    static func getDDHH(_ date: Date, isJP: Bool = true) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJP ? "ja_JP" : "en_US")
        formatter.dateFormat = isJP ? "d日 H時": "d, HH"
        return formatter.string(from: date)
    }

    // ローカル日付フォーマット（月日、曜日、時分）
    static func getMMDDEEHHMM(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJapanese ? "ja_JP" : "en_US")
        formatter.dateFormat = isJapanese ? "M月d日(EE) HH:mm": "EE, MMM d HH:mm"
        return formatter.string(from: date)
    }
    
    // ローカル日付フォーマット（月日、曜日）＆（時分）
    static func getMMDDEE_HHMM(_ date: Date) -> (String,String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJapanese ? "ja_JP" : "en_US")
        formatter.dateFormat = isJapanese ? "M月d日(EE)": "EE, MMM d"
        let mde = formatter.string(from: date)
        formatter.dateFormat = "HH:mm"
        return (mde, formatter.string(from: date))
    }
    static func getMMDDEE_HHMM_JP(_ date: Date) -> (String,String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(EE)"
        let mde = formatter.string(from: date)
        formatter.dateFormat = "HH:mm"
        return (mde, formatter.string(from: date))
    }
    
    // ローカル日付フォーマット（月日、曜日）
    static func getMMDDEE(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJapanese ? "ja_JP" : "en_US")
        formatter.dateFormat = isJapanese ? "M月d日(EE)": "EE, MMM d"
        return formatter.string(from: date)
    }
    static func getMMDDEE_JP(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(EE)"
        return formatter.string(from: date)
    }

    // ローカル日付フォーマット（年月日）
    static func getYYYYMMDD(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJapanese ? "ja_JP" : "en_US")
        formatter.dateFormat = isJapanese ? "Y年M月d日": "MMM d, Y"
        return formatter.string(from: date)
    }
    
    // ローカル日付フォーマット（年月）
    static func getYYYYMM(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isJapanese ? "ja_JP" : "en_US")
        formatter.dateFormat = isJapanese ? "Y年M月": "MMM Y"
        return formatter.string(from: date)
    }
    
    // ローカル日付フォーマット（yyyyMMdd）: らじすな特有
    static func toYMD(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
    // ローカル日付フォーマット（yyyyMMdd）: らじすな特有
    static func toMdE(_ date: Date) -> String {
        return getMMDDEE_JP(date)
    }
    // ローカル日付フォーマット（yyyyMMdd）: らじすな特有
    static func toYMDHMS(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: date)
    }
    
    // 時分の文字列を分に
    static func hhmmToMinute(_ hhmm: String?) -> Int? {
        if let hhmm = hhmm {
            let parts = hhmm.components(separatedBy: ":").map{ $0.trimmingCharacters(in: .whitespaces) }
            if (parts.count == 2 && parts[0].isNumeric() && parts[1].isNumeric()) {
                return parts[0].toInt() * 60 + parts[1].toInt()
            }
        }
        return nil
    }
    
    // ２つの日付が同じ年月日かどうかチェック
    static func isSameDay(day1: Date, day2: Date) -> Bool {
        let calendar = Calendar.current
        let y1 = calendar.component(.year, from: day1)
        let m1 = calendar.component(.month, from: day1)
        let d1 = calendar.component(.day, from: day1)
        let y2 = calendar.component(.year, from: day2)
        let m2 = calendar.component(.month, from: day2)
        let d2 = calendar.component(.day, from: day2)
        return (y1 == y2 && m1 == m2 && d1 == d2)
    }

    // レーベンシュタイン距離計算（２つの文字のマッチ率計算用）
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m {
            for j in 0...n {
                if i == 0 {
                    dp[i][j] = j
                } else if j == 0 {
                    dp[i][j] = i
                } else {
                    dp[i][j] = min(
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1,
                        dp[i - 1][j - 1] + (s1Array[i - 1] == s2Array[j - 1] ? 0 : 1)
                    )
                }
            }
        }
        return dp[m][n]
    }

    // ２つの文字のマッチ率計算（％）
    static func matchPercentage(_ s1: String, _ s2: String) -> Double {
        let maxLength = max(s1.count, s2.count)
        if maxLength == 0 { return 100.0 }
        let distance = levenshteinDistance(s1, s2)
        return (Double(maxLength - distance) / Double(maxLength)) * 100.0
    }
        
}

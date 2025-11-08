//
//  AppDelegate.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//

import UIKit
import CoreData
import AlamofireImage

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var isFirstWakeUp: Bool = false             // 初回起動
    static public let appVerKey = "APP_VER"
    var appNewsSiteDate: String = ""            // アプリニュースの最新投稿日時
    var appUUID: String = ""                    // アプリの固有ID
    
    var imageDownloader: ImageDownloader? = nil
    
    // [Watch] セションハンドラをインスタンス化
    // セッションは WatchSessionHandler 内で activate 済み
    var watchSessionHandler = WatchSessionHandler.shared
    
    // プレイヤーをインスタンス化（ [Watch] からダイレクトアクセスがあるためここでインスタンス化）
    var audioPlayerManager = AudioPlayerManager.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // ログ出力の判定
        Com.logging = AppCom.logMode
#if DEBUG
        // DEBUGビルド時は常にログを出力
        // Com.logging = true
#endif
        
        // アプリの固有ID
        let ud = UserDefaults.standard
        if ud.object(forKey: "AppUUID") == nil {
            appUUID = UUID().uuidString
            ud.set(appUUID, forKey: "AppUUID")
        }
        else {
            appUUID = ud.string(forKey: "AppUUID") ?? UUID().uuidString
        }
        Com.XLOG("🍎:\(appUUID)")

        // キャッシュ等のデータをFinderで確認のため、documentパスをログに表示
        Com.XLOG("🗂️:\n\(Com.getDocumentPath())")
                
        // Errorトレース（エラー発生時の詳細を表示する）
        NSSetUncaughtExceptionHandler { exception in
            Com.XLOG("☠️: \(exception)")
            Com.XLOG(exception.callStackSymbols)
        }
        
        /*
         XCODEで余計なログを非表示にするには
         Product -> Scheme -> Edit Scheme... を選択
         Environment Variables に OS_ACTIVITY_MODE = disable と値を追加
        */
        
        // 初回起動＆アプリバージョンチェック
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        if (ud.object(forKey: AppDelegate.appVerKey) != nil) {
            let version = ud.string(forKey: AppDelegate.appVerKey)
            Com.XLOG("UserDefaults save ver: \(version!)")
            if (appVersion != version) {
                // バーションアップに伴う処理が必要ならここでチェックして処理する
                //（現在特に処理はなし）
                // 現在のアプリバージョンを保存
                ud.set(appVersion, forKey: AppDelegate.appVerKey)
            }
        }
        else {
            // 初回起動
            isFirstWakeUp = true
            ud.set(appVersion, forKey: AppDelegate.appVerKey)
            // 初回起動時に必要な処理（なにかあれば）
        }
        
        return true
    }
    
    // MARK: - Image cache control
    
    // イメージダウンローダーの取得
    func getImageDownloader(diskSpaceMB: Int = 300) -> ImageDownloader? {
        if (imageDownloader == nil) {
            // 未設定の場合はダウンローダを作成
            // memoryCapacityはゼロに設定しないと、ImageRequestCacheと２重にキャッシュされるらしい（AlamofireImage Document said）
            let diskCapacity = diskSpaceMB * 1024 * 1024        // ディスクキャッシュ（defaultは 300 MB)
            let cacheCapacity: UInt64 = 200 * 1024 * 1024       // メモリキャッシュの上限(defaultは 100 MB)
            let cachePurgeCapacity: UInt64 = 120 * 1024 * 1024  // メモリキャッシュの上限を超えたとき、古いキャッシュを削除した残りのキャッシュサイズ(defaultは 60 MB)
            let diskCache = URLCache(memoryCapacity: 0, diskCapacity: diskCapacity, diskPath: "image_disk_cache")
            let configuration = URLSessionConfiguration.default
            configuration.urlCache = diskCache
            configuration.requestCachePolicy = .returnCacheDataElseLoad // キャッシュが無い場合のみ通信
            let imageCache: ImageRequestCache = AutoPurgingImageCache(memoryCapacity: cacheCapacity, preferredMemoryUsageAfterPurge: cachePurgeCapacity)
            imageDownloader = ImageDownloader(configuration: configuration, imageCache: imageCache)
            Com.XLOG("イメージダウンローダキャッシュ DISK:\(diskSpaceMB)MB MEMORY:\(cacheCapacity/(1024*1024))MB After PURGE:\(cachePurgeCapacity/(1024*1024))MB")
        }
        return imageDownloader
    }
    
    // イメージキャッシュ削除
    func removeImageCache() {
        // イメージキャッシュを削除
        // removeAllCachedResponsesでサイズは減っているけど、実際にパスにあるキャッシュはPURGEされない… なんでじゃろ？
        // iOSのキャッシュ処理の挙動はいまいちわからん…
        Com.XLOG("イメージキャッシュクリア前: \(URLCache.shared.currentDiskUsage)")
        URLCache.shared.removeAllCachedResponses()
        // ImageUrlCache.removeAll(context)
        Com.XLOG("イメージキャッシュクリア完了: \(URLCache.shared.currentDiskUsage)")

    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    
    // MARK - Core date background access context
    
    // CoreDataのコンテキスト取得
    func getMoContext() -> NSManagedObjectContext {
        let mainContext: NSManagedObjectContext = persistentContainer.viewContext
        if (Thread.isMainThread) {
            // FG処理
            return mainContext
        }
        // BG処理
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "RadioSnap")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        // viewContext の自動マージ設定（AIの提案により追加）
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}


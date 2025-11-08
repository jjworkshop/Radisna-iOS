//
//  Download.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//

import Foundation
import CoreData

// ダウンロード予約アイテム
extension Download {

    // Download データの件数
    static func numberOfData(_ context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        do {
            return try context.count(for: fetchRequest)
        } catch {
            Com.XLOG("Error fetching count: \(error)")
            return 0
        }
    }

    // Download 存在チェック
    static func exist(_ context: NSManagedObjectContext, stationId: String, startDt: String) -> String? {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@ AND startDt == %@", stationId, startDt)
        do {
            return try context.fetch(fetchRequest).first?.uuid
        } catch {
            Com.XLOG("Error checking existence: \(error)")
            return nil
        }
    }

    // Download アイテム取得
    static func getItem(_ context: NSManagedObjectContext, uuid: String) -> Download? {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            Com.XLOG("Error fetching item: \(error)")
            return nil
        }
    }

    // Download データを削除
    static func remove(_ context: NSManagedObjectContext, uuid: String) {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            if let item = try context.fetch(fetchRequest).first {
                context.delete(item)
                try context.save()
            }
        } catch {
            Com.XLOG("Error removing item: \(error)")
        }
    }
    
    // Download データを全て削除
    static func removeAll(_ context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        do {
            let items = try context.fetch(fetchRequest)
            for item in items {
                context.delete(item)
            }
            try context.save()
        } catch {
            Com.XLOG("Error removing all items: \(error)")
        }
    }

    // Download データを保存
    static func storeData(_ context: NSManagedObjectContext, stationId: String, stationName: String, startDt: String, endDt: String, title: String, bcDate: String, bcTime: String, pfm: String, imgUrl: String, playbackSec: Int = 0, duration: Int = 0, played: Bool = false, copied: Bool = false) {
        let newDownload = Download(context: context)
        newDownload.uuid = UUID().uuidString
        newDownload.stationId = stationId
        newDownload.stationName = stationName
        newDownload.startDt = startDt
        newDownload.endDt = endDt
        newDownload.title = title
        newDownload.bcDate = bcDate
        newDownload.bcTime = bcTime
        newDownload.pfm = pfm
        newDownload.imgUrl = imgUrl
        newDownload.playbackSec = Int32(playbackSec)
        newDownload.duration = Int32(duration)
        newDownload.played = played
        newDownload.copied = copied
        do {
            try context.save()
        } catch {
            Com.XLOG("Error storing data: \(error)")
        }
    }
    
    // Download データを保存（Bookingから）
    static func storeDataByBooking(_ context: NSManagedObjectContext, booking: Booking) {
        let sdb = StationDB.shared
        let stationName = sdb.getName(stationId: booking.stationId ?? "")
        Download.storeData(
            context,
            stationId: booking.stationId ?? "",
            stationName: stationName,
            startDt: booking.startDt ?? "",
            endDt: booking.endDt ?? "",
            title: booking.title ?? "",
            bcDate: booking.bcDate ?? "",
            bcTime: booking.bcTime ?? "",
            pfm: booking.pfm ?? "",
            imgUrl: booking.imgUrl ?? ""
        )
    }

    // Download 全てのデータIDを取得
    static func getAll(_ context: NSManagedObjectContext, sortPattern: Int) -> [String] {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        let sortDescriptor: NSSortDescriptor
        switch sortPattern {
        case 0: sortDescriptor = NSSortDescriptor(key: "startDt", ascending: true)
        case 1: sortDescriptor = NSSortDescriptor(key: "startDt", ascending: false)
        case 2: sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        case 3: sortDescriptor = NSSortDescriptor(key: "title", ascending: false)
        case 4: sortDescriptor = NSSortDescriptor(key: "stationId", ascending: true)
        case 5: sortDescriptor = NSSortDescriptor(key: "stationId", ascending: false)
        default: sortDescriptor = NSSortDescriptor(key: "startDt", ascending: true)
        }
        fetchRequest.sortDescriptors = [sortDescriptor]
        do {
            let downloads = try context.fetch(fetchRequest)
            return downloads.compactMap { $0.uuid }
        } catch {
            Com.XLOG("Error fetching all items: \(error)")
            return []
        }
    }
    
    // 再生済みのデータ件数（再生済みで再生中は除く）
    static func numberOfPlayedData(_ context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "played == true AND playbackSec <= 0")
        do {
            return try context.count(for: fetchRequest)
        } catch {
            Com.XLOG("Error fetching played data count: \(error)")
            return 0
        }
    }
    
    // Download 再生済みの全てのデータIDを取得（再生済みで再生中は除く）
    static func getAllPlayed(_ context: NSManagedObjectContext) -> [String] {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "played == true AND playbackSec <= 0")
        do {
            let downloads = try context.fetch(fetchRequest)
            return downloads.compactMap { $0.uuid }
        } catch {
            Com.XLOG("Error fetching all items: \(error)")
            return []
        }
    }

    // Download プレイ時間を更新
    static func updatePlaybackSecs(_ context: NSManagedObjectContext, uuid: String, playbackSec: Int, duration: Int) -> Bool {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            if let item = try context.fetch(fetchRequest).first {
                item.playbackSec = Int32(playbackSec)
                item.duration = Int32(duration)
                try context.save()
                return true
            }
        } catch {
            Com.XLOG("Error updating playback seconds: \(error)")
        }
        return false
    }

    // Download 再生済を更新
    static func updateMediaStorePlayed(_ context: NSManagedObjectContext, uuid: String, played: Bool) -> Bool {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            if let item = try context.fetch(fetchRequest).first {
                item.played = played
                if played {
                    item.playbackSec = 0
                }
                try context.save()
                return true
            }
        } catch {
            Com.XLOG("Error updating media store played: \(error)")
        }
        return false
    }

    // Download メディアファイルコピー済を更新（未使用）
    static func updateMediaStoreCopied(_ context: NSManagedObjectContext, uuid: String, copied: Bool) -> Bool {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            if let item = try context.fetch(fetchRequest).first {
                item.copied = copied
                try context.save()
                return true
            }
        } catch {
            Com.XLOG("Error updating media store copied: \(error)")
        }
        return false
    }
}

// MARK: - [Watch] 用のデータ処理

extension Download {
    // Download 全データを辞書配列で取得（ソート対応）
    static func getProgramList(_ context: NSManagedObjectContext, sortPattern: Int = 0) -> [[String: String]] {
        let fetchRequest: NSFetchRequest<Download> = Download.fetchRequest()
        let sortDescriptor: NSSortDescriptor
        switch sortPattern {
        case 0: sortDescriptor = NSSortDescriptor(key: "startDt", ascending: true)
        case 1: sortDescriptor = NSSortDescriptor(key: "startDt", ascending: false)
        case 2: sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
        case 3: sortDescriptor = NSSortDescriptor(key: "title", ascending: false)
        case 4: sortDescriptor = NSSortDescriptor(key: "stationId", ascending: true)
        case 5: sortDescriptor = NSSortDescriptor(key: "stationId", ascending: false)
        default: sortDescriptor = NSSortDescriptor(key: "startDt", ascending: true)
        }
        fetchRequest.sortDescriptors = [sortDescriptor]
        do {
            let downloads = try context.fetch(fetchRequest)
            return downloads.compactMap { item in
                guard let uuid = item.uuid, let title = item.title else { return nil }
                return [
                    "uuid": uuid,
                    "title": title,
                    "played": item.played ? "true" : "false"
                ]
            }
        } catch {
            Com.XLOG("Error fetching program list: \(error)")
            return []
        }
    }
}

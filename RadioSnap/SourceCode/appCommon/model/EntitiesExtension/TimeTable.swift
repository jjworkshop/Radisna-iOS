//
//  TimeTable.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//

import Foundation
import CoreData

// タイムテーブルアイテム（キャッシュ扱いで、stationId毎に本日の取得データ１件のみ）
extension TimeTable {

    // TimeTable データの件数
    static func numberOfData(_ context: NSManagedObjectContext, stationId: String, todayStr: String) -> Int {
        let fetchRequest: NSFetchRequest<TimeTable> = TimeTable.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@ AND todayStr == %@", stationId, todayStr)
        do {
            return try context.count(for: fetchRequest)
        } catch {
            Com.XLOG("Error fetching count: \(error)")
            return 0
        }
    }

    // TimeTable アイテム取得
    static func getItem(_ context: NSManagedObjectContext, stationId: String, todayStr: String) -> TimeTable? {
        let fetchRequest: NSFetchRequest<TimeTable> = TimeTable.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@ AND todayStr == %@", stationId, todayStr)
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            Com.XLOG("Error fetching item: \(error)")
            return nil
        }
    }

    // TimeTable 指定放送局の全て削除
    static func removeStationAll(_ context: NSManagedObjectContext, stationId: String) {
        let fetchRequest: NSFetchRequest<TimeTable> = TimeTable.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@", stationId)
        do {
            let items = try context.fetch(fetchRequest)
            for item in items {
                context.delete(item)
            }
            try context.save()
        } catch {
            Com.XLOG("Error removing station items: \(error)")
        }
    }

    // TimeTable 全て削除
    static func removeAll(_ context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TimeTable.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            Com.XLOG("Error removing all items: \(error)")
        }
    }

    // TimeTable データを保存
    static func storeData(_ context: NSManagedObjectContext, stationId: String, todayStr: String, jsonStr: String) {
        let newTimeTable = TimeTable(context: context)
        newTimeTable.stationId = stationId
        newTimeTable.todayStr = todayStr
        newTimeTable.jsonStr = jsonStr
        do {
            try context.save()
        } catch {
            Com.XLOG("Error storing data: \(error)")
        }
    }
}

//
//  Booking.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//

import Foundation
import CoreData

// ダウンロード予約アイテム
extension Booking {

    // Booking データの件数
    static func numberOfData(_ context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        do {
            return try context.count(for: fetchRequest)
        } catch {
            Com.XLOG("Error fetching count: \(error)")
            return 0
        }
    }
    
    // Booking ダウンロード予約データの件数
    static func numberOfReservedData(_ context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %d", 7)
        do {
            return try context.count(for: fetchRequest)
        } catch {
            Com.XLOG("Error counting status 7: \(error)")
            return 0
        }
    }

    // Booking 存在チェック
    static func exist(_ context: NSManagedObjectContext, stationId: String, startDt: String) -> Bool {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@ AND startDt == %@", stationId, startDt)
        do {
            return try context.count(for: fetchRequest) > 0
        } catch {
            Com.XLOG("Error checking existence: \(error)")
            return false
        }
    }
    
    // Booking 存在チェック（uuid）
    static func exist(_ context: NSManagedObjectContext, uuid: String) -> Bool {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            return try context.count(for: fetchRequest) > 0
        } catch {
            Com.XLOG("Error checking existence: \(error)")
            return false
        }
    }

    // Booking アイテム取得
    static func getItem(_ context: NSManagedObjectContext, uuid: String) -> Booking? {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            Com.XLOG("Error fetching item: \(error)")
            return nil
        }
    }

    // Booking データを削除
    static func remove(_ context: NSManagedObjectContext, uuid: String) {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
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

    // Booking データをすべて削除
    static func removeAll(_ context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Booking.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
            //Com.XLOG("🫥removeAll complete: \(numberOfData(context))")
        } catch {
            Com.XLOG("Error removing all items: \(error)")
        }
    }

    // Booking データを新規に追加
    static func storeData(_ context: NSManagedObjectContext, item: BookingItem, uuid: String? = nil , seqNo: Int? = nil) -> String? {
        var result: String? = nil
        let newUuid = uuid == nil ? UUID().uuidString : uuid
        let newBooking = Booking(context: context)
        newBooking.uuid = newUuid
        newBooking.stationId = item.stationId
        newBooking.startDt = item.startDt
        newBooking.endDt = item.endDt
        newBooking.title = item.title
        newBooking.bcDate = item.bcDate
        newBooking.bcTime = item.bcTime
        newBooking.url = item.url
        newBooking.pfm = item.pfm
        newBooking.imgUrl = item.imgUrl
        newBooking.status = 0
        newBooking.seqNo = seqNo == nil ? Int32((getMaxSeqNo(context) + 1)) : Int32(seqNo!)
        do {
            try context.save()
            //Com.XLOG("🫥storeData: \(newUuid!) - \(item.title)")
            result = newUuid
        } catch {
            Com.XLOG("Error storing data: \(error)")
        }
        return result
    }

    // seqNo の最大値を求める
    private static func getMaxSeqNo(_ context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "seqNo", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        do {
            if let maxBooking = try context.fetch(fetchRequest).first {
                return Int(maxBooking.seqNo)
            }
        } catch {
            Com.XLOG("Error fetching max seqNo: \(error)")
        }
        return 0
    }

    // Booking 全てのデータIDを取得
    static func getAll(_ context: NSManagedObjectContext) -> [String] {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "seqNo", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        do {
            let bookings = try context.fetch(fetchRequest)
            return bookings.compactMap { $0.uuid }
        } catch {
            Com.XLOG("Error fetching all items: \(error)")
            return []
        }
    }

    // Booking 指定ステータスのデータIDを全て取得
    static func getAllDesignated(_ context: NSManagedObjectContext, status: Int) -> [String] {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %d", status)
        let sortDescriptor = NSSortDescriptor(key: "seqNo", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        do {
            let bookings = try context.fetch(fetchRequest)
            return bookings.compactMap { $0.uuid }
        } catch {
            Com.XLOG("Error fetching status=7 items: \(error)")
            return []
        }
    }
    
    // Booking ステータスを更新
    static func updateStatus(_ context: NSManagedObjectContext, uuid: String, status: Int) -> Bool {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            if let item = try context.fetch(fetchRequest).first {
                item.status = Int32(status)
                try context.save()
                return true
            }
        } catch {
            Com.XLOG("Error updating status: \(error)")
        }
        return false
    }

    // Booking seqNoを更新
    static func updateSeqNo(_ context: NSManagedObjectContext, uuid: String, seqNo: Int) -> Bool {
        let fetchRequest: NSFetchRequest<Booking> = Booking.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
        do {
            if let item = try context.fetch(fetchRequest).first {
                item.seqNo = Int32(seqNo)
                try context.save()
                return true
            }
        } catch {
            Com.XLOG("Error updating seqNo: \(error)")
        }
        return false
    }
}


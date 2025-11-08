//
//  Booking+CoreDataProperties.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//
//

import Foundation
import CoreData


extension Booking {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Booking> {
        return NSFetchRequest<Booking>(entityName: "Booking")
    }

    @NSManaged public var bcDate: String?
    @NSManaged public var bcTime: String?
    @NSManaged public var endDt: String?
    @NSManaged public var imgUrl: String?
    @NSManaged public var pfm: String?
    @NSManaged public var seqNo: Int32
    @NSManaged public var startDt: String?
    @NSManaged public var stationId: String?
    @NSManaged public var status: Int32
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var uuid: String?

}

extension Booking : Identifiable {

}

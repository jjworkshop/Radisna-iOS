//
//  TimeTable+CoreDataProperties.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//
//

import Foundation
import CoreData


extension TimeTable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TimeTable> {
        return NSFetchRequest<TimeTable>(entityName: "TimeTable")
    }

    @NSManaged public var jsonStr: String?
    @NSManaged public var stationId: String?
    @NSManaged public var todayStr: String?

}

extension TimeTable : Identifiable {

}

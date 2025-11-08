//
//  Download+CoreDataProperties.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//
//

import Foundation
import CoreData


extension Download {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Download> {
        return NSFetchRequest<Download>(entityName: "Download")
    }

    @NSManaged public var bcDate: String?
    @NSManaged public var bcTime: String?
    @NSManaged public var copied: Bool
    @NSManaged public var duration: Int32
    @NSManaged public var imgUrl: String?
    @NSManaged public var pfm: String?
    @NSManaged public var playbackSec: Int32
    @NSManaged public var played: Bool
    @NSManaged public var startDt: String?
    @NSManaged public var stationId: String?
    @NSManaged public var stationName: String?
    @NSManaged public var title: String?
    @NSManaged public var uuid: String?

}

extension Download : Identifiable {

}

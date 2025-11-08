//
//  CoreDataManager.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/12.
//

import CoreData

// [Watch] コアデータアクセス用
class CoreDataManager {
    static let shared = CoreDataManager()
    let persistentContainer: NSPersistentContainer

    private init() {
        persistentContainer = NSPersistentContainer(name: "RadioSnap")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        }
    }
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}


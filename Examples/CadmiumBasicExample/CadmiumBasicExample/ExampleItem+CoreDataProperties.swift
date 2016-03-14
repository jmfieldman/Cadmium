//
//  ExampleItem+CoreDataProperties.swift
//  CadmiumBasicExample
//
//  Created by Jason Fieldman on 3/14/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension ExampleItem {

    @NSManaged var name: String?
    @NSManaged var numberTaps: Int32

}

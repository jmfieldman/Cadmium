//
//  TestItem.swift
//  Cadmium
//
//  Created by Jason Fieldman on 3/18/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation
import CoreData
import Cadmium

class TestItem : CdManagedObject {
    @NSManaged var id: Int
    @NSManaged var name: String
}
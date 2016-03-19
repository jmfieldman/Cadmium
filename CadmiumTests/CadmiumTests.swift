//
//  CadmiumTests.swift
//  CadmiumTests
//
//  Created by Jason Fieldman on 3/13/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import XCTest
import CoreData
@testable import Cadmium

class CadmiumTests: XCTestCase {
    
    let dispatchGroup = dispatch_group_create()
    let bgQueue       = dispatch_queue_create("CadmiumTests.backgroundQueue", nil)
    
    override func setUp() {
        super.setUp()
        self.cleanCd()
        self.initCd()
        self.initData()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testBasicQueries() {
        
        do {
            var objs = try Cd.objects(TestItem.self).filter("name = \"C\"").fetch()
            XCTAssertEqual(objs.count, 1, "Query string equals")
            
            objs = try Cd.objects(TestItem.self).filter("name < \"C\"").fetch()
            XCTAssertEqual(objs.count, 2, "Query string less-than")
            
            objs = try Cd.objects(TestItem.self).filter("id = 4").fetch()
            XCTAssertEqual(objs.count, 1, "Query int equals")
            
            objs = try Cd.objects(TestItem.self).filter("id < 4").fetch()
            XCTAssertEqual(objs.count, 3, "Query int equals")
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    func testSortingQueries() {
        
        do {
            var objs = try Cd.objects(TestItem.self).filter("id > %@ AND id < %@", 1, 5).sorted("id").fetch()
            XCTAssertEqual(objs.count, 3, "Query string equals")
            XCTAssertEqual(objs[0].id, 2, "Query sorting")
            XCTAssertEqual(objs[1].id, 3, "Query sorting")
            XCTAssertEqual(objs[2].id, 4, "Query sorting")
            
            objs = try Cd.objects(TestItem.self).filter("id > %@ AND id < %@", 1, 5).sorted("id", ascending: false).fetch()
            XCTAssertEqual(objs.count, 3, "Query string equals")
            XCTAssertEqual(objs[0].id, 4, "Query sorting")
            XCTAssertEqual(objs[1].id, 3, "Query sorting")
            XCTAssertEqual(objs[2].id, 2, "Query sorting")
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
        
    }
    
    func testBasicModification() {
        
        do {
            
            dispatch_group_enter(dispatchGroup)
            dispatch_async(bgQueue) {
                
                Cd.transactAndWait {
                    do {
                        let item = try Cd.objects(TestItem.self).filter("id = 1").fetchOne()
                        item!.name = "111"
                    } catch let error {
                        XCTFail("tx error: \(error)")
                    }
                }
                
                dispatch_group_leave(self.dispatchGroup)
            }
            dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER)
            
            let objs = try Cd.objects(TestItem.self).filter("id = 1").fetch()
            XCTAssertEqual(objs.count, 1, "Query string equals")
            XCTAssertEqual(objs[0].name, "111", "Query string equals")
            
            let obj = try Cd.objects(TestItem.self).filter("name = \"111\"").fetchOne()
            XCTAssertEqual(obj!.id, 1, "Query string equals")
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    func initData() {
        
        
        dispatch_group_enter(dispatchGroup)
        dispatch_async(bgQueue) {
            
            Cd.transactAndWait {
                do {
                    let items = try Cd.create(TestItem.self, count: 5)
                    
                    items[0].id     = 1
                    items[0].name   = "A"
                    items[1].id     = 2
                    items[1].name   = "B"
                    items[2].id     = 3
                    items[2].name   = "C"
                    items[3].id     = 4
                    items[3].name   = "D"
                    items[4].id     = 5
                    items[4].name   = "E"
                    
                } catch let error {
                    XCTFail("initData error: \(error)")
                }
            }
            
            dispatch_group_leave(self.dispatchGroup)
        }
        
        dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER)
    }
    
    func initCd() {
        do {
            try Cd.initWithSQLStore(inbundleID: "org.fieldman.CadmiumTests", momdName: "CadmiumTestModel", sqliteFilename: "test.sqlite")
        } catch let error {
            XCTFail("setup error: \(error)")
        }
    }
    
    func cleanCd() {
        let documentDirectories = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        let documentDirectory   = documentDirectories[documentDirectories.count - 1]
        
        do {
            for url in try NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentDirectory, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions(rawValue: 0)) {
                if url.description.rangeOfString("test.sqlite") != nil {
                    try NSFileManager.defaultManager().removeItemAtURL(url)
                }
            }
        } catch {}
    }
}

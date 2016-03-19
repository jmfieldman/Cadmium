//
//  CadmiumTests.swift
//  CadmiumTests
//
//  Copyright (c) 2016-Present Jason Fieldman - https://github.com/jmfieldman/Cadmium
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

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
    
    /*
     *  --------------------- Allowed Behaviors ----------------------
     */
    
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
    
    
    
    /*
     *  ----------------- Forbidden Behaviors ----------------------
     */
    
    func testForbidModificationOnMainThread() {
        
        do {
            let obj = try Cd.objects(TestItem.self).filter("name = \"C\"").fetchOne()!
            XCTAssertEqual(obj.id, 3, "Query string equals")
            
            let exception = catchException {
                obj.name = "Bob"
            }
            
            if (exception == nil) {
                XCTFail("should have failed with exception for modifying in main thread")
            }
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    /*
     *  ----------------- Testing Lifecycle --------------------
     */
    
    
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

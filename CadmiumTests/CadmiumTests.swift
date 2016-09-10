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
    
    let bgQueue       = DispatchQueue(label: "CadmiumTests.backgroundQueue", attributes: [])
    
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
            
            let dispatchGroup = DispatchGroup()
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    do {
                        let item = try Cd.objects(TestItem.self).filter("id = 1").fetchOne()
                        item!.name = "111"
                    } catch let error {
                        XCTFail("tx error: \(error)")
                    }
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            let objs = try Cd.objects(TestItem.self).filter("id = 1").fetch()
            XCTAssertEqual(objs.count, 1, "Query string equals")
            XCTAssertEqual(objs[0].name, "111", "Query string equals")
            
            let obj = try Cd.objects(TestItem.self).filter("name = \"111\"").fetchOne()
            XCTAssertEqual(obj!.id, 1, "Query string equals")
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    func testBasicCreate() {
        
        do {
            let dispatchGroup = DispatchGroup()
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    let obj = try! Cd.create(TestItem.self)
                    obj.name = "F"
                    obj.id   = 1000
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            let objs = try Cd.objects(TestItem.self).fetch()
            XCTAssertEqual(objs.count, 6, "Query string equals")
            
            let obj = try Cd.objects(TestItem.self).filter("name = \"F\"").fetchOne()
            XCTAssertEqual(obj!.id, 1000, "Query string equals")
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    func testBasicUseInCurrentContext() {
        
        do {
            
            var obj: TestItem!
            
            let dispatchGroup = DispatchGroup()
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    obj = try! Cd.create(TestItem.self)
                    obj.name = "F"
                    obj.id   = 1000
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            var objs = try Cd.objects(TestItem.self).filter("name = \"F\"").fetch()
            XCTAssertEqual(objs.count, 1, "Query string equals")
            
            obj = objs[0]
            
            objs = try Cd.objects(TestItem.self).filter("name = \"G\"").fetch()
            XCTAssertEqual(objs.count, 0, "Query string equals")
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    let obj2: TestItem = Cd.useInCurrentContext(obj)!
                    obj2.name = "G"
                    obj2.id   = 1000
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            objs = try Cd.objects(TestItem.self).fetch()
            XCTAssertEqual(objs.count, 6, "Query string equals")
            
            objs = try Cd.objects(TestItem.self).filter("name = \"G\"").fetch()
            XCTAssertEqual(objs.count, 1, "Query string equals")
            
            objs = try Cd.objects(TestItem.self).filter("name = \"F\"").fetch()
            XCTAssertEqual(objs.count, 0, "Query string equals")
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    func testMultiCreate() {
        
        do {
            
            let dispatchGroup = DispatchGroup()
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    for obj in try! Cd.create(TestItem.self, count: 10) {
                        obj.name = "B"
                    }
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            let objs = try Cd.objects(TestItem.self).fetch()
            XCTAssertEqual(objs.count, 15, "Query string equals")
            
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    
    func testBasicDictionary() {
        
        do {
            
            let dic = try Cd.objects(TestItem.self).fetchDictionaryArray()
            XCTAssertEqual(dic.count, 5, "Query size")
            
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
        
    }
    
    
    func testDictionaryExpressionGrouping() {
        
        do {
            
            let dispatchGroup = DispatchGroup()
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    var i = 1
                    for obj in try! Cd.create(TestItem.self, count: 10) {
                        obj.name = "TEST"
                        obj.id   = i
                        i += 1
                    }
                    
                    i = 1
                    for obj in try! Cd.create(TestItem.self, count: 10) {
                        obj.name = "TEST2"
                        obj.id   = i
                        i += 1
                    }
                }
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            let exception1 = catchException {
                _ = try? Cd.objects(TestItem.self).groupBy("name").fetchDictionaryArray()
            }
            
            if exception1 == nil {
                XCTFail("should have failed because of grouping without property naming")
            }
            
            let dicArray = try Cd.objects(TestItem.self)
                            .includeExpression("sum", resultType: .integer64AttributeType, withFormat: "@sum.id")
                            .includeExpression("count", resultType: .integer64AttributeType, withFormat: "name.@count")
                            .onlyProperties(["name", "sum", "count"])
                            .groupBy("name")
                            .fetchDictionaryArray()
            
            print("\(dicArray)")
            
            XCTAssertEqual(dicArray.count, 7, "Result size")
            
            var wasTested = 0
            for dic in dicArray {
                if dic["name"] as! String == "TEST" {
                    XCTAssertEqual(dic["sum"] as? Int ?? 0, 55, "sum difference")
                    XCTAssertEqual(dic["count"] as? Int ?? 0, 10, "count difference")
                    wasTested = 1
                }
                
                if dic["name"] as! String == "TEST2" {
                    XCTAssertEqual(dic["sum"] as? Int ?? 0, 55, "sum difference")
                }
            }
            
            XCTAssertEqual(wasTested, 1, "wasn't tested!")
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
        
    }
    
    
    func testBasicDelete() {
        
        do {
            
            let dispatchGroup = DispatchGroup()
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    Cd.delete(try! Cd.objects(TestItem.self).fetchOne()!)
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            let objs = try Cd.objects(TestItem.self).fetch()
            XCTAssertEqual(objs.count, 4, "Query string equals")
            
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    func testMultiDelete() {
        
        do {
            
            let dispatchGroup = DispatchGroup()
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    Cd.delete(try! Cd.objects(TestItem.self).fetch())
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            let objs = try Cd.objects(TestItem.self).fetch()
            XCTAssertEqual(objs.count, 0, "Query string equals")
            
            
        } catch let error {
            XCTFail("query error: \(error)")
        }
    }
    
    func testCreateTransientMainInsertLater() {
        
        do {
            
            let dispatchGroup = DispatchGroup()
            
            let obj = try! Cd.create(TestItem.self, transient: true)
            obj.name = "asdf"
            obj.id   = 1000
            
            
            bgQueue.async(group: dispatchGroup) {
                
                Cd.transactAndWait {
                    Cd.insert(obj)
                }
                
                
            }
            dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            
            let objs = try Cd.objects(TestItem.self).fetch()
            XCTAssertEqual(objs.count, 6, "Query string equals")
            
            
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
    
    func testForbidModificationInOtherTx() {
        
        let dispatchGroup = DispatchGroup()
        
        
        bgQueue.async(group: dispatchGroup) {
        
            var obj: TestItem!
            
            Cd.transactAndWait {
                obj = try! Cd.create(TestItem.self)
                obj.name = "Bob"
            }
            
            Cd.transactAndWait {
                Cd.cancelImplicitCommit()
                if catchException({                    
                    obj.name = "B"                    
                }) == nil {
                    XCTFail("should have failed with exception for modifying in main thread")
                }
            }
            
            
        }
        
        dispatchGroup.wait(timeout: DispatchTime.distantFuture)
    }
    
    func testForbidReusingTransient() {
        
        let dispatchGroup = DispatchGroup()
        
        
        bgQueue.async(group: dispatchGroup) {
            
            var obj: TestItem!
            
            Cd.transactAndWait {
                obj = try! Cd.create(TestItem.self, transient: true)
                obj.name = "Bob"
            }
            
            Cd.transactAndWait {
                if catchException({
                    obj = Cd.useInCurrentContext(obj)
                }) == nil {
                    XCTFail("should have failed with exception for using transient")
                }
            }
            
            
        }
        
        dispatchGroup.wait(timeout: DispatchTime.distantFuture)
    }
    
    func testForbidCreateMain() {
        
        if catchException({
            let _ = try! Cd.create(TestItem.self)
        }) == nil {
            XCTFail("should have failed with exception for creating non-transient on main")
        }
        
    }
        
    func testForbidDeleteMain() {
        
        let obj = try! Cd.objects(TestItem.self).fetchOne()!
        
        if catchException({
            Cd.delete(obj)
        }) == nil {
            XCTFail("should have failed with exception for creating non-transient on main")
        }
        
    }
    
    func helperRunParallelInc(_ maxMillionths: Int, forcedSerial: Bool?, onQueue: DispatchQueue? = nil) -> [Int] {
        
        var result: [Int] = []
        var lock = os_unfair_lock()
        
        let queue = DispatchQueue(label: "parallel", attributes: DispatchQueue.Attributes.concurrent)
        let group = DispatchGroup()
        
        for _ in 0 ..< 25 {
            
            for _ in 0 ..< 40 {
                queue.async(group: group) {
                    
                    Cd.transactAndWait(serial: forcedSerial, on: onQueue) {
                        if let obj = try! Cd.objects(TestItem.self).filter("name = %@", "A").fetchOne() {
                            
                            let delayTime = Double(arc4random_uniform(UInt32(maxMillionths))) / 1000000.0
                            Thread.sleep(forTimeInterval: delayTime)
                            
                            let curId = obj.id
                            
                            Thread.sleep(forTimeInterval: delayTime)
                            
                            os_unfair_lock_lock(&lock)
                            result.append(curId)
                            os_unfair_lock_unlock(&lock)
                            
                            obj.id = curId + 1
                        }
                    }
                    
                }
            }
            
            group.wait(timeout: DispatchTime.distantFuture)
        }
        
        return result
    }
    
    func helperRunParallelIncNormalTransact(_ maxMillionths: Int, forcedSerial: Bool?, onQueue: DispatchQueue? = nil) -> [Int] {
        
        var result: [Int] = []
        var lock = os_unfair_lock()
        
        let queue = DispatchQueue(label: "releaseQueue", attributes: [])
        let group = DispatchGroup()
        
        for _ in 0 ..< 25 {
            
            for _ in 0 ..< 40 {
                group.enter()
                    
                Cd.transact(serial: forcedSerial, on: onQueue) {
                    if let obj = try! Cd.objects(TestItem.self).filter("name = %@", "A").fetchOne() {
                        
                        let delayTime = Double(arc4random_uniform(UInt32(maxMillionths))) / 1000000.0
                        Thread.sleep(forTimeInterval: delayTime)
                        
                        let curId = obj.id
                        
                        Thread.sleep(forTimeInterval: delayTime)
                        
                        os_unfair_lock_lock(&lock)
                        result.append(curId)
                        os_unfair_lock_unlock(&lock)
                        
                        obj.id = curId + 1
                        
                        queue.async {
                            group.leave()
                        }
                    }
                }
            }
            
            group.wait(timeout: DispatchTime.distantFuture)
        }
        
        return result
    }
    
    func testParallelNoCrash() {
        
        let res = helperRunParallelInc(10, forcedSerial: nil)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in i ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, true, "Tasks ran serially")
    }
    
    func testParallelSerialNoCrash() {
        
        Cd.defaultSerialTransactions = true
        
        let res = helperRunParallelInc(10, forcedSerial: nil)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in (i+1) ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, false, "Tasks did not run serially")
        
        
    }
    
    func testParallelSerialNoCrash2() {
        
        Cd.defaultSerialTransactions = false
        
        let res = helperRunParallelInc(10, forcedSerial: true)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in (i+1) ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, false, "Tasks did not run serially")
        
        
    }
    
    func testParallelSerialNoCrash3() {
        
        Cd.defaultSerialTransactions = true
        
        let res = helperRunParallelInc(10, forcedSerial: false)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in (i+1) ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, true, "Tasks did not run serially")
        
    }
    
    func testParallelSerialNoCrash4() {
        
        Cd.defaultSerialTransactions = false
        
        let res = helperRunParallelIncNormalTransact(10, forcedSerial: true)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in (i+1) ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, false, "Tasks did not run serially")
        
    }
    
    func testParallelSerialNoCrash5() {
        
        Cd.defaultSerialTransactions = false
        
        let res = helperRunParallelIncNormalTransact(10, forcedSerial: nil)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in (i+1) ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, true, "Tasks ran serially")
        
    }
    
    func testParallelSerialNoCrashUsingQueuesSer() {
        
        let myQueue = DispatchQueue(label: "test", attributes: [])
        
        let res = helperRunParallelIncNormalTransact(10, forcedSerial: nil, onQueue: myQueue)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in (i+1) ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, false, "Tasks did not run serially")
        
    }
    
    func testParallelSerialNoCrashUsingQueuesPar() {
        
        let myQueue = DispatchQueue(label: "test", attributes: DispatchQueue.Attributes.concurrent)
        
        let res = helperRunParallelIncNormalTransact(10, forcedSerial: nil, onQueue: myQueue)
        
        /* Pretty much impossible that this would create a perfectly linear list */
        var dupfound = false
        for i in 0 ..< (res.count - 1) {
            for j in (i+1) ..< res.count {
                if res[i] == res[j] { dupfound = true; break }
            }
        }
        
        XCTAssertEqual(res.count, 1000, "Did not run 1000 times")
        XCTAssertEqual(dupfound, false, "Tasks did not run serially")
        
    }
    
    func testTransactionInTransactionDoesntHang() {
        
        Cd.defaultSerialTransactions = true
        
        
        let group = DispatchGroup()

        group.enter()
        
        Cd.transact(serial: true) {
            if let obj = try! Cd.objects(TestItem.self).filter("name = %@", "A").fetchOne() {
                obj.id = obj.id + 1
            }
            Cd.transactAndWait(serial: true) {
                if let obj = try! Cd.objects(TestItem.self).filter("name = %@", "A").fetchOne() {
                    obj.id = obj.id + 1
                }
                Cd.transactAndWait(serial: true) {
                    if let obj = try! Cd.objects(TestItem.self).filter("name = %@", "A").fetchOne() {
                        obj.id = obj.id + 1
                    }
                }
            }
            group.leave()
        }
        
        group.wait(timeout: DispatchTime.distantFuture)
        
        XCTAssertEqual(true, true, "Hang Test")
        
    }
    
    /*
     *  ----------------- Testing Lifecycle --------------------
     */
    
    
    func initData() {
        
        let dispatchGroup = DispatchGroup()
        
        
        bgQueue.async(group: dispatchGroup) {
            
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
            
            
        }
        
        dispatchGroup.wait(timeout: DispatchTime.distantFuture)
    }
    
    func cleanName() -> String {
        let origName = self.name ?? "unknownTestName"
        let nospace = origName.replacingOccurrences(of: " ", with: "_")
        let nobrace1 = nospace.replacingOccurrences(of: "[", with: "")
        let nobrace2 = nobrace1.replacingOccurrences(of: "]", with: "")
        let nodash = nobrace2.replacingOccurrences(of: "-", with: "")
        return nodash
    }
    
    func initCd() {
        do {
            
            try Cd.initWithSQLStore(momdInbundleID: "org.fieldman.CadmiumTests",
                                    momdName:       "CadmiumTestModel",
                                    sqliteFilename: "\(self.cleanName()).sqlite",
                                    options:        [NSSQLitePragmasOption: ["journal_mode": "MEMORY"]])
            
        } catch let error {
            XCTFail("setup error: \(error)")
        }
    }
    
    func cleanCd() {
        let documentDirectories = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory   = documentDirectories[documentDirectories.count - 1]
        
        do {
            for url in try FileManager.default.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions(rawValue: 0)) {
                if url.description.range(of: "\(self.cleanName()).sqlite") != nil {
                    try FileManager.default.removeItem(at: url)
                }
            }
        } catch {}
    }
}

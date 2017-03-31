//
//  Cd.swift
//  Cadmium
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

import Foundation
import CoreData


public class Cd {

    
    /*
     *  -------------------- Settings -----------------------
     */
    
    /** If true, Cadmium will default to using serial transactions. */
    internal static var defaultSerialTransactions: Bool = false
    
    /*
     *  -------------------- Initialization ----------------------
     */
    
    /**
     Initialize the Cadmium engine with the URLs for the managed object model
     and the SQLite store.
    
    
     - parameter momdURL:   The full URL to the managed object model.
     - parameter sqliteURL: The full URL to the sqlite store.
                            If nil, Cadmium will use an in-memory store.
     - parameter serialTX:  If Cadmium should use serial transactions
                            by default.  See README for more information.
    */
    public static func initWithSQLStore(momdURL: URL, sqliteURL: URL?, options: [AnyHashable: Any]? = nil, serialTX: Bool = false) throws {
        guard let mom = NSManagedObjectModel(contentsOf: momdURL) else {
            throw CdInitFailure.invalidManagedObjectModel
        }
        
        defaultSerialTransactions = serialTX
        
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        let storeType = (sqliteURL == nil) ? NSInMemoryStoreType : NSSQLiteStoreType
        try psc.addPersistentStore(ofType: storeType, configurationName: nil, at: sqliteURL, options: options)
        
        CdManagedObjectContext.initializeMasterContexts(coordinator: psc)
    }
    
    /**
     Initialize the Cadmium engine with a SQLite store.  This initializer helps
     wrap up some of the menial tasks of drilling down exact URLs for resources.
     
     - parameter bundleID:       Pass the bundle identifier that contains your
                                 managed object model file.  This is typically
                                 something like com.yourcompany.yourapp, or
                                 com.yourcompany.yourframework.
     
                                 If you pass nil to this parameter it will look
                                 in the main bundle (which will fail if the
                                 object model is inside of another framework.
     - parameter momdName:       The name of the managed object model
     - parameter sqliteFilename: The name of the SQLite file you are storing data
                                 in.  The initializer will append this filename
                                 to the user's document directory.
                                 If nil, Cadmium will use an in-memory store.
     - parameter serialTX:       If Cadmium should use serial transactions
                                 by default.  See README for more information.
     
     - throws: Various errors in case something goes wrong!
     */
    public static func initWithSQLStore(momdInbundleID bundleID: String?, momdName: String, sqliteFilename: String?, options: [AnyHashable: Any]? = nil, serialTX: Bool = false) throws {
        var bundle: Bundle!
        
        if bundleID == nil {
            bundle = Bundle.main
        } else {
            guard let idBundle = Bundle(identifier: bundleID!) else {
                throw CdInitFailure.invalidBundle
            }
            bundle = idBundle
        }
        
        var actualMomdName: NSString = momdName as NSString
        if actualMomdName.pathExtension == "momd" {
            actualMomdName = actualMomdName.deletingPathExtension as NSString
        }
        
        guard let momdURL = bundle.url(forResource: actualMomdName as String, withExtension: "momd") else {
            throw CdInitFailure.invalidManagedObjectModel
        }
        
        var sqliteURL: URL? = nil
        if let filename = sqliteFilename {
            let documentDirectories = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentDirectory   = documentDirectories[documentDirectories.count - 1]
            sqliteURL               = documentDirectory.appendingPathComponent(filename)
            
            try FileManager.default.createDirectory(at: documentDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        
        try Cd.initWithSQLStore(momdURL: momdURL, sqliteURL: sqliteURL, options: options, serialTX: serialTX)
    }
    
    /*
     *  -------------------- Object Query Support ----------------------
     */
    
    /**
     This instantiates a CdFetchRequest object, which is used to created chained
     object queries.
     
     Be aware that the fetch will execute against the context of the calling thread.
     If run from the main thread, the fetch is on the main thread context.  If called
     from inside a transaction, the fetch is run against the context of the 
     transaction.
     
     - parameter objectClass: The managed object type to query.  Must inherit from
                               CdManagedObject
     
     - returns: The CdFetchRequest object ready to be configured and then fetched.
    */
    public static func objects<T: CdManagedObject>(_ objectClass: T.Type) -> CdFetchRequest<T> {
        return CdFetchRequest<T>()
    }

    /**
     A macro to query for a specific object based on its id (or primary key).
     
     - parameter objectClass: The object type to query for
     - parameter idValue:     The value of the ID
     - parameter key:         The name of the ID column (default = "id")
     
     - throws: Throws a general fetch exception if it occurs.
     
     - returns: The object that was found, or nil
     */
    public static func objectWithID<T: CdManagedObject>(_ objectClass: T.Type, idValue: AnyObject, key: String = "id") throws -> T? {
        return try Cd.objects(objectClass).filter("\(key) == %@", idValue).fetchOne()
    }
    
    /**
     A macro to query for objects based on their ids (or primary keys).
     
     - parameter objectClass: The object type to query for
     - parameter idValues:    The value of the IDS to search for
     - parameter key:         The name of the ID column (default = "id")
     
     - throws: Throws a general fetch exception if it occurs.
     
     - returns: The objects that were found
     */
    public static func objectsWithIDs<T: CdManagedObject>(_ objectClass: T.Type, idValues: [AnyObject], key: String = "id") throws -> [T] {
        return try Cd.objects(objectClass).filter("\(key) IN %@", idValues).fetch()
    }
    
    /**
     This is a wrapper around the normal NSFetchedResultsController that ensures
     you are using the main thread context.
     
     - parameter fetchRequest:       The NSFetchRequest to use.  You can use the .nsFetchRequest
                                     property of a CdFetchRequest.
     - parameter sectionNameKeyPath: The section name key path
     - parameter cacheName:          The cache name
     
     - returns: The initialized NSFetchedResultsController
     */
    public static func newFetchedResultsController<T: CdManagedObject>(_ fetchRequest: NSFetchRequest<T>, sectionNameKeyPath: String?, cacheName: String?) -> NSFetchedResultsController<T> {
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: CdManagedObjectContext.mainThreadContext(), sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
    }
    
    /*
     *  -------------------- Object Query Swift 3 Support ----------------------
     */
    
    /**
     This instantiates a CdFetchRequest object, which is used to created chained
     object queries.
     
     Be aware that the fetch will execute against the context of the calling thread.
     If run from the main thread, the fetch is on the main thread context.  If called
     from inside a transaction, the fetch is run against the context of the
     transaction.
     
     - parameter objectClass: The managed object type to query.  Must inherit from
                              CdManagedObject
     
     - returns: The CdFetchRequest object ready to be configured and then fetched.
     */
    public static func objectQuery<T: CdManagedObject>(for: T.Type) -> CdFetchRequest<T> {
        return CdFetchRequest<T>()
    }
    
    /**
     This instantiates a CdFetchRequest object, which is used to created chained
     object queries.
     
     Be aware that the fetch will execute against the context of the calling thread.
     If run from the main thread, the fetch is on the main thread context.  If called
     from inside a transaction, the fetch is run against the context of the
     transaction.
     
     - parameter objectClass: The managed object type to query.  Must inherit from
     CdManagedObject
     
     - returns: The CdFetchRequest object ready to be configured and then fetched.
     */
    public static func dictionaryQuery<T: CdManagedObject>(for: T.Type) -> CdFetchRequest<NSDictionary> {
        return CdFetchRequest<NSDictionary>(entityName: "\(T.self)")
    }
    
    /*
     *  -------------------- Object Lifecycle ----------------------
     */
    
    /**
     Create a new CdManagedObject.  If this method is called from the main thread the object must be
     transient.  Otherwise it must be called from inside a transaction.
     
     - parameter entityType: The entity type you would like to create.
     - parameter transient:  If false, the object will be automatically inserted
                             into the current transaction context.
     
     - returns: The created object.
     */
    public static func create<T: CdManagedObject>(_ entityType: T.Type, transient: Bool = false) throws -> T {
        guard let entDesc = NSEntityDescription.entity(forEntityName: "\(entityType)", in: CdManagedObjectContext.mainThreadContext()) else {
            Cd.raise("Could not create entity description for \(entityType)")
        }
        
        if transient {
            return CdManagedObject(entity: entDesc, insertInto:  nil) as! T
        }
        
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("You cannot create a non-transient object in the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only create a new managed object from inside a valid transaction.")
        }
        
        let object = CdManagedObject(entity: entDesc, insertInto: currentContext) as! T
        try currentContext.obtainPermanentIDs(for: [object])
        return object
    }
    
    /**
     Create many new CdManagedObjects.  If this method is called from the main thread the objects must be
     transient.  Otherwise it must be called from inside a transaction.
     
     - parameter entityType: The entity type you would like to create.
     - parameter count:      How many objects to create
     - parameter transient:  If false, the object will be automatically inserted
     into the current transaction context.
     
     - returns: The created object.
     */
    public static func create<T: CdManagedObject>(_ entityType: T.Type, count: Int, transient: Bool = false) throws -> [T] {
        guard count > 0 else {
            return []
        }
        
        guard let entDesc = NSEntityDescription.entity(forEntityName: "\(entityType)", in: CdManagedObjectContext.mainThreadContext()) else {
            Cd.raise("Could not create entity description for \(entityType)")
        }
        
        if transient {
            var result: [T] = []
            for _ in 0 ..< count {
                result.append(CdManagedObject(entity: entDesc, insertInto:  nil) as! T)
            }
            return result
        }
        
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("You cannot create non-transient objects in the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only create new managed objects from inside a valid transaction.")
        }
        
        var result: [T] = []
        for _ in 0 ..< count {
            let object = CdManagedObject(entity: entDesc, insertInto: currentContext) as! T
            try currentContext.obtainPermanentIDs(for: [object])
            result.append(object)
        }
        return result
    }
    
    /**
     Inserts the transient object into the current transaction context.  The object must have been created
     with the transient flag set to true, and not be inserted into any other context yet.
     
     - parameter object: The object to insert into the current context.
     */
    public static func insert(_ object: CdManagedObject) {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("You cannot insert an object from the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only insert a new managed object from inside a valid transaction.")
        }
        
        if currentContext === object.managedObjectContext {
            return
        }
        
        if object.managedObjectContext != nil {
            Cd.raise("You cannot insert an object into a context that already belongs to another context.  Use Cd.useInCurrentContext instead.")
        }
        
        let keys: [String] = object.entity.attributesByName.keys.map {$0}
        let properties = object.dictionaryWithValues(forKeys: keys)
        currentContext.insert(object)
        currentContext.refresh(object, mergeChanges: true)
        object.setValuesForKeys(properties)
    }
    
    /**
     Inserts the transient objects into the current transaction context.  The objects must have been created
     with the transient flag set to true, and not be inserted into any other context yet.
     
     - parameter objects: The objects to insert into the current context.
     */
    public static func insert(_ objects: [CdManagedObject]) {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("You cannot insert an object from the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only insert a new managed object from inside a valid transaction.")
        }

        for object in objects {
            if currentContext === object.managedObjectContext {
                continue
            }
            
            if object.managedObjectContext != nil {
                Cd.raise("You cannot insert an object into a context that already belongs to another context.  Use Cd.useInCurrentContext instead.")
            }
            
            let keys: [String] = object.entity.attributesByName.keys.map {$0}
            let properties = object.dictionaryWithValues(forKeys: keys)
            currentContext.insert(object)
            currentContext.refresh(object, mergeChanges: true)
            object.setValuesForKeys(properties)
        }
    }
    
    /**
     Delete the object from the current transaction context.  The object must exist and
     reside in the current transactional context.
     
     - parameter object: The object to delete from the current context.
     */
    public static func delete(_ object: CdManagedObject) {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("You cannot delete an object from the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only delete a managed object from inside a transaction.")
        }
        
        if currentContext !== object.managedObjectContext {
            Cd.raise("You may only delete a managed object from inside the transaction it belongs to.")
        }
        
        if object.managedObjectContext == nil {
            Cd.raise("You cannot delete an object that is not in a context.")
        }
        
        currentContext.delete(object)
    }
    
    /**
     Delete the objects from the current transaction context.  The objects must exist and
     reside in the current transactional context.
     
     - parameter objects: The objects to delete from the current context.
     */
    public static func delete(_ objects: [CdManagedObject]) {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("You cannot delete an object from the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only delete a managed object from inside a transaction.")
        }
        
        for object in objects {
            if currentContext !== object.managedObjectContext {
                Cd.raise("You may only delete a managed object from inside the transaction it belongs to.")
            }
            
            if object.managedObjectContext == nil {
                Cd.raise("You cannot delete an object that is not in a context.")
            }
            
            currentContext.delete(object)
        }
    }
    
     
    /*
     *  -------------------- Transaction Support ----------------------
     */
    
    /**
     Initiate a database transaction asynchronously on a background thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.
     
     If the serial setting is true, transactions are executed serially, even if they
     occur in different contexts.
    
     - parameter serial:    If defined, it will override the serial transaction
                            setting declared during initialization.  Leave nil
                            to use the default.
     - parameter on:        If non-nil, specifies the dispatch queue to run the
                            serial operation on.  This must be a serial dispatch
                            queue (not concurrent).  If this argument is non-nil,
                            the serial argument is assumed true unless specifically
                            passed as false.
     - parameter operation:	This function should be used for transactions that
                            operate in a background thread, and may ultimately 
                            save back to the database using the Cd.commit() call.
    
                            The operation block is run asynchronously and will not 
                            occur on the main thread.  It will run on the private
                            queue of the write context.
     
                            It is important to note that no transactions can occur
                            on the main thread.  This will use a background write
                            context even if initially called from the main thread.
    */
    public static func transact(serial: Bool? = nil, on serialQueue: DispatchQueue? = nil, operation: @escaping (Void) -> Void) {
        let useSerial = (serial ?? Cd.defaultSerialTransactions) || (serial != false && serialQueue != nil)
                
        /*  These blocks are different.  One calls performBlock as normal (useSerial = false).
            The other calls performBlockAndWait inside of an async serial queue (useSerial = true)
         */
        
        if useSerial {
            (serialQueue ?? CdManagedObjectContext.serialTransactionQueue).async {
                let newWriteContext = CdManagedObjectContext.newBackgroundWriteContext()
                newWriteContext.performAndWait() {
                    let prevInside = Thread.current.setInsideTransaction(true)
                    self.transactOperation(newWriteContext, operation: operation)
                    Thread.current.setInsideTransaction(prevInside)
                }
            }
        } else {
            let newWriteContext = CdManagedObjectContext.newBackgroundWriteContext()
            newWriteContext.perform {
                let prevInside = Thread.current.setInsideTransaction(true)
                self.transactOperation(newWriteContext, operation: operation)
                Thread.current.setInsideTransaction(prevInside)
            }
        }
    }
    
    /**
     Initiate a database transaction asynchronously on a background thread with an
     object from a different context.  A new CdManagedObjectContext will be created 
     for the lifetime of the transaction.
     
     If the serial setting is true, transactions are executed serially, even if they
     occur in different contexts.
     
     - parameter object:    An object from another context that you would like
                            to use in this transaction.
     - parameter serial:    If defined, it will override the serial transaction
                            setting declared during initialization.  Leave nil
                            to use the default.
     - parameter on:        If non-nil, specifies the dispatch queue to run the
                            serial operation on.  This must be a serial dispatch
                            queue (not concurrent).  If this argument is non-nil,
                            the serial argument is assumed true unless specifically
                            passed as false.
     - parameter operation:	This function should be used for transactions that
                            operate in a background thread, and may ultimately
                            save back to the database using the Cd.commit() call.
                            The operation is passed a CdManagedObject in the
                            new context that is derived from the first parameter.
     
     The operation block is run asynchronously and will not
     occur on the main thread.  It will run on the private
     queue of the write context.
     
     It is important to note that no transactions can occur
     on the main thread.  This will use a background write
     context even if initially called from the main thread.
     */
    public static func transactWith<T: CdManagedObject>(_ object: T, serial: Bool? = nil, on serialQueue: DispatchQueue? = nil, operation: @escaping (T?) -> Void) {
        Cd.transact(serial: serial, on: serialQueue) {
            operation(Cd.useInCurrentContext(object))
        }
    }

    /**
     Initiate a database transaction asynchronously on a background thread with an
     object from a different context.  A new CdManagedObjectContext will be created
     for the lifetime of the transaction.
     
     If the serial setting is true, transactions are executed serially, even if they
     occur in different contexts.
     
     - parameter objects:   An array of objects from another context that you would like
                            to use in this transaction.
     - parameter serial:    If defined, it will override the serial transaction
                            setting declared during initialization.  Leave nil
                            to use the default.
     - parameter on:        If non-nil, specifies the dispatch queue to run the
                            serial operation on.  This must be a serial dispatch
                            queue (not concurrent).  If this argument is non-nil,
                            the serial argument is assumed true unless specifically
                            passed as false.
     - parameter operation:	This function should be used for transactions that
                            operate in a background thread, and may ultimately
                            save back to the database using the Cd.commit() call.
                            The operation is passed an array of CdManagedObjects in the
                            new context that is derived from the first parameter.
     
     The operation block is run asynchronously and will not
     occur on the main thread.  It will run on the private
     queue of the write context.
     
     It is important to note that no transactions can occur
     on the main thread.  This will use a background write
     context even if initially called from the main thread.
     */
    public static func transactWith<T: CdManagedObject>(_ objects: [T], serial: Bool? = nil, on serialQueue: DispatchQueue? = nil, operation: @escaping ([T]) -> Void) {
        Cd.transact(serial: serial, on: serialQueue) {
            operation(Cd.useInCurrentContext(objects))
        }
    }

    /**
     Initiate a database transaction synchronously on the current thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.

     This function cannot be called from the main thread, to prevent potential
     deadlocks.  You can execute fetches and read data on the main thread without
     needing to wrap those operations in a transaction.
     
     If the serial setting is true, transactions are executed serially, even if they 
     occur in different contexts.  Recursive transactAndWait calls are not 
     dispatched serially, even if this setting is true (to prevent deadlocks).
     
     - parameter serial:    If defined, it will override the serial transaction
                            setting declared during initialization.  Leave nil
                            to use the default.
     - parameter on:        If non-nil, specifies the dispatch queue to run the
                            serial operation on.  This must be a serial dispatch
                            queue (not concurrent).  If this argument is non-nil,
                            the serial argument is assumed true unless specifically
                            passed as false.
     - parameter operation:	This function should be used for transactions that
                            should occur synchronously against the current background
                            thread.  Transactions may ultimately save back to the 
                            database using the Cd.commit() call.
     
                            The operation is synchronous and will block until complete.
                            It will execute on the context's private queue and may or
                            may not execute in a separate thread than the calling
                            thread.
    */
    public static func transactAndWait(serial: Bool? = nil, on serialQueue: DispatchQueue? = nil, operation: @escaping (Void) -> Void) {
        if Thread.current.isMainThread {
            Cd.raise("You cannot perform transactAndWait on the main thread.  Use transact, or spin off a new background thread to call transactAndWait")
        }
        
        let useSerial = ((serial ?? Cd.defaultSerialTransactions) || (serial != false && serialQueue != nil)) && !Thread.current.insideTransaction()
        
        let operationBlock = {
            let newWriteContext = CdManagedObjectContext.newBackgroundWriteContext()
            newWriteContext.performAndWait {
                let prevInside = Thread.current.setInsideTransaction(true)
                self.transactOperation(newWriteContext, operation: operation)
                Thread.current.setInsideTransaction(prevInside)
            }
        }
        
        if useSerial {
            (serialQueue ?? CdManagedObjectContext.serialTransactionQueue).sync(execute: operationBlock)
        } else {
            operationBlock()
        }
    }
    
    
    /**
     Initiate a database transaction synchronously on the current thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.
     
     This function cannot be called from the main thread, to prevent potential
     deadlocks.  You can execute fetches and read data on the main thread without
     needing to wrap those operations in a transaction.
     
     If the serial setting is true, transactions are executed serially, even if they
     occur in different contexts.  Recursive transactAndWait calls are not
     dispatched serially, even if this setting is true (to prevent deadlocks).
     
     - parameter object:    An object from another context that you would like
                            to use in this transaction.
     - parameter serial:    If defined, it will override the serial transaction
                            setting declared during initialization.  Leave nil
                            to use the default.
     - parameter on:        If non-nil, specifies the dispatch queue to run the
                            serial operation on.  This must be a serial dispatch
                            queue (not concurrent).  If this argument is non-nil,
                            the serial argument is assumed true unless specifically
                            passed as false.
     - parameter operation:	This function should be used for transactions that
                            should occur synchronously against the current background
                            thread.  Transactions may ultimately save back to the
                            database using the Cd.commit() call.
     
     The operation is synchronous and will block until complete.
     It will execute on the context's private queue and may or
     may not execute in a separate thread than the calling
     thread.
     */
    public static func transactAndWaitWith<T: CdManagedObject>(_ object: T, serial: Bool? = nil, on serialQueue: DispatchQueue? = nil, operation: @escaping (T?) -> Void) {
        Cd.transactAndWait(serial: serial, on: serialQueue) {
            operation(Cd.useInCurrentContext(object))
        }
    }
    
    
    /**
     Initiate a database transaction synchronously on the current thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.
     
     This function cannot be called from the main thread, to prevent potential
     deadlocks.  You can execute fetches and read data on the main thread without
     needing to wrap those operations in a transaction.
     
     If the serial setting is true, transactions are executed serially, even if they
     occur in different contexts.  Recursive transactAndWait calls are not
     dispatched serially, even if this setting is true (to prevent deadlocks).
     
     - parameter objects:   An array of objects from another context that you would like
                            to use in this transaction.
     - parameter serial:    If defined, it will override the serial transaction
                            setting declared during initialization.  Leave nil
                            to use the default.
     - parameter on:        If non-nil, specifies the dispatch queue to run the
                            serial operation on.  This must be a serial dispatch
                            queue (not concurrent).  If this argument is non-nil,
                            the serial argument is assumed true unless specifically
                            passed as false.
     - parameter operation:	This function should be used for transactions that
                            should occur synchronously against the current background
                            thread.  Transactions may ultimately save back to the
                            database using the Cd.commit() call.
     
     The operation is synchronous and will block until complete.
     It will execute on the context's private queue and may or
     may not execute in a separate thread than the calling
     thread.
     */
    public static func transactAndWaitWith<T: CdManagedObject>(_ objects: [T], serial: Bool? = nil, on serialQueue: DispatchQueue? = nil, operation: @escaping ([T]) -> Void) {
        Cd.transactAndWait(serial: serial, on: serialQueue) {
            operation(Cd.useInCurrentContext(objects))
        }
    }
    
    
    /**
     This is the private helper method that conducts that actual transaction
     inside of the context's queue.
     
     - parameter fromContext: The managed object context we are transacting inside.
     - parameter operation:   The operation to perform.
     */
    fileprivate static func transactOperation(_ fromContext: CdManagedObjectContext, operation: (Void) -> Void) {
        let currentThread    = Thread.current
        let existingContext  = currentThread.attachedContext()
        let existingNoCommit = currentThread.noImplicitCommit()
        
        currentThread.attachContext(fromContext)
        operation()
        
        if currentThread.noImplicitCommit() == false {
            try! Cd.commit()
        }
        
        currentThread.attachContext(existingContext)
        currentThread.setNoImplicitCommit(existingNoCommit)
    }
    
    /**
     Call this function from inside of a transaction to cancel the implicit
     commit that will occur after the transaction closure completes.
     */
    public static func cancelImplicitCommit() {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("The main thread does have a transaction context that can be committed.")
        }
        
        guard let _ = currentThread.attachedContext() else {
            Cd.raise("You must call this from inside a valid transaction.")
        }
        
        currentThread.setNoImplicitCommit(true)
    }
   
    /**
     Get the CdManagedObjectContext from inside of a valid transaction block.
     This can be used for various object manipulation functions (insertion,
     deletion, etc).
     
     - returns: The CdManagedObjectContext for the current transaction.
     */
    public static func transactionContext() -> CdManagedObjectContext {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("The main thread cannot have a transaction context.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You must call this from inside a valid transaction.")
        }
        
        return currentContext
    }
    
    /**
     Allows you to refer to a foreign CdManagedObject (from another
     context) in your current context.
     
     - parameter object: A CdManagedObject that is suitable to use
                         in the current context (must have a permanent ID).
     */
    public static func useInCurrentContext<T: CdManagedObject>(_ object: T) -> T? {
        guard let currentContext = Thread.current.attachedContext() else {
            Cd.raise("You may only call useInCurrentContext from the main thread, or inside a valid transaction.")
        }
        
        if let originalContext = object.managedObjectContext , originalContext.hasChanges && originalContext != CdManagedObjectContext._mainThreadContext {
            Cd.raise("You cannot transfer an object from a context that has outstanding changes.  Make sure you call Cd.commit() from your transaction first.")
        }
        
        if object.objectID.isTemporaryID {
            Cd.raise("You cannot transfer an object without a permanent object ID.  This object may be transient or unsaved in its current context.")
        }
        
        if let myItem = (try? currentContext.existingObject(with: object.objectID)) as? T {
            currentContext.refresh(myItem, mergeChanges: false)
            return myItem
        }
        
        return nil
    }
    
    /**
     Use a CdManagedObject from a transaction back on the main thread.
     
     - parameter object:    The CdManagedObject you would like to use on the main thread.
     - parameter operation: The operation to perform.  The argument in this operation block
                            receives a version of the CdManagedObject on the main thread's
                            read-only context.
     */
    public static func onMainWith<T: CdManagedObject>(_ object: T?, operation: @escaping ((T?) -> Void)) {
        guard let obj = object else {
            DispatchQueue.main.async {
                operation(object)
            }
            return
        }
        
        DispatchQueue.main.async {
            operation(Cd.useInCurrentContext(obj))
        }
    }
    
    /**
     Use a CdManagedObject from a transaction back on the main thread.
     
     - parameter objects:   An array of CdManagedObjects you would like to use on the main thread.
     - parameter operation: The operation to perform.  The argument in this operation block
                            receives an array of CdManagedObjects on the main thread's
                            read-only context.  If an object could not be acquired on the main
                            thread it is not included in the array.
     */
    public static func onMainWith<T: CdManagedObject>(_ objects: [T], operation: @escaping (([T]) -> Void)) {
        DispatchQueue.main.async {
            var arr: [T] = []
            for obj in objects {
                if let mainObj = Cd.useInCurrentContext(obj) {
                    arr.append(mainObj)
                }
            }
            operation(arr)
        }
    }
    
    /**
     Allows you to refer to an array of foreign CdManagedObjects (from another
     context) in your current context.
     
     - parameter objects:   An array of CdManagedObjects that is suitable to use
                            in the current context (must have a permanent ID).
     - returns:             An array of objects suitable for use in the current
                            context.  Any object that could not be transferred is
                            left out of the return array.
     */
    public static func useInCurrentContext<T: CdManagedObject>(_ objects: [T]) -> [T] {
        var result: [T] = []
        
        for original in objects {
            if let contextObject = Cd.useInCurrentContext(original) {
                result.append(contextObject)
            }
        }
        
        return result
    }
    
    /**
     Commit any changes made inside of an active transaction.  Must be called from
     inside Cd.transact or Cd.transactAndWait.
    */
    public static func commit() throws {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            Cd.raise("You can only commit changes inside of a transaction (the main thread is read-only).")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You can only commit changes inside of a transaction.")
        }
        
        /* We're inside of the context's performBlock -- only save it we have to */
        if currentContext.hasChanges {
            try currentContext.save()
        
            /* Save on our master write context */
            CdManagedObjectContext.saveMasterWriteContext()
        }
    }
    
    
    /*
     *  -------------------- Error Handling ----------------------
     */
    
    internal static func raise(_ reason: String) -> Never  {
        NSException(name: NSExceptionName(rawValue: "Cadmium Exception"), reason: reason, userInfo: nil).raise()
        fatalError("These usage exception cannot be caught")
    }
   
    
}

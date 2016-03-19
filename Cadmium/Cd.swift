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
     *  -------------------- Initialization ----------------------
     */
    
    /**
     Initialize the Cadmium engine with the URLs for the managed object model
     and the SQLite store.
    
    
     - parameter momdURL:   The full URL to the managed object model.
     - parameter sqliteURL: The full URL to the sqlite store.
    */
    public class func initWithSQLStore(momdURL momdURL: NSURL, sqliteURL: NSURL, options: [NSObject : AnyObject]? = nil) throws {
        guard let mom = NSManagedObjectModel(contentsOfURL: momdURL) else {
            throw CdInitFailure.InvalidManagedObjectModel
        }
        
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: sqliteURL, options: options)
        
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
     
     - throws: Various errors in case something goes wrong!
     */
    public class func initWithSQLStore(momdInbundleID bundleID: String?, momdName: String, sqliteFilename: String, options: [NSObject : AnyObject]? = nil) throws {
        var bundle: NSBundle!
        
        if bundleID == nil {
            bundle = NSBundle.mainBundle()
        } else {
            guard let idBundle = NSBundle(identifier: bundleID!) else {
                throw CdInitFailure.InvalidBundle
            }
            bundle = idBundle
        }
        
        var actualMomdName: NSString = momdName
        if actualMomdName.pathExtension == "momd" {
            actualMomdName = actualMomdName.stringByDeletingPathExtension
        }
        
        guard let momdURL = bundle.URLForResource(actualMomdName as String, withExtension: "momd") else {
            throw CdInitFailure.InvalidManagedObjectModel
        }
        
        let documentDirectories = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        let documentDirectory   = documentDirectories[documentDirectories.count - 1]
        let sqliteURL           = documentDirectory.URLByAppendingPathComponent(sqliteFilename)
        
        try NSFileManager.defaultManager().createDirectoryAtURL(documentDirectory, withIntermediateDirectories: true, attributes: nil)
        try Cd.initWithSQLStore(momdURL: momdURL, sqliteURL: sqliteURL, options: options)
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
    @inline(__always) public class func objects<T: CdManagedObject>(objectClass: T.Type) -> CdFetchRequest<T> {
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
    public class func objectWithID<T: CdManagedObject>(objectClass: T.Type, idValue: AnyObject, key: String = "id") throws -> T? {
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
    public class func objectsWithIDs<T: CdManagedObject>(objectClass: T.Type, idValues: [AnyObject], key: String = "id") throws -> [T] {
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
    public class func newFetchedResultsController(fetchRequest: NSFetchRequest, sectionNameKeyPath: String?, cacheName: String?) -> NSFetchedResultsController {
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: CdManagedObjectContext.mainThreadContext(), sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
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
    public class func create<T: CdManagedObject>(entityType: T.Type, transient: Bool = false) throws -> T {
        guard let entDesc = NSEntityDescription.entityForName("\(entityType)", inManagedObjectContext: CdManagedObjectContext.mainThreadContext()) else {
            Cd.raise("Could not create entity description for \(entityType)")
        }
        
        if transient {
            return CdManagedObject(entity: entDesc, insertIntoManagedObjectContext:  nil) as! T
        }
        
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            Cd.raise("You cannot create a non-transient object in the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only create a new managed object from inside a valid transaction.")
        }
        
        let object = CdManagedObject(entity: entDesc, insertIntoManagedObjectContext: currentContext) as! T
        try currentContext.obtainPermanentIDsForObjects([object])
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
    public class func create<T: CdManagedObject>(entityType: T.Type, count: Int, transient: Bool = false) throws -> [T] {
        guard count > 0 else {
            return []
        }
        
        guard let entDesc = NSEntityDescription.entityForName("\(entityType)", inManagedObjectContext: CdManagedObjectContext.mainThreadContext()) else {
            Cd.raise("Could not create entity description for \(entityType)")
        }
        
        if transient {
            var result: [T] = []
            for _ in 0 ..< count {
                result.append(CdManagedObject(entity: entDesc, insertIntoManagedObjectContext:  nil) as! T)
            }
            return result
        }
        
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            Cd.raise("You cannot create non-transient objects in the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            Cd.raise("You may only create new managed objects from inside a valid transaction.")
        }
        
        var result: [T] = []
        for _ in 0 ..< count {
            let object = CdManagedObject(entity: entDesc, insertIntoManagedObjectContext: currentContext) as! T
            try currentContext.obtainPermanentIDsForObjects([object])
            result.append(object)
        }
        return result
    }
    
    /**
     Inserts the transient object into the current transaction context.  The object must have been created
     with the transient flag set to true, and not be inserted into any other context yet.
     
     - parameter object: The object to insert into the current context.
     */
    public class func insert(object: CdManagedObject) {
        let currentThread = NSThread.currentThread()
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
        let properties = object.dictionaryWithValuesForKeys(keys)
        currentContext.insertObject(object)
        currentContext.refreshObject(object, mergeChanges: true)
        object.setValuesForKeysWithDictionary(properties)
    }
    
    /**
     Inserts the transient objects into the current transaction context.  The objects must have been created
     with the transient flag set to true, and not be inserted into any other context yet.
     
     - parameter objects: The objects to insert into the current context.
     */
    public class func insert(objects: [CdManagedObject]) {
        let currentThread = NSThread.currentThread()
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
            let properties = object.dictionaryWithValuesForKeys(keys)
            currentContext.insertObject(object)
            currentContext.refreshObject(object, mergeChanges: true)
            object.setValuesForKeysWithDictionary(properties)
        }
    }
    
    /**
     Delete the object from the current transaction context.  The object must exist and
     reside in the current transactional context.
     
     - parameter object: The object to delete from the current context.
     */
    public class func delete(object: CdManagedObject) {
        let currentThread = NSThread.currentThread()
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
        
        currentContext.deleteObject(object)
    }
    
    /**
     Delete the objects from the current transaction context.  The objects must exist and
     reside in the current transactional context.
     
     - parameter objects: The objects to delete from the current context.
     */
    public class func delete(objects: [CdManagedObject]) {
        let currentThread = NSThread.currentThread()
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
            
            currentContext.deleteObject(object)
        }
    }
    
     
    /*
     *  -------------------- Transaction Support ----------------------
     */
    
    /**
     Initiate a database transaction asynchronously on a background thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.
    
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
    public class func transact(operation: Void -> Void) {
        let newWriteContext = CdManagedObjectContext.newBackgroundWriteContext()
        newWriteContext.performBlock {
            self.transactOperation(newWriteContext, operation: operation)
        }
    }

    /**
     Initiate a database transaction synchronously on the current thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.

     This function cannot be called from the main thread, to prevent potential
     deadlocks.  You can execute fetches and read data on the main thread without
     needing to wrap those operations in a transaction.
     
     - parameter operation:	This function should be used for transactions that
                            should occur synchronously against the current background
                            thread.  Transactions may ultimately save back to the 
                            database using the Cd.commit() call.
     
                            The operation is synchronous and will block until complete.
                            It will execute on the context's private queue and may or
                            may not execute in a separate thread than the calling
                            thread.
    */
    public class func transactAndWait(operation: Void -> Void) {
        if NSThread.currentThread().isMainThread {
            Cd.raise("You cannot perform transactAndWait on the main thread.  Use transact, or spin off a new background thread to call transactAndWait")
        }
        
        let newWriteContext = CdManagedObjectContext.newBackgroundWriteContext()
        newWriteContext.performBlockAndWait {
            self.transactOperation(newWriteContext, operation: operation)
        }
    }
    
    /**
     This is the private helper method that conducts that actual transaction
     inside of the context's queue.
     
     - parameter fromContext: The managed object context we are transacting inside.
     - parameter operation:   The operation to perform.
     */
    private class func transactOperation(fromContext: CdManagedObjectContext, @noescape operation: Void -> Void) {
        let currentThread    = NSThread.currentThread()
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
    public class func cancelImplicitCommit() {
        let currentThread = NSThread.currentThread()
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
    public class func transactionContext() -> CdManagedObjectContext {
        let currentThread = NSThread.currentThread()
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
                         in the current context.
     */
    public class func useInCurrentContext<T: CdManagedObject>(object: T) -> T? {
        guard let currentContext = NSThread.currentThread().attachedContext() else {
            Cd.raise("You may only call useInCurrentContext from the main thread, or inside a valid transaction.")
        }
        
        guard let originalContext = object.managedObjectContext else {
            Cd.raise("You cannot transfer a transient object to a context.  Use Cd.insert instead.")
        }
        
        if originalContext.hasChanges && originalContext != CdManagedObjectContext._mainThreadContext {
            Cd.raise("You cannot transfer an object from a context that has outstanding changes.  Make sure you call Cd.commit() from your transaction first.")
        }
        
        if let myItem = (try? currentContext.existingObjectWithID(object.objectID)) as? T {
            currentContext.refreshObject(myItem, mergeChanges: false)
            return myItem
        }
        
        return nil
    }
    
    /**
     Commit any changes made inside of an active transaction.  Must be called from
     inside Cd.transact or Cd.transactAndWait.
    */
    public class func commit() throws {
        let currentThread = NSThread.currentThread()
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
    
    @noreturn internal class func raise(reason: String) {
        NSException(name: "Cadmium Exception", reason: reason, userInfo: nil).raise()
        fatalError("These usage exception cannot be caught")
    }
    
    
}
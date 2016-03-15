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

    /**
     *  -------------------- Initialization ----------------------
     */
    
    /* TODO: Init needs work */
    public class func initWithSQLStore(momdURL momdURL: NSURL, sqliteURL: NSURL) {
        guard let mom = NSManagedObjectModel(contentsOfURL: momdURL) else {
            return
        }
        
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        try! psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: sqliteURL, options: nil)
        
        CdManagedObjectContext.initializeMasterContexts(coordinator: psc)
    }
    
    
    /**
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
    
    
    /**
     *  -------------------- Object Creation ----------------------
     */
    
    /**
     Create a new CdManagedObject.  This must be called from the main thread (and must be
     transient), or called from inside a transaction.
     
     - parameter entityType: The entity type you would like to create.
     - parameter transient:  If false, the object will be automatically inserted
                             into the current transaction context.
     
     - returns: The created object.
     */
    public class func create<T: CdManagedObject>(entityType: T.Type, transient: Bool = false) -> T {
        guard let entDesc = NSEntityDescription.entityForName("\(entityType)", inManagedObjectContext: CdManagedObjectContext.mainThreadContext()) else {
            fatalError("Could not create entity description for \(entityType)")
        }
        
        if transient {
            return CdManagedObject(entity: entDesc, insertIntoManagedObjectContext:  nil) as! T
        }
        
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            fatalError("You cannot create a non-transient object in the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            fatalError("You may only create a new managed object from inside a valid transaction.")
        }
        
        return CdManagedObject(entity: entDesc, insertIntoManagedObjectContext: currentContext) as! T
    }
    
     
    /**
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
            let currentThread = NSThread.currentThread()
            let existingContext = currentThread.attachedContext()
            currentThread.attachContext(newWriteContext)
            operation()
            currentThread.attachContext(existingContext)
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
            fatalError("You cannot perform transactAndWait on the main thread.  Use transact, or spin off a new background thread to call transactAndWait")
        }
        
        let newWriteContext = CdManagedObjectContext.newBackgroundWriteContext()
        newWriteContext.performBlockAndWait {
            let currentThread = NSThread.currentThread()
            let existingContext = currentThread.attachedContext()
            currentThread.attachContext(newWriteContext)
            operation()
            currentThread.attachContext(existingContext)
        }
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
            fatalError("The main thread cannot have a transaction context.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            fatalError("You must call this from inside a valid transaction.")
        }
        
        return currentContext
    }
	
    /**
     Allows you to refer to a foreign CdManagedObject (from another
     context) in your current transaction.
     
     - parameter object: A CdManagedObject that is suitable to use
                         in the current transaction.
     */
    public class func useInTransaction(object: CdManagedObject) -> CdManagedObject {
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            fatalError("The main thread cannot have a transaction context.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            fatalError("You must call this from inside a valid transaction.")
        }
        
        return currentContext.objectWithID(object.objectID) as! CdManagedObject
    }
    
	/**
	 Commit any changes made inside of an active transaction.  Must be called from
	 inside Cd.transact or Cd.transactAndWait.
	*/
	public class func commit() throws {
		let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            fatalError("You can only commit changes inside of a transaction.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            fatalError("You can only commit changes inside of a transaction.")
        }
        
        /* We must be inside of the context's performBlock */
        try currentContext.save()
        
        /* Save on our master write context */
        CdManagedObjectContext.saveMasterWriteContext()
	}
    
    
    
    
    
    
}
//
//  CdManagedObjectContext.swift
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


public class CdManagedObjectContext : NSManagedObjectContext {
    
    
    /**
     *    ------------------- Internal Properties ----------------------------
     */
    
    /**
     *  This handle tracks the main thread context singleton for our implementation.
     *  It should be initialized when the Cadmium system is initialized.
     */
    internal static var _mainThreadContext: CdManagedObjectContext? = nil
    
    /**
     *  This handle tracks the master background save context.  This context will be
     *  the parent context for all others (include all background transactions and the
     *  main thread context).
     */
    internal static var _masterSaveContext: CdManagedObjectContext? = nil
    
    /**
     *  This should be set to true when an update handler is installed.  It tells
     *  the notification handler to iterate through updated objects and call their
     *  handlers.
     */
    internal static var shouldCallUpdateHandlers: Bool = false
    
    /**
     *  This is the concurrent dispatch queue which is used to pass async
     *  transactions if they are intended to be used serially.  This allows
     *  us to block on our recursive lock before executing the context
     *  transaction.
     */
    internal static let serialTransactionQueue = DispatchQueue(label: "Cd.ManagedObjectContext.serialTransactionQueue", attributes: [])
    
    /**
     Initialize the master save context and the main thread context.
     
     - parameter coordinator: The persistent store coordinator for the save context.
     */
    internal static func initializeMasterContexts(coordinator: NSPersistentStoreCoordinator) {
        _masterSaveContext = CdManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        _masterSaveContext?.undoManager = nil
        _masterSaveContext?.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        _masterSaveContext?.persistentStoreCoordinator = coordinator
        
        _mainThreadContext = CdManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        _mainThreadContext?.undoManager = nil
        _mainThreadContext?.parent = _masterSaveContext
        
        let notificationQueue = OperationQueue()
        
        /* Attach update handler to main thread context */
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSManagedObjectContextDidSave, object: _masterSaveContext, queue: notificationQueue) { (notification: Notification) -> Void in
            DispatchQueue.main.async {
                Thread.current.setInsideMainThreadChangeNotification(true)
                
                /* Fault-in update objects before mergeChangesFromContextDidSaveNotification
                   This allows monitoring FRC to see newly inserted objects, rather than them
                   being treated like invisible faults.
                   http://www.mlsite.net/blog/?p=518 */
                if let updates = (notification as NSNotification).userInfo?["updated"] as? Set<NSManagedObject> {
                    for update in updates {
                        _mainThreadContext?.object(with: update.objectID).willAccessValue(forKey: nil)
                    }
                }
                
                _mainThreadContext?.mergeChanges(fromContextDidSave: notification)
                Thread.current.setInsideMainThreadChangeNotification(false)
            }
        }
        
        /* Attach update handler to main thread context */
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: _mainThreadContext, queue: nil) { (notification: Notification) -> Void in
            guard shouldCallUpdateHandlers else { return }
            
            DispatchQueue.main.async {
                if let refreshedObjects = (notification as NSNotification).userInfo?[NSRefreshedObjectsKey] as? Set<CdManagedObject> {
                    for object in refreshedObjects {
                        object.updateHandler?(.refreshed)
                    }
                }
                
                if let updatedObjects = (notification as NSNotification).userInfo?[NSUpdatedObjectsKey] as? Set<CdManagedObject> {
                    for object in updatedObjects {
                        object.updateHandler?(.updated)
                    }
                }
                
                if let deletedObjects = (notification as NSNotification).userInfo?[NSDeletedObjectsKey] as? Set<CdManagedObject> {
                    for object in deletedObjects {
                        object.updateHandler?(.deleted)
                    }
                }
            }
        }
        
        /* Attach handler for one-time iCloud setup */
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSPersistentStoreCoordinatorStoresWillChange, object: coordinator, queue: notificationQueue) { (notification: Notification) -> Void in
            guard let msc = _masterSaveContext else {
                return
            }
            
            msc.perform {
                if (msc.hasChanges) {
                    try! msc.save()
                } else {
                    msc.reset()
                }
            }
        }
    }
    
    /**
     *    ------------------- Internal Helper Functions ----------------------
     */
     
     
    /**
     Returns the main thread context (and protects against pre-initialization access)
     
     - returns: The main thread context
     */
    @inline(__always) internal static func mainThreadContext() -> CdManagedObjectContext {
        if let mtc = _mainThreadContext {
            return mtc
        }
        
        /* This is only feasible if we have not initialized the Cadmium engine. */
        Cd.raise("Cadmium must be initialized before a main thread context is available.")
    }
    
    /**
     Creates a new background write context whose parent is the master save context.
     
     - returns: The new background write context.
     */
    @inline(__always) internal static func newBackgroundWriteContext() -> CdManagedObjectContext {
        let newContext           = CdManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        newContext.parent = _masterSaveContext
        newContext.undoManager   = nil
        return newContext
    }
    
    /**
     Returns the proper CdManagedObjectContext instance for the calling thread.  If called from
     the main thread it will return the main thread context.  Otherwise it will check if a
     background write context exists for this thread.
     
     - returns: The proper CdManagedObjectContext for the calling thread (if it exists)
     */
    @inline(__always) internal static func forThreadContext() -> CdManagedObjectContext? {
        let currentThread = Thread.current
        if currentThread.isMainThread {
            return mainThreadContext()
        }
        
        if let currentContext = currentThread.attachedContext() {
            return currentContext
        }
        
        return nil
    }

    /**
     Saves the master write context if necessary.
     */
    @inline(__always) internal static func saveMasterWriteContext() {
        guard let msc = _masterSaveContext else {
            return
        }
        
        msc.performAndWait {
            if msc.hasChanges {
                try! msc.obtainPermanentIDs(for: Array<NSManagedObject>(msc.insertedObjects))
                try! msc.save()
            }
        }
    }
}



internal extension Thread {
    
    /**
     Get the currently attached CdManagedObjectContext to the thread.
     
     - returns: The currently attached context, or nil if none.
     */
    internal func attachedContext() -> CdManagedObjectContext? {
        if self.isMainThread {
            return CdManagedObjectContext._mainThreadContext
        }
        return self.threadDictionary[kCdThreadPropertyCurrentContext] as? CdManagedObjectContext
    }
    
    /**
     Attach a context to the current thread.  Pass nil to remove the context from the current thread.
     
     - parameter context: The context to attach, or nil to remove.
     */
    @inline(__always) internal func attachContext(_ context: CdManagedObjectContext?) {
        if self.isMainThread {
            Cd.raise("You cannot explicitly attach a context from the main thread.")
        }
        self.threadDictionary[kCdThreadPropertyCurrentContext] = context
    }
    
    /**
     Returns true if the current transaction context should *NOT* perform
     an implicit commit.
     
     - returns: true if the current transaction context should *NOT*
                perform an implicit commit.
     */
    @inline(__always) internal func noImplicitCommit() -> Bool {
        return (self.threadDictionary[kCdThreadPropertyNoImplicitSave] as? Bool) ?? false
    }
    
    /**
     Declare if the current transaction context should perform an implicit commit
     when finished.
     
     - parameter status: Whether or not the implicit commit should be aborted.
     */
    @inline(__always) internal func setNoImplicitCommit(_ status: Bool?) {
        self.threadDictionary[kCdThreadPropertyNoImplicitSave] = status
    }
    
    /**
     Returns true if the main thread is inside a sanctioned
     NSManagedObjectContextDidSaveNotification notification).
     
     - returns: true if the main thread should allow modifications (set during
     the NSManagedObjectContextDidSaveNotification notification).
     */
    internal func insideMainThreadChangeNotification() -> Bool {
        return (self.threadDictionary[kCdThreadPropertyMainSaveNotif] as? Bool) ?? false
    }
    
    /**
     Declare if the main thread context is inside of a sanctioned
     NSManagedObjectContextDidSaveNotification merge event.
     
     - parameter status: true if so, false if not.
     */
    internal func setInsideMainThreadChangeNotification(_ inside: Bool) {
        self.threadDictionary[kCdThreadPropertyMainSaveNotif] = inside
    }
    
    /**
     Returns true if the thread is inside a transaction.
     
     - returns: true if the thread is inside a transaction.
     */
    internal func insideTransaction() -> Bool {
        return (self.threadDictionary[kCdThreadPropertyInsideTrans] as? Bool) ?? false
    }
    
    /**
     Declare if a thread is inside a transaction.
     
     - parameter status: true if so, false if not.
     - returns:          The previous value
     */
    @discardableResult internal func setInsideTransaction(_ inside: Bool) -> Bool {
        let result = (self.threadDictionary[kCdThreadPropertyInsideTrans] as? Bool) ?? false
        self.threadDictionary[kCdThreadPropertyInsideTrans] = inside
        return result
    }
    
}


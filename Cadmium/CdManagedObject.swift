//
//  CdManagedObject.swift
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

/**
 Passed into the updateHandler of a CdManagedObject when a modification
 event occurs.
 
 - Refreshed: The receiver object was refreshed (from a change in
              another context).
 - Deleted:   The receiver object was deleted.
 */
public enum CdManagedObjectUpdateEvent {
    case Refreshed, Deleted
}

/**
 *  Any core data model class you create must inherit from CdManagedObject
 *  instead of NSManagedObject.  This is enforced in the query functions since
 *  a return type must of CdManagedObject.
 *
 *  The implementation of this class installs access and write hooks that
 *  verify you are modifying your managed objects in the proper context.
 */
public class CdManagedObject : NSManagedObject {
    
    // MARK: - Public Access dictionary
    
    /** This userInfo dictionary is available to store persistent data along with
        your managed object */
    public var userInfo: [String: Any] = [:]
    
    // MARK: - Update handler
    
    /** You can attach an update handler to receive events that occur to this 
        main thread object.
 
        Because you can only install one handler, advanced use cases that need
        multiple handlers can use the userInfo dictionary to extend dispatching
        behavior (e.g. use the userInfo dictionary to store reactive-style signal
        handlers.) */
    public var updateHandler: (CdManagedObjectUpdateEvent -> Void)? = nil {
        didSet {
            if self.managedObjectContext != CdManagedObjectContext._mainThreadContext {
                Cd.raise("You may attach an updateHandler to an object from the main thread context.")
            }
            CdManagedObjectContext.shouldCallUpdateHandlers = true
        }
    }
    
    // MARK: - Protections
    
    /**
     This is an override for willAccessValueForKey: that ensures the access
     is performed in the proper threading context.
     
     - parameter key: The key whose value is being accessed.
     */
    public override func willAccessValueForKey(key: String?) {
        guard let myManagedObjectContext = self.managedObjectContext else {
            super.willAccessValueForKey(key)
            return
        }
        
        if myManagedObjectContext === CdManagedObjectContext._masterSaveContext {
            super.willAccessValueForKey(key)
            return
        }
        
        let currentThread = NSThread.currentThread()
        guard let currentContext = currentThread.attachedContext() where currentContext === myManagedObjectContext else {
            if myManagedObjectContext === CdManagedObjectContext.mainThreadContext() {
                Cd.raise("You are accessing a managed object from the main thread from a background thread.")
            } else if currentThread.attachedContext() === nil {
                Cd.raise("You are accessing a managed object from a thread that does not have a managed object context.")
            } else if currentThread.attachedContext() === CdManagedObjectContext.mainThreadContext() {
                Cd.raise("You are accessing a managed object from a background transaction on the main thread.")
            } else {
                Cd.raise("You are accessing a managed object from a background transaction outside of its transaction.")
            }
        }
        
        super.willAccessValueForKey(key)
    }
    
    /**
     This is an override for willChangeValueForKey: that ensures the change
     is performed in the proper threading context.
     
     - parameter key: The key whose value is being changed.
     */
    public override func willChangeValueForKey(key: String) {
        guard let myManagedObjectContext = self.managedObjectContext else {
            super.willChangeValueForKey(key)
            return
        }
        
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            Cd.raise("You cannot modify a managed object on the main thread.  Only from inside a transaction.")
        }
        
        if myManagedObjectContext === CdManagedObjectContext._masterSaveContext {
            super.willChangeValueForKey(key)
            return
        }
        
        guard let currentContext = currentThread.attachedContext() where currentContext === myManagedObjectContext else {
            if currentThread.attachedContext() == nil {
                Cd.raise("You are modifying a managed object from a thread that does not have a managed object context.")
            } else {
                Cd.raise("You are modifying a managed object from outside of its original transaction.")
            }
        }
        
        super.willChangeValueForKey(key)
    }
    
    /**
     This is an override for willChangeValueForKey:inMutationKind:usingObjects: that ensures the change
     is performed in the proper threading context.
     
     - parameter inKkey: The key whose value is being changed.
     - parameter withSetMutation: The kind of mutation being applied.
     - parameter usingObjects: The objects being related.
     */
    public override func willChangeValueForKey(inKey: String, withSetMutation inMutationKind: NSKeyValueSetMutationKind, usingObjects inObjects: Set<NSObject>) {
        guard let myManagedObjectContext = self.managedObjectContext else {
            super.willChangeValueForKey(inKey, withSetMutation: inMutationKind, usingObjects: inObjects)
            return
        }
        
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            Cd.raise("You cannot modify a managed object on the main thread.  Only from inside a transaction.")
        }
        
        if myManagedObjectContext === CdManagedObjectContext._masterSaveContext {
            super.willChangeValueForKey(inKey, withSetMutation: inMutationKind, usingObjects: inObjects)
            return
        }
        
        guard let currentContext = currentThread.attachedContext() where currentContext === myManagedObjectContext else {
            if currentThread.attachedContext() == nil {
                Cd.raise("You are modifying a managed object from a thread that does not have a managed object context.")
            } else {
                Cd.raise("You are modifying a managed object from outside of its original transaction.")
            }
        }
        
        for object in inObjects {
            guard let managedObject = object as? CdManagedObject where managedObject.managedObjectContext === myManagedObjectContext else {
                Cd.raise("You are attempting to create a relationship between objects from different contexts.")
            }
        }
        
        super.willChangeValueForKey(inKey, withSetMutation: inMutationKind, usingObjects: inObjects)
    }
}
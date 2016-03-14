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
 *  Any core data model class you create must inherit from CdManagedObject
 *  instead of NSManagedObject.  This is enforced in the query functions since
 *  a return type must of CdManagedObject.
 *
 *  The implementation of this class installs access and write hooks that
 *  verify you are modifying your managed objects in the proper context.
 */
public class CdManagedObject : NSManagedObject {
    
    /**
     Create a CdManagedObject that is already inserted into the context
     of the current transaction.
     
     - returns: The CdManagedObject that has been inserted into the
                current context.
     */
    public class func create() -> CdManagedObject {
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            fatalError("You cannot create a new object in the main thread.")
        }
        
        guard let currentContext = currentThread.attachedContext() else {
            fatalError("You may only create a new managed object from inside a valid transaction.")
        }
        
        guard let entDesc = NSEntityDescription.entityForName(String(self.dynamicType), inManagedObjectContext: currentContext) else {
            fatalError("Could not create entity description for \(String(self.dynamicType))")
        }
        
        return CdManagedObject(entity: entDesc, insertIntoManagedObjectContext: currentContext)
    }

    
    /**
     Create a transient instance of a CdManagedObject.  This instance is not
     automatically inserted into a context.
     
     - returns: The CdManagedObject that has not been inserted into a context yet.
     */
    public class func createTransient() -> CdManagedObject {
        guard let entDesc = NSEntityDescription.entityForName(String(self.dynamicType), inManagedObjectContext: CdManagedObjectContext.mainThreadContext()) else {
            fatalError("Could not create entity description for \(String(self.dynamicType))")
        }
        
        return CdManagedObject(entity: entDesc, insertIntoManagedObjectContext: nil)
    }
    
    
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
        
        let currentThread = NSThread.currentThread()
        guard let currentContext = currentThread.attachedContext() where currentContext == myManagedObjectContext else {
            if myManagedObjectContext == CdManagedObjectContext.mainThreadContext() {
                fatalError("You are accessing a managed object from the main thread from a background thread.")
            } else if currentThread.attachedContext() == nil {
                fatalError("You are accessing a managed object from a thread that does not have a managed object context.")
            } else if currentThread.attachedContext() == CdManagedObjectContext.mainThreadContext() {
                fatalError("You are accessing a managed object from a background transaction on the main thread.")
            } else {
                fatalError("You are accessing a managed object from a background transaction outside of its transaction.")
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
        
        let currentThread = NSThread.currentThread()
        if currentThread.isMainThread {
            fatalError("You cannot modify a managed object on the main thread.  Only from inside a transaction.")
        }
        
        guard let myManagedObjectContext = self.managedObjectContext else {
            super.willAccessValueForKey(key)
            return
        }
        
        guard let currentContext = currentThread.attachedContext() where currentContext == myManagedObjectContext else {
            if currentThread.attachedContext() == nil {
                fatalError("You are modifying a managed object from a thread that does not have a managed object context.")
            } else {
                fatalError("You are modifying a managed object from outside of its original transaction.")
            }
        }
        
        super.willChangeValueForKey(key)
    }
    
    /* TODO: Explore protections in setValue:forKey: (relationships stay within context) */
}
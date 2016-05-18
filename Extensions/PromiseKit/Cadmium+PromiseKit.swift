//
//  Cadmium+PromiseKit.swift
//  CadmiumPromiseExample
//
//  Created by Jason Fieldman on 5/13/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation
import PromiseKit


public enum CdPromiseError : ErrorType {
    case NotAvailableInCurrentContext(CdManagedObject?)
}

public extension Cd {
	
    /** Allows you to perform a standard Cadmium transaction as a Promise */
    public class func transact<U>(serial serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, operation: (Void) throws -> U) -> Promise<U> {
		return Promise { fulfill, reject in
            dispatch_async(dispatch_get_global_queue(0, 0)) {
                var result: U!
                var error: ErrorType?
                Cd.transactAndWait(serial: serial, on: serialQueue) {
                    do {
                        result = try operation()
                    } catch let _error {
                        error = _error
                    }
                }
                if let error = error {
                    reject(error)
                } else {
                    fulfill(result)
                }
            }
		}
	}
	
    /** Allows you to perform a standard Cadmium transaction as a Promise.
        Converts the object to an instance in the operation's context. */
	public class func transactWith<T: CdManagedObject, U>(object: T, serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, operation: (T) throws -> U) -> Promise<U> {
		return Promise { fulfill, reject in
            dispatch_async(dispatch_get_global_queue(0, 0)) {
                var result: U!
                var error: ErrorType?
                Cd.transactAndWait(serial: serial, on: serialQueue) {
                    guard let currentObject = Cd.useInCurrentContext(object) else {
                        reject(CdPromiseError.NotAvailableInCurrentContext(object))
                        return
                    }
                    
                    do {
                        result = try operation(currentObject)
                    } catch let _error {
                        error = _error
                    }
                }
                if let error = error {
                    reject(error)
                } else {
                    fulfill(result)
                }
            }            
		}
	}
	
    /** Allows you to perform a standard Cadmium transaction as a Promise.
        Converts the object array to the operation's context. */
	public class func transactWith<T: CdManagedObject, U>(objects: [T], serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, operation: ([T]) throws -> U) -> Promise<U> {
		return Promise { fulfill, reject in
            dispatch_async(dispatch_get_global_queue(0, 0)) {
                var result: U!
                var error: ErrorType?
                Cd.transactAndWait(serial: serial, on: serialQueue) {
                    do {
                        result = try operation(Cd.useInCurrentContext(objects))
                    } catch let _error {
                        error = _error
                    }
                }
                if let error = error {
                    reject(error)
                } else {
                    fulfill(result)
                }
            }
		}
	}
	
}


public extension Promise {
	
    /** Allows you to chain a Cadmium transaction into the promise chain with the immediate 'then' style. 
        The argument to the promise operation is treated as a normal non-managed-object instance. */
	public func thenTransact<U>(serial serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, body: (T) throws -> U) -> Promise<U> {
		
		return self.thenInBackground { (value: T) -> U in
			var result: U!
            var error: ErrorType?
			Cd.transactAndWait(serial: serial, on: serialQueue) {
                do {
                    result = try body(value)
                } catch let _error {
                    error = _error
                }
			}
            if let error = error { throw error }
			return result
		}
		
	}
	
}



public extension Promise where T: CdManagedObject {
	
    /** Allows you to chain a Cadmium transaction into the promise chain with the immediate 'then' style.
        Using this operation when the generic is a CdManagedObject converts the token object to a new
        instance that belongs to the body's context. */
	public func thenTransactWith<U>(serial serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, body: (T) throws -> U) -> Promise<U> {
		
		return self.thenInBackground { (value: T?) -> U in
			guard let _value = value else {
				throw CdPromiseError.NotAvailableInCurrentContext(value)
			}
			
			var result: U!
            var error: ErrorType?
            Cd.transactAndWait(serial: serial, on: serialQueue) {
				guard let currentObject = Cd.useInCurrentContext(_value) else {
                    error = CdPromiseError.NotAvailableInCurrentContext(_value)
                    return
                }
                
                do {
                    result = try body(currentObject)
                } catch let _error {
                    error = _error
                }
            }
            if let error = error { throw error }
			return result
		}
		
	}
    
    /** Use this to send a managed object from a promise chain into the main thread context. */
	public func thenOnMainWith<U>(body: (T) throws -> U) -> Promise<U> {
		
		return self.then { (value: T) -> U in
            guard let currentObject = Cd.useInCurrentContext(value) else {
                throw CdPromiseError.NotAvailableInCurrentContext(value)
            }
            
			return try body(currentObject)
		}
		
	}
}

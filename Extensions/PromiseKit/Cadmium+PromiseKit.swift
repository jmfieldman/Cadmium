//
//  Cadmium+PromiseKit.swift
//  CadmiumPromiseExample
//
//  Created by Jason Fieldman on 5/13/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation
import PromiseKit
import Cadmium


public extension Cd {
	
	
	public class func transact<U>(serial serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, operation: (Void) throws -> U) -> Promise<U> {
		return Promise { fulfill, reject in
			Cd.transact(serial: serial, on: serialQueue) {
				do {
					let result = try operation()
					fulfill(result)
				} catch let error {
					reject(error)
				}
			}
		}
	}
	
	public class func transactWith<T: CdManagedObject, U>(object: T, serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, operation: (T) throws -> U) -> Promise<U> {
		return Promise { fulfill, reject in
			Cd.transact(serial: serial, on: serialQueue) {
				do {
					let result = try operation(Cd.useInCurrentContext(object))
					fulfill(result)
				} catch let error {
					reject(error)
				}
			}
		}
	}
	
	public class func transactWith<T: CdManagedObject, U>(objects: [T], serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, operation: ([T]) throws -> U) -> Promise<U> {
		return Promise { fulfill, reject in
			Cd.transact(serial: serial, on: serialQueue) {
				do {
					let result = try operation(Cd.useInCurrentContext(objects))
					fulfill(result)
				} catch let error {
					reject(error)
				}
			}
		}
	}
	
}


public extension Promise {
	
	public func thenTransact<U>(serial serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, body: (T) throws -> U) -> Promise<U> {
		
		return self.then { (value: T) -> U in
			var result: U!
			Cd.transact(serial: serial, on: serialQueue) {
				result = try body(value)
			}
			return result
		}
		
	}
	
}


public extension Promise where T: CdManagedObject {
	
	public func thenTransactWith<U>(serial serial: Bool? = nil, on serialQueue: dispatch_queue_t? = nil, body: (T) throws -> U) -> Promise<U> {
		
		return self.then { (value: T) -> U in
			var result: U!
			Cd.transact(serial: serial, on: serialQueue) {
				result = try body(Cd.useInCurrentContext(value))
			}
			return result
		}
		
	}
	
	public func thenOnMainWith<U>(body: (T) throws -> U) -> Promise<U> {
		
		return self.then { (value: T) -> U in
			return try body(Cd.useInCurrentContext(value))			
		}
		
	}
}

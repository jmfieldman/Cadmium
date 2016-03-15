//
//  CdFetchRequest.swift
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
 *  The CdFetchRequest class enables chained query statements and ensures fetches
 *  occur in the proper context.
 */
public class CdFetchRequest<T: CdManagedObject> {
    
    /**
     *  This is the internal NSFetchRequest we are wrapping.
     */
    public let nsFetchRequest: NSFetchRequest
    
    
    /**
     Initialize the CdFetchRequest object.  This class can only be instantiated from
     within the Cadmium framework by using the Cd.objects method.
     
     - returns: The new fetch request
     */
    internal init() {
        nsFetchRequest = NSFetchRequest(entityName: "\(T.self)")
    }
    
    /*
     *  -------------------------- Filtering ------------------------------
     */
    
    /**
     Filter the fetch request by a predicate.
     
     - parameter predicate: The predicate to use as a filter.  
                            It is ANDed with the existing predicate, if one exists already.
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func filter(predicate: NSPredicate) -> CdFetchRequest<T> {
        if let currentPredicate = nsFetchRequest.predicate {
            nsFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [currentPredicate, predicate])
        } else {
            nsFetchRequest.predicate = predicate
        }
        return self
    }

    /**
     Filter the fetch request using a string and arguments.
     
     - parameter predicateString: The predicate string
     - parameter predicateArgs:   The arguments in the string
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func filter(predicateString: String, _ predicateArgs: AnyObject...) -> CdFetchRequest<T> {
        let newPredicate = NSPredicate(format: predicateString, argumentArray: predicateArgs)
        return filter(newPredicate)
    }
    
    /**
     The 'and' method is a synonym for the 'filter' method.
     
     - parameter predicate: The predicate to filter by
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func and(predicate: NSPredicate) -> CdFetchRequest<T> {
        return filter(predicate)
    }
    
    /**
     The 'and' method is a synonym for the 'filter' method.
     
     - parameter predicateString: The predicate string
     - parameter predicateArgs:   The arguments in the string
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func and(predicateString: String, _ predicateArgs: AnyObject...) -> CdFetchRequest<T> {
        let newPredicate = NSPredicate(format: predicateString, argumentArray: predicateArgs)
        return and(newPredicate)
    }
    
    /**
     Append an OR predicate to the existing filter.
     
     - parameter predicate: The predicate to use as a filter.
                            It is ORed with the existing predicate, if one exists already.
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func or(predicate: NSPredicate) -> CdFetchRequest<T> {
        if let currentPredicate = nsFetchRequest.predicate {
            nsFetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [currentPredicate, predicate])
        } else {
            nsFetchRequest.predicate = predicate
        }
        return self
    }
    
    /**
     Append an OR predicate to the existing filter using a string and parameters.
     
     - parameter predicateString: The predicate string
     - parameter predicateArgs:   The arguments in the string
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func or(predicateString: String, _ predicateArgs: AnyObject...) -> CdFetchRequest<T> {
        let newPredicate = NSPredicate(format: predicateString, argumentArray: predicateArgs)
        return or(newPredicate)
    }
    
    
    /*
     *  -------------------------- Sorting ------------------------------
     */
    
    /**
     Attach a sort descriptor to the fetch using key and ascending.
     
     - parameter property:  The name of the property to sort on
     - parameter ascending: Should the sort be ascending?
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func sorted(property: String, ascending: Bool = true) -> CdFetchRequest<T> {
        let descriptor = NSSortDescriptor(key: property, ascending: ascending)
        return sorted(descriptor)
    }
    
    /**
     Attach a sort descriptor to the fetch using an NSSortDescriptor
     
     - parameter descriptor: The descriptor to sort with
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func sorted(descriptor: NSSortDescriptor) -> CdFetchRequest<T> {
        if nsFetchRequest.sortDescriptors == nil {
            nsFetchRequest.sortDescriptors = [descriptor]
        } else {
            nsFetchRequest.sortDescriptors!.append(descriptor)
        }
        return self
    }
    
    
    /*
     *  ------------------------ Misc Operations --------------------------
     */
    
    /**
     Specify only the specific object attributes you want to query.
     This modifies propertiesToFetch
     
     - parameter attributes: The list of attributes to include in the query.
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func onlyAttr(attributes: [String]) -> CdFetchRequest<T> {
        nsFetchRequest.propertiesToFetch = attributes
        return self
    }
    
    /**
     Specify the limit of objects to query for.
     This modifies fetchLimit
     
     - parameter limit: The limit of objects to fetch.
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func limit(limit: Int) -> CdFetchRequest<T> {
        nsFetchRequest.fetchLimit = limit
        return self
    }
    
    /**
     Specify the offset to begin the fetch.
     This modifies fetchOffset
     
     - parameter offset: The offset to begin fetching from
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func offset(offset: Int) -> CdFetchRequest<T> {
        nsFetchRequest.fetchOffset = offset
        return self
    }
    
    /**
     Specify the batch size of the query.
     This modifies fetchBatchSize
     
     - parameter batchSize: The batch size for the query
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func batchSize(batchSize: Int) -> CdFetchRequest<T> {
        nsFetchRequest.fetchBatchSize = batchSize
        return self
    }
    
    /**
     Specify whether or not the query should query distinct values for the attributes
     declared in onlyAttr.  If onlyAttr has not been called, this will have no
     affect.  Modifies returnsDistinctResults
     
     - parameter distinct: Whether or not to only return distinct values of onlyAttr
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func distinct(distinct: Bool = true) -> CdFetchRequest<T> {
        nsFetchRequest.returnsDistinctResults = distinct
        return self
    }
    
    /**
     Specify which relationships to prefetch during the query.
     This modifies relationshipKeyPathsForPrefetching
     
     - parameter relationships: The names of the relationships to prefetch
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func prefetch(relationships: [String]) -> CdFetchRequest<T> {
        nsFetchRequest.relationshipKeyPathsForPrefetching = relationships
        return self
    }
    
    /*
     *  -------------------------- Fetching ------------------------------
     */
    
    /**
     Executes the fetch on the current context.  If run from the main thread, it
     executes on the main thread context.  If run from a transaction it will
     execute on the transaction thread.  
     
     You cannot execute this on a non-transaction background thread since there 
     will not be an attached context.
     
     - throws:  If the underlying NSFetchRequest throws an error, this returns
                it up the stack.
     
     - returns: The fetch results
     */
    public func fetch() throws -> [T] {
        guard let currentContext = NSThread.currentThread().attachedContext() else {
            Cd.raise("You cannot fetch data from a non-transactional background thread.  You may only query from the main thread or from inside a transaction.")
        }
        
        if let results = try currentContext.executeFetchRequest(nsFetchRequest) as? [T] {
            return results
        }
        
        return []
    }
    
    /**
     Executes the fetch on the current context.  If run from the main thread, it
     executes on the main thread context.  If run from a transaction it will
     execute on the transaction thread.
     
     This method automatically sets the fetchLimit to 1, and returns a single value
     (not an array).
     
     You cannot execute this on a non-transaction background thread since there
     will not be an attached context.
     
     - throws:  If the underlying NSFetchRequest throws an error, this returns
     it up the stack.
     
     - returns: The fetch results
     */
    @inline(__always) public func fetchOne() throws -> T? {
        nsFetchRequest.fetchLimit = 1
        return try fetch().first
    }
    
    /**
     Returns the number of objects that match the fetch parameters.  If you are only interested in
     counting objects, this method is much faster than performing a normal fetch and counting
     the objects in the full response array (since Core Data does not have to instantiate any
     managed objects for the count.)
     
     - returns: The number of items that match the fetch parameters, or NSNotFound if an error occurred.
     */
    @inline(__always) public func count() throws -> Int {
        guard let currentContext = NSThread.currentThread().attachedContext() else {
            Cd.raise("You cannot fetch data from a non-transactional background thread.  You may only query from the main thread or from inside a transaction.")
        }
        
        return currentContext.countForFetchRequest(nsFetchRequest, error: nil)
    }
    
    
}
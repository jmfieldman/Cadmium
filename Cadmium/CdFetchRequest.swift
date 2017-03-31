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
public class CdFetchRequest<T: NSFetchRequestResult> {
    
    /**
     *  This is the internal NSFetchRequest we are wrapping.
     */
    public let nsFetchRequest: NSFetchRequest<T>
    
    /**
     *  Contains the expressions declared during method chaining (indexed by name)
     */
    private var includedExpressions: [String: NSExpressionDescription] = [:]
    
    /**
     *  Contains the allowed properties declared during method chaining
     */
    private var includedProperties: Set<String> = Set<String>()
    
    /**
     *  Contains the properties to group by declared during method chaining
     */
    private var includedGroupings: [String] = []
    
    /**
     Initialize the CdFetchRequest object.  This class can only be instantiated from
     within the Cadmium framework by using the Cd.objects method.
     
     - returns: The new fetch request
     */
    internal init() {
        nsFetchRequest = NSFetchRequest(entityName: "\(T.self)")
    }
    
    internal init(entityName: String) {
        nsFetchRequest = NSFetchRequest(entityName: entityName)
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
    @inline(__always) public func filter(_ predicate: NSPredicate) -> CdFetchRequest<T> {
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
    @inline(__always) public func filter(_ predicateString: String, _ predicateArgs: Any...) -> CdFetchRequest<T> {
        let newPredicate = NSPredicate(format: predicateString, argumentArray: predicateArgs)
        return filter(newPredicate)
    }
    
    /**
     The 'and' method is a synonym for the 'filter' method.
     
     - parameter predicate: The predicate to filter by
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func and(_ predicate: NSPredicate) -> CdFetchRequest<T> {
        return filter(predicate)
    }
    
    /**
     The 'and' method is a synonym for the 'filter' method.
     
     - parameter predicateString: The predicate string
     - parameter predicateArgs:   The arguments in the string
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func and(_ predicateString: String, _ predicateArgs: AnyObject...) -> CdFetchRequest<T> {
        let newPredicate = NSPredicate(format: predicateString, argumentArray: predicateArgs)
        return and(newPredicate)
    }
    
    /**
     Append an OR predicate to the existing filter.
     
     - parameter predicate: The predicate to use as a filter.
                            It is ORed with the existing predicate, if one exists already.
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func or(_ predicate: NSPredicate) -> CdFetchRequest<T> {
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
    @inline(__always) public func or(_ predicateString: String, _ predicateArgs: AnyObject...) -> CdFetchRequest<T> {
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
    @inline(__always) public func sorted(_ property: String, ascending: Bool = true) -> CdFetchRequest<T> {
        let descriptor = NSSortDescriptor(key: property, ascending: ascending)
        return sorted(descriptor)
    }
    
    /**
     Attach a sort descriptor to the fetch using an NSSortDescriptor
     
     - parameter descriptor: The descriptor to sort with
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func sorted(_ descriptor: NSSortDescriptor) -> CdFetchRequest<T> {
        if nsFetchRequest.sortDescriptors == nil {
            nsFetchRequest.sortDescriptors = [descriptor]
        } else {
            nsFetchRequest.sortDescriptors!.append(descriptor)
        }
        return self
    }
    
    /*
     *  ------------------------ Expressions --------------------------
     */
    
    /**
     Include a custom expression in your response.  If this is chained in, you must use fetchDictionaryArray()
     since you cannot fetch managed objects with custom properties.
     
     In order to include the expression results in the dictionary, the 'named' value must be present
     in the array you pass to onlyProperties()
     
     - parameter named:      The name for the expression.  This will be referenced in onlyProperties()
     - parameter resultType: The result type for the expression.
     - parameter withFormat: The format for the expression.
     - parameter formatArgs: The arguments for the expression, if required.
     
     - returns: The updated fetch request.
     */
    public func includeExpression(_ named: String, resultType: NSAttributeType, withFormat: String, _ formatArgs: AnyObject...) -> CdFetchRequest<T> {
        let expression                      = NSExpression(format: withFormat, formatArgs)
        
        let expressionDesc                  = NSExpressionDescription()
        expressionDesc.expression           = expression
        expressionDesc.name                 = named
        expressionDesc.expressionResultType = resultType
        
        self.includedExpressions[named] = expressionDesc
        
        return self
    }
    
    /*
     *  ------------------------ Misc Operations --------------------------
     */
    
    /**
     Specify only the specific properties you want to query.
     This modifies propertiesToFetch
     
     - parameter properties: The list of properties to include in the query.
     
     - returns: The updated fetch request.
     */
    public func onlyProperties(_ properties: [String]) -> CdFetchRequest<T> {
        self.includedProperties.formUnion(properties)
        return self
    }
    
    /**
     Specify only the properties you want to group by.
     This modifies propertiesToGroupBy
     
     - parameter properties: The list of properties to group by.
     
     - returns: The updated fetch request.
     */
    public func groupBy(_ properties: [String]) -> CdFetchRequest<T> {
        self.includedGroupings.append(contentsOf: properties)
        return self
    }
    
    /**
     Specify only the properties you want to group by.
     This modifies propertiesToGroupBy
     
     - parameter properties: The list of properties to group by.
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func groupBy(_ property: String) -> CdFetchRequest<T> {
        return groupBy([property])
    }
    
    /**
     Specify the limit of objects to query for.
     This modifies fetchLimit
     
     - parameter limit: The limit of objects to fetch.
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func limit(_ limit: Int) -> CdFetchRequest<T> {
        nsFetchRequest.fetchLimit = limit
        return self
    }
    
    /**
     Specify the offset to begin the fetch.
     This modifies fetchOffset
     
     - parameter offset: The offset to begin fetching from
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func offset(_ offset: Int) -> CdFetchRequest<T> {
        nsFetchRequest.fetchOffset = offset
        return self
    }
    
    /**
     Specify the batch size of the query.
     This modifies fetchBatchSize
     
     - parameter batchSize: The batch size for the query
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func batchSize(_ batchSize: Int) -> CdFetchRequest<T> {
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
    @inline(__always) public func distinct(_ distinct: Bool = true) -> CdFetchRequest<T> {
        nsFetchRequest.returnsDistinctResults = distinct
        return self
    }
    
    /**
     Specify which relationships to prefetch during the query.
     This modifies relationshipKeyPathsForPrefetching
     
     - parameter relationships: The names of the relationships to prefetch
     
     - returns: The updated fetch request.
     */
    @inline(__always) public func prefetch(_ relationships: [String]) -> CdFetchRequest<T> {
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
        guard let currentContext = Thread.current.attachedContext() else {
            Cd.raise("You cannot fetch data from a non-transactional background thread.  You may only query from the main thread or from inside a transaction.")
        }
        
        if T.self is NSDictionary.Type {
            // -------- Dictionary fetches --------------
            
            nsFetchRequest.resultType = .dictionaryResultType
            
            if includedProperties.count > 0 {
                var actualProperties: [AnyObject] = []
                for propertyName in includedProperties {
                    if let expression = includedExpressions[propertyName] {
                        actualProperties.append(expression)
                    } else {
                        actualProperties.append(propertyName as AnyObject)
                    }
                }
                nsFetchRequest.propertiesToFetch = actualProperties
            }
            
            if includedGroupings.count > 0 {
                for groupName in includedGroupings {
                    if !includedProperties.contains(groupName) {
                        Cd.raise("You cannot group by a property name unless you've included it in onlyProperties()")
                    }
                }
                nsFetchRequest.propertiesToGroupBy = includedGroupings
            }
        } else {
            // ------ For non-dictionary fetches -------------
            
            if includedProperties.count > 0 {
                nsFetchRequest.propertiesToFetch = [String](includedProperties)
            }
            
            if includedExpressions.count > 0 {
                Cd.raise("You cannot call fetch() if you have included custom expressions.  Use fetchDictionaryArray()")
            }
            
            if includedGroupings.count > 0 {
                Cd.raise("You cannot call fetch() if you have included custom groupings.  Use fetchDictionaryArray()")
            }
        }
        
        return try currentContext.fetch(nsFetchRequest)
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
    public func count() throws -> Int {
        guard let currentContext = Thread.current.attachedContext() else {
            Cd.raise("You cannot fetch data from a non-transactional background thread.  You may only query from the main thread or from inside a transaction.")
        }
        
        return try currentContext.count(for: nsFetchRequest)
    }
    
    
    
}


public extension CdFetchRequest where T: CdManagedObject {
    
    /**
     Deletes any objects that match the receivers query.  Performs the delete in the current context
     if called from inside a transaction.  Otherwise, it wraps the delete in an asynchronous transaction.
     
     - throws: The error thrown during the fetch request.
     */
    public func delete() throws {
        if let currentContext = Thread.current.attachedContext() , currentContext !== CdManagedObjectContext._mainThreadContext {
            Cd.delete(try self.fetch())
            return
        }
        
        Cd.transact {
            try! self.delete()
        }
    }
}

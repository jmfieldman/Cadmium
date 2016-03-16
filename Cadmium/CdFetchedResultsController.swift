//
//  CdFetchedResultsController.swift
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

public class CdFetchedResultsController : NSFetchedResultsController {
    
    /**
     The CdFetchedResultsController wraps the NSFetchedResultsController init
     in such a way that you are forced to request on the main thread's read
     context. 
     
     You will never be able to modify objects acquired from this controller.
     Instead, you can pass them to transactions using the Cd.useInCurrentContext
     method.
     
     - parameter fetchRequest:       You are not forced to use a CdFetchRequest,
                                     But you are encouraged to construct your query
                                     using its mechanism and accessing its
                                     nsFetchRequest property.
     - parameter sectionNameKeyPath: The section name key path (see NSFetchRequest)
     - parameter cacheName:          The cache name (see NSFetchRequest)
     
     - returns: The instantiated controller.  Assign a delegate manually or
                use the automateDelegation method.  Use performFetch to initiate.
     */
    public init(fetchRequest: NSFetchRequest, sectionNameKeyPath: String?, cacheName: String?) {
        super.init(
            fetchRequest:           fetchRequest,
            managedObjectContext:   CdManagedObjectContext.mainThreadContext(),
            sectionNameKeyPath:     sectionNameKeyPath,
            cacheName:              cacheName)
    }
 
    
    /*
     *  ----------------- Automated Table Delegation -----------------
     */
    
    /**       
     This holds the table view that is being controlled by our automation.  
     This is a weak reference so be sure the table is retained elsewhere.
     */
    internal weak var _controlledTable: UITableView? = nil
    
    /**
     Use this method to attach the receiver as its own delegate.  The 
     intercepted delegate methods perform standard table manipulations
     on a UITableView whose section/row data is mapped to the results
     of the fetched results controller.
     
     To cancel this automated delegate, you can simply set the receiver's
     delegate back to nil, or some other value other than itself.
     
     - parameter table: The table to delegate for.  This is held in a weak
                        reference, so the table must be retained elsewhere.
     */
    public func automateDelegation(forTable table: UITableView) {
        _controlledTable = table
        self.delegate    = self
    }
    
}

// MARK: - NSFetchedResultsControllerDelegate

extension CdFetchedResultsController : NSFetchedResultsControllerDelegate {
    
    public func controllerWillChangeContent(controller: NSFetchedResultsController) {
        _controlledTable?.beginUpdates()
    }
    
    public func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:   _controlledTable?.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:   _controlledTable?.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default:        return
        }
    }
    
    public func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:   _controlledTable?.insertRowsAtIndexPaths([newIndexPath!],  withRowAnimation: .Fade)
        case .Delete:   _controlledTable?.deleteRowsAtIndexPaths([indexPath!],     withRowAnimation: .Fade)
        case .Update:   _controlledTable?.reloadRowsAtIndexPaths([indexPath!],     withRowAnimation: .Automatic)
        case .Move:     _controlledTable?.deleteRowsAtIndexPaths([indexPath!],     withRowAnimation: .Fade)
                        _controlledTable?.insertRowsAtIndexPaths([newIndexPath!],  withRowAnimation: .Fade)
        }
    }
    
    public func controllerDidChangeContent(controller: NSFetchedResultsController) {
        _controlledTable?.endUpdates()
    }
}

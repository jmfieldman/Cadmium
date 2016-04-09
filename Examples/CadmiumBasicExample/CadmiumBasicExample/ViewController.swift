//
//  ViewController.swift
//  CadmiumBasicExample
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

import UIKit
import CoreData
import Cadmium

class ViewController: UITableViewController {
    
    var fetchedResultsController: CdFetchedResultsController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = "Cadmium Example"
        
        self.navigationItem.leftBarButtonItem  = UIBarButtonItem(title: "Add",  style: .Plain, target: self, action: #selector(handleAdd(_:)))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .Plain, target: self, action: #selector(handleEdit(_:)))
    
        /* Create a fetched results controller that will list all of our example items  (sorted by name) */
        fetchedResultsController = CdFetchedResultsController(
            fetchRequest: Cd.objects(ExampleItem.self).sorted("name").nsFetchRequest,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        fetchedResultsController?.delegate = self
        
        /* Call performFetch to initiate the controller */
        try! fetchedResultsController?.performFetch()
        
    }
    
    /* Adds an ExampleItem with a random 10-character name */
    func handleAdd(button: UIBarButtonItem) {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        
        for _ in (0..<10) {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let newCharacter = allowedChars[allowedChars.startIndex.advancedBy(randomNum)]
            randomString += String(newCharacter)
        }
        
        /* managed objects must be inserted in a transaction (not the main thread).
           An implicit commit finalizes the transaction after it is finished.  
        
           You can call Cd.cancelImplicitCommit() to disable this implicit commit,
           which is useful if you are canceling any changes made during the transaction.
        
           You can call Cd.commit() anytime to explicitly save any changes in the transaction
           up to the call. */
        Cd.transact {
            let newItem = try! Cd.create(ExampleItem.self)
            newItem.name = randomString
            
            let newOther = try! Cd.create(OtherItem.self)
            newOther.prop = 1
            
            newOther.myExample = newItem
            newItem.myOther    = newOther
            
            try! Cd.commit()
            
            dispatch_async(dispatch_get_main_queue()) {
                let mainItem = Cd.useInCurrentContext(newItem)
                print("mainItem \(mainItem!.name)")
            }
        }
    }
    
    func handleEdit(button: UIBarButtonItem) {
        self.tableView.setEditing(!self.tableView.editing, animated: true)
        if (self.tableView.editing) {
            button.title = "Done"
            button.style = .Done
        } else {
            button.title = "Edit"
            button.style = .Plain
        }
    }
    
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension ViewController {
    
    /* We don't have sections with table automation, so we can assume the object count is the number of rows. */
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController!.fetchedObjects?.count ?? 0
    }
    
    /* Extract the item from the fetched results controller and display a cell with its information */
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("cell") ?? UITableViewCell(style: .Subtitle, reuseIdentifier: "cell")

        guard let item = fetchedResultsController?.objectAtIndexPath(indexPath) as? ExampleItem else {
            return cell
        }
        
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = "number of taps: \(item.numberTaps)"
        return cell
    }
    
    /* Acquire the item from the fetched results controller at the proper index, and increment its tap count */
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        guard let item = fetchedResultsController?.objectAtIndexPath(indexPath) as? ExampleItem else {
            return
        }
        
        /* The objects from the fetch controller are from the main thread's read-only context.
           They need to be passed into a write transaction to be modified.
           An implicit commit occurs when the transaction is complete and changes are
           written to disk.  The main thread context is notified of this change and
           the fetch controller will updated automatically in the main thread. */
        Cd.transact {
            guard let txItem = Cd.useInCurrentContext(item) else {
                return
            }
            
            txItem.numberTaps += 1
        }
        
    }
    
    // MARK: Editing
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }
    
    /* Attempt to delete the item at the specified index */
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        guard let item = fetchedResultsController?.objectAtIndexPath(indexPath) as? ExampleItem else {
            return
        }
        
        /* Objects can only be deleted in transactions, similar to object modification. */
        Cd.transact {
            guard let txItem = Cd.useInCurrentContext(item) else {
                return
            }
            
            Cd.delete(txItem)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ViewController : NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:   self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:   self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default:        return
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:   self.tableView.insertRowsAtIndexPaths([newIndexPath!],  withRowAnimation: .Fade)
        case .Delete:   self.tableView.deleteRowsAtIndexPaths([indexPath!],     withRowAnimation: .Fade)
        case .Update:   self.tableView.reloadRowsAtIndexPaths([indexPath!],     withRowAnimation: .Automatic)
        case .Move:     self.tableView.deleteRowsAtIndexPaths([indexPath!],     withRowAnimation: .Fade)
                        self.tableView.insertRowsAtIndexPaths([newIndexPath!],  withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
}

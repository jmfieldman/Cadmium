//
//  ViewController.swift
//  CadmiumPromiseExample
//
//  Created by Jason Fieldman on 5/13/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import UIKit
import CoreData
import PromiseKit
import Cadmium

class ViewController: UITableViewController {
    
    var fetchedResultsController: CdFetchedResultsController<ExampleItem>? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        self.title = "Cadmium Example"
        
        self.navigationItem.leftBarButtonItem  = UIBarButtonItem(title: "Add",  style: .plain, target: self, action: #selector(handleAdd(_:)))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(handleEdit(_:)))
        
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
    func handleAdd(_ button: UIBarButtonItem) {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        
        for _ in (0..<10) {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let newCharacter = allowedChars[allowedChars.characters.index(allowedChars.startIndex, offsetBy: randomNum)]
            randomString += String(newCharacter)
        }
        
        /* managed objects must be inserted in a transaction (not the main thread).
        An implicit commit finalizes the transaction after it is finished.
        
        You can call Cd.cancelImplicitCommit() to disable this implicit commit,
        which is useful if you are canceling any changes made during the transaction.
        
        You can call Cd.commit() anytime to explicitly save any changes in the transaction
        up to the call. */
        Cd.transact {
            let newItem: ExampleItem = try! Cd.create(ExampleItem.self)
            newItem.name = randomString
            return newItem
        }.thenOnMainWith { (mainItem: ExampleItem) in
            print("created item in transaction: \(mainItem.name)")
            mainItem.updateHandler = { event in
                print("event occurred on object \(mainItem.name): \(event)")
            }
        }
        
    }
    
    func handleEdit(_ button: UIBarButtonItem) {
        self.tableView.setEditing(!self.tableView.isEditing, animated: true)
        if (self.tableView.isEditing) {
            button.title = "Done"
            button.style = .done
        } else {
            button.title = "Edit"
            button.style = .plain
        }
    }
    
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension ViewController {
    
    /* We don't have sections with table automation, so we can assume the object count is the number of rows. */
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController!.fetchedObjects?.count ?? 0
    }
    
    /* Extract the item from the fetched results controller and display a cell with its information */
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        guard let item = fetchedResultsController?.object(at: indexPath) as? ExampleItem else {
            return cell
        }
        
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = "number of taps: \(item.numberTaps) [/2 since incrementing twice]"
        return cell
    }
    
    /* Acquire the item from the fetched results controller at the proper index, and increment its tap count */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = fetchedResultsController?.object(at: indexPath) as? ExampleItem else {
            return
        }
        
        /* The objects from the fetch controller are from the main thread's read-only context.
        They need to be passed into a write transaction to be modified.
        An implicit commit occurs when the transaction is complete and changes are
        written to disk.  The main thread context is notified of this change and
        the fetch controller will updated automatically in the main thread. */
        Cd.transactWith(item) { txItem in
            txItem.numberTaps += 1
            return txItem
        }.thenTransactWith { (txItem: ExampleItem) in
            txItem.numberTaps += 1
        }
        
    }
    
    // MARK: Editing
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    /* Attempt to delete the item at the specified index */
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard let item = fetchedResultsController?.object(at: indexPath) as? ExampleItem else {
            return
        }
        
        /* Objects can only be deleted in transactions, similar to object modification. */
        Cd.transactWith(item) { txItem in
            Cd.delete(txItem)
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ViewController : NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:   self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:   self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:        return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:   self.tableView.insertRows(at: [newIndexPath!],  with: .fade)
        case .delete:   self.tableView.deleteRows(at: [indexPath!],     with: .fade)
        case .update:   self.tableView.reloadRows(at: [indexPath!],     with: .automatic)
        case .move:     self.tableView.deleteRows(at: [indexPath!],     with: .fade)
        self.tableView.insertRows(at: [newIndexPath!],  with: .fade)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
}

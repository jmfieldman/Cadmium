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
        Cd.transactWith(item) { txItem in
			txItem.numberTaps += 1
            return txItem
        }.thenTransactWith { (txItem: ExampleItem) in
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
		Cd.transactWith(item) { txItem in
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

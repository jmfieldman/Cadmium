//
//  ViewController.swift
//  CadmiumBasicExample
//
//  Created by Jason Fieldman on 3/14/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import UIKit
import CoreData
import Cadmium

class ViewController: UITableViewController {
    
    var fetchedResultsController: CdFetchedResultsController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = "Example"
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .Plain, target: self, action: "handleAdd:")
        
        fetchedResultsController = CdFetchedResultsController(
            fetchRequest: Cd.objects(ExampleItem.self).sorted("name").nsFetchRequest,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        fetchedResultsController?.delegate = self
        try! fetchedResultsController?.performFetch()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func handleAdd(button: UIButton) {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        
        for _ in (0..<10) {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let newCharacter = allowedChars[allowedChars.startIndex.advancedBy(randomNum)]
            randomString += String(newCharacter)
        }
        
        Cd.transact {
            let newItem = Cd.create(ExampleItem.self)
            newItem.name = randomString
            try! Cd.commit()
        }
    }
    
}

extension ViewController {
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController!.fetchedObjects!.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCellWithIdentifier("cell") ?? UITableViewCell(style: .Subtitle, reuseIdentifier: "cell")
        if let item = fetchedResultsController?.objectAtIndexPath(indexPath) as? ExampleItem {
            cell.textLabel?.text = item.name
            cell.detailTextLabel?.text = "number of taps: \(item.numberTaps)"
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if let item = fetchedResultsController?.objectAtIndexPath(indexPath) as? ExampleItem {
            Cd.transact {
                let txItem = Cd.useInTransaction(item)
                txItem.numberTaps += 1
                print("new taps: \(txItem.numberTaps)")
                try! Cd.commit()
            }
        }
        
    }
}

extension ViewController : NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            self.tableView.insertRowsAtIndexPaths([newIndexPath!],  withRowAnimation: UITableViewRowAnimation.Fade)
        case .Delete:
            self.tableView.deleteRowsAtIndexPaths([indexPath!],     withRowAnimation: UITableViewRowAnimation.Fade)
        case .Update:
            self.tableView.reloadRowsAtIndexPaths([indexPath!],     withRowAnimation: UITableViewRowAnimation.Automatic)
        case .Move:
            self.tableView.deleteRowsAtIndexPaths([indexPath!],     withRowAnimation: UITableViewRowAnimation.Fade)
            self.tableView.insertRowsAtIndexPaths([newIndexPath!],  withRowAnimation: UITableViewRowAnimation.Fade)
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:
            self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default:
            return
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
}
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
        
        self.navigationItem.leftBarButtonItem  = UIBarButtonItem(title: "Add",  style: .Plain, target: self, action: "handleAdd:")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .Plain, target: self, action: "handleEdit:")
        
        fetchedResultsController = CdFetchedResultsController(
            fetchRequest: Cd.objects(ExampleItem.self).sorted("name").nsFetchRequest,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        fetchedResultsController?.automateDelegation(forTable: self.tableView)
        try! fetchedResultsController?.performFetch()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func handleAdd(button: UIBarButtonItem) {
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
        guard let item = fetchedResultsController?.objectAtIndexPath(indexPath) as? ExampleItem else {
            return
        }
        
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
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        guard let item = fetchedResultsController?.objectAtIndexPath(indexPath) as? ExampleItem else {
            return
        }
        
        Cd.transact {
            guard let txItem = Cd.useInCurrentContext(item) else {
                return
            }
            
            Cd.delete(txItem)
        }
    }
}

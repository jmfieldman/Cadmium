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
    
    var fetchedResultsController: NSFetchedResultsController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = "Example"
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .Plain, target: self, action: "handleAdd:")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func handleAdd(button: UIButton) {
        Cd.transact {
            let newItem = ExampleItem.create()
            newItem.name = "New"
        }
    }
    
}


extension ViewController {
    
}
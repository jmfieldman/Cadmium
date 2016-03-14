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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}


extension ViewController {
    
}
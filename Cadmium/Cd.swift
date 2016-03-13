//
//  Cd.swift
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


public class Cd {

	/**
     Initiate a database transaction asynchronously on a background thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.
	
     - parameter operation:	This function should be used for transactions that
							operate in a background thread, and may ultimately 
							save back to the database using the Cd.commit() call.
	
							The operation is asynchronous and will not occur on
							the main thread.
     
                            It is important to note that no transactions can occur
                            on the main thread.  This will use a background write
                            context even if initially called from the main thread.
	*/
	public class func transact(operation: Void -> Void) {
		
	}

    /**
     Initiate a database transaction synchronously on the current thread.  A
     new CdManagedObjectContext will be created for the lifetime of the transaction.

     This function cannot be called from the main thread, to prevent potential
     deadlocks.  You can execute fetches and read data on the main thread without
     needing to wrap those operations in a transaction.
     
     - parameter operation:	This function should be used for transactions that
                            should occur synchronously with the current background 
                            thread.  Transactions may ultimately save back to the 
                            database using the Cd.commit() call.
     
                            The operation is synchronous and will block until complete.
                            It may execute in a separate thread than the calling
                            thread.
    */
	public class func transactAndWait(operation: Void -> Void) {
		
	}
	
	/**
	Commit any changes made inside of an active transaction.  Must be called from
	inside Cd.transact or Cd.transactAndWait.
	*/
	public class func commit() {
		
	}
    
       
    
    
}
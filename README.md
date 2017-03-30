![Cadmium](/Assets/Banner.png)

Cadmium is a Core Data framework for Swift that enforces best practices and raises exceptions for common Core Data pitfalls exactly where you make them.

Cadmium was written as a reaction to the complexity of dealing with multiple managed object contexts for standard database-like use cases. It is still important to understand what a managed object context is and how they are used, but for typical CRUD-style usage of Core Data it is a complete nuisance.

With Cadmium, the user never sees a ```NSManagedObjectContext``` or derived class. You interact only with argument-less transactions, and object fetch/manipulation tasks. The contexts are managed in the background, which makes Core Data feel more like Realm.


# Design Goals

* Create a minimalist/concise framework API that provides for most Core Data use cases and guides the user towards best practices.
* Aggressively protect the user from performing common Core Data pitfalls, and raise exceptions immediately on the offending statement rather than waiting for a context save event.

---

Here's an example of a Cadmium transaction that gives all of your employee objects a raise:

```swift
Cd.transact {
    try! Cd.objects(Employee.self).fetch().forEach {
        $0.salary += 10000
    }
}
```

You might notice a few things:

* Transaction usage is dead-simple.  You do not declare any parameters for use inside the block.
* You never have to reference the managed object context, we manage it for you.
* The changes are committed automatically upon completion (you can disable this.)

### What Cadmium is Not

Cadmium is not designed to be a 100% complete wrapper around Core Data.  Some of the much more
advanced Core Data features are hidden behind the Cadmium API.  If you are creating an enterprise-level
application that requires meticulous manipulation of Core Data stores and contexts to optimize heavy lifting, then
Cadmium is not for you.

Cadmium is for you if want a smart wrapper that vastly simplifies most Core Data tasks and warns you
immediately when you inadvertently manipulate data in a way you shouldn't.

# Installing

You can install Cadmium by adding it to your [CocoaPods](http://cocoapods.org/) ```Podfile```:

```ruby
pod 'Cadmium'
```

Or you can use a variety of ways to include the ```Cadmium.framework``` file from this project into your own.

### Swift Version Support

> Swift 3.0: Use Cadmium 1.0

> Swift 2.3: Use Cadmium 0.13.x

> Swift 2.2: Use Cadmium 0.12.x

Cocoapods:

```ruby
pod 'Cadmium', '~> 1.1'  # Swift 3.1 
pod 'Cadmium', '~> 1.0'  # Swift 3.0
pod 'Cadmium', '~> 0.13' # Swift 2.3
pod 'Cadmium', '~> 0.12' # Swift 2.2
```


# How to Use

### Context Architecture

Cadmium uses the same basic context architecture as CoreStore, with a root save context running on a private queue that
has one read-only child context on the main queue and any number of writeable child contexts running on background queues.

![Cadmium Core Data Architecture](/Assets/core_data_arch.png)

This means that your main thread will never bog down on write transactions, and will only be used to merge changes (in memory)
and updating any UI elements dependent on your data.

It also means that you cannot initiate modifications to managed objects on the main thread!  All of your write operations
must exist inside transactions that occur in background threads.  You will need to design your app to support the idea
of asynchronous write operations, which is what you *should* be doing when it comes to database modification.

### Managed Object Model

The creation and use of the managed object model is very similar to typical Core Data flow.  Create your managed object model as
usual, and generate the corresponding ```NSManagedObject``` classes.  Then, simply change the hierarchy so that your class
implementations derive from ```CdManagedObject``` instead of ```NSManagedObject```.

```CdManagedObject``` is a child class of ```NSManagedObject```.

### Initialization

Set up Cadmium with a single initialization call:

```swift
do {
    try Cd.initWithSQLStore(momdInbundleID: nil,
                            momdName:       "MyObjectModel.momd",
                            sqliteFilename: "MyDB.sqlite",
                            options:        nil /* Optional */)
} catch let error {
    print("\(error)")
}
```

This loads the object model, sets up the persistent store coordinator, and initializes important contexts.

If your object model is in a framework (not your main bundle), you'll have to pass the framework's bundle identifier to the first argument.

The ```options```  argument flows through to the options passed in addPersistentStoreWithType: on the NSPersistentStoreCoordinator.

You can pass nil to the sqliteFilename parameter to create an NSInMemoryStoreType database.

### Querying

Cadmium offers a chained query mechanism.  This can be used to query objects from the main thread (for read-only purposes), or from inside a transaction.

Querying starts with ```Cd.objects(..)``` and looks like this:

```swift
do {
    for employee in try Cd.objects(Employee.self)
                          .filter("name = %@", someName)
                          .sorted("salary", ascending: true)
                          // See CdFetchRequest for more functions
                          .fetch() {
        /* Do something */
        print("Employee name: \(employee.name)")
    }
} catch let error {
    print("\(error)")
}
```

You begin by passing the managed object type into the parameter for ```Cd.objects(..)```.  This constructs a ```CdFetchRequest``` for managed objects of that type.

Chain in as many filter/sort/modification calls as you want, and finalize with ```fetch()``` or ```fetchOne()```.  ```fetch()``` returns an array of objects, and ```fetchOne()``` returns a single optional object (```nil``` if none were found matching the filter).

### Transactions

You can only initiate changes to your data from inside of a transaction.  You can initiate a transaction using either:

```swift
Cd.transact {
    //...
}
```

```swift
Cd.transactAndWait {
    //...
}
```

```Cd.transact``` performs the transaction asynchronously (the calling thread continues while the work in the transaction is performed).   ```Cd.transactAndWait``` performs the transaction synchronously (it will block the calling thread until the transaction is complete.)

To ensure best practices and avoid potential deadlocks, you are not allowed to call ```Cd.transactAndWait``` from the main thread (this will raise an exception.)

### Implicit Transaction Commit

When a transaction completes, the transaction context automatically commits any changes you made to the data store.  For most transactions this means you do not need to call any additional commit/save command.

If you want to turn off the implicit commit for a transaction (e.g. to perform a rollback and ignore any changes made), you can call ```Cd.cancelImplicitCommit()``` from inside the transaction.  A typical use case would look like:

```swift
Cd.transact {

    modifyThings()

    if someErrorOccurred {
        Cd.cancelImplicitCommit()
        return
    }

    moreActions()
}
```

You can also force a commit mid-transaction by calling ```Cd.commit()```.  You may want to do this during long transactions when you want to save changes before possibly returning with a cancelled implicit commit.  A use case might look like:

```swift
Cd.transact {

    modifyThingsStepOne()
    Cd.commit() //changes in modifyThingsStepOne() cannot be rolled back!

    modifyThingsStepTwo()

    if someErrorOccurred {
        Cd.cancelImplicitCommit()
        return
    }

    moreActions()
}
```

### Forced Serial Transactions

**NOTE: Advanced Feature**

Core Data, and Cadmium, are asynchronous APIs by nature.  You generally initiate fetches and modify data asynchronously from the main thread.  This
tight coupling with asynchronous behavior may be detrimental if you find that the context modifications you perform often conflict with each other.

For example, take the following transaction that might occur when the user taps a button to visit a place:

```swift
Cd.transact {
    if let place = try! Cd.objects(Place.self).filter("id = %@", myID).fetchOne() {
        place.visits += 1
    }
}
```

What if the user spams the visit button?  Because the transactions occur in separate context queues, it's not 100% guaranteed that ```place.visits```
will increment serially.  There is a remote possibility that a race condition will cause two of these contexts to see ```place.visits``` as the same
value before incrementing.

To help resolve this problem and ensure that transactions are executed serially, you may pass an optional ```serial``` parameter to your
transactions:

```swift
Cd.transact(serial: true) {
    if let place = try! Cd.objects(Place.self).filter("id = %@", myID).fetchOne() {
        place.visits += 1
    }
}
```

This guarantees that your transactions will occur serially (even waiting for the finalized context save) before proceeding to the next one -- thus
your transactions can be considered atomic.   

Note that this atomic behavior is limited to the top-most transaction.  Transactions-inside-transactions are not executed on the serial queue to
prevent deadlocks.

```swift
/* In this odd case, the inside transactAndWait will ignore the serial parameter, since it is already
   inside a transaction.  The prevents deadlocks waiting on the serial queue. */

Cd.transact(serial: true) {
    Cd.transactAndWait(serial: true) {
    }
}
```

It is annoying to pass the serial parameter every time you want this behavior, especially if you want in *most of the time*.  If you want your
transactions to be serial by default, pass ```true``` to the ```serialTX``` parameter in the Cd.init function:

```swift
try Cd.initWithSQLStore(momdInbundleID: "org.fieldman.CadmiumTests",
                        momdName:       "CadmiumTestModel",
                        sqliteFilename: "test.sqlite",
                        serialTX:       true)
```

When you pass ```true``` to the init, you can override this per-transaction by passing ```false``` to the ```serial``` parameter:

```swift
Cd.transact(serial: false) {
    ...
}
```

Not specifying the ```serial``` parameter, or passing ```nil```, will use the default determined during initialization.

Most use cases will be fine setting the default serial usage to true and leaving it at that. You will incur a performance hit with
serial transactions in the cases that you attempt to execute lots of concurrent
or long-running transactions on unrelated objects (since these will all execute serially instead of in parallel).

As an advanced workaround to this issue, if you have many concurrent long-running transactions on different subsets of your
data store, you can pass your own dispatch queue to the ```on``` parameter:

```swift
Cd.transact(on: mySerialDispatchQueue) {
    ...
}
```

The transaction block itself will occur in the context's queue -- but this occurs synchronously in the dispatch queue you
provide.  You can provide different dispatch queues for transactions that affect different objects.

Note that the dispatch queue you provide will target the internal default serial queue, which keeps the save context
synchronized no matter which queues you use.  It also means that any transactions you run on the default serial queue
will block all other queues you may pass in (so avoid running very long transactions on the default serial queue).

### Creating and Deleting Objects

Objects can be created and deleted inside transactions.

```swift
Cd.transact {
    let newEmployee    = try! Cd.create(Employee.self)
    newEmployee.name   = "Bob"
    newEmployee.salary = 10000
}

Cd.transact {
    Cd.delete(try! Cd.objects(Employee.self).filter("name = %@", "Bob").fetch())
}
```                  

You can also delete objects directly from a CdFetchRequest:

```swift
Cd.objects(Employee.self).filter("salary > 100000").delete()
```

If called:

* Outside a transaction: will delete the objects asynchronously in a background transaction.
* Inside a transaction: will perform the delete synchronously inside the transaction.


### Modifying Objects from Other Contexts

You will often need to modify a managed object from one context inside of another context.  The most
common use case is when you want to modify objects you've queried from the main thread (which are read-only).

You can use ```Cd.useInCurrentContext``` to get a copy of the object that is suitable for
modification in the current context:

```swift
/* Acquire a read-only employee object somewhere on the main thread */
guard let employee = try! Cd.objects(Employee.self).fetchOne() else {
    return
}

/* Modify it in a transaction */
Cd.transact {
    guard let txEmployee = Cd.useInCurrentContext(employee) else {
        return
    }

    txEmployee.salary += 10000    
}
```

Note that an object must have been inserted and committed in a transaction before it can be accessed from another context.
If a transient object has not been inserted yet, it will not be available with this method.

If you are only using one object from another context, consider ```Cd.transactWith``` instead:

```swift
/* Acquire a read-only employee object somewhere on the main thread */
guard let employee = try! Cd.objects(Employee.self).fetchOne() else {
    return
}

/* Modify it in a transaction */
Cd.transactWith(employee) { txEmployee in
    if let txEmployee = txEmployee {
        txEmployee.salary += 10000
    }
}
```

You can also pass an array into ```Cd.transactWith``` to get an array of objects in the new context.

### Notifying the Main Thread

Because transactions occur on the transaction context's private queue, calls to ```Cd.commit()``` are synchronous and only
return after the save has propagated to the persistent store.

You can use this fact to notify the main thread that a commit has completed in your transaction:

```swift
Cd.transact {

    modifyThings()
    Cd.commit()

    /* only called after the commit saves up to the persistent store */
    DispatchQueue.main.async {
        notifyOthers()
    }    
}
```

You must also call ```Cd.commit()``` if you want to dispatch objects created in a transaction back to the main thread, since
calling ```Cd.commit()``` will save created objects to the persistent store and give them permanent IDs.

```swift
Cd.transact {
    let newItem = try! Cd.create(ExampleItem.self)
    newItem.name = "Test"

    /* Synchronously saves newItem to the persistent store */
    try! Cd.commit()

    Cd.onMainWith(newItem) { mainItem in
        guard let item = mainItem else {
            return
        }

        print("created item in transaction: \(item.name)")        
    }
}
```

### Fetched Results Controller

For typical uses of ```NSFetchedResultsController```, you should use the built-in subclass ```CdFetchedResultsController```.  This
subclass wraps the normal functionality of ```NSFetchedResultsController``` onto the protected main queue context.

You can use the ```CdFetchedResultsController``` as you would a ```NSFetchedResultsController``` with the following in mind:

* The objects in the fetch results exist in the main thread read-only context and cannot be modified.  Use ```Cd.useInCurrentContext```
to modify them in a transaction.
* You can pass a ```UITableView``` into the ```automateDelegation``` method to perform the standard insert/delete commands on sections and
rows when your fetched results controller has changes.  This can help save a few lines in your own view controllers.

### Using the Update Handler

Every instance of ```CdManagedObject``` has a property called ```updateHandler``` that can store a block to be called when it
is updated.  You may only attach a block to ```updateHandler``` on objects belonging to the main thread context.  This can be
useful in situations where you want to monitor objects without using an ```NSFetchedResultsController```.

An example might look like:

```swift
/* ... from the example above, transferring a new item to the main thread: */
DispatchQueue.main.async {
    if let mainItem = Cd.useInCurrentContext(newItem), name = mainItem.name {
        print("created item in transaction: \(name)")
        mainItem.updateHandler = { event in
            print("event occurred on object \(name): \(event)")
        }
    }
}
```

Be aware that you can only install one ```updateHandler``` per instance.  If you need a solution that requires dispatching to
more listeners, you can use the handler to post a ```NSNotification```, or use another toolkit like ReactiveCocoa (see the
file ```Cadmium+ReactiveCocoa.swift``` in the Examples directory.)


### Aggressively Identifying Coding Pitfalls

Most developers who use Core Data have gone through the same gauntlet of discovering the various pitfalls and complications of creating a multi-threaded Core Data application.  

Even seasoned veterans are still susceptible to the occasional ```1570: The operation couldn’t be completed``` or ```13300: NSManagedObjectReferentialIntegrityError```

Many of the common issues arise because the standard Core Data framework is lenient about allowing code that does the Wrong Thing and only throwing an error on the eventual attempt to save (which may not be proximal to the offending code.)

Cadmium performs aggressive checking on managed object operations to make sure you are coding correctly, and will raise exceptions on the offending lines rather than waiting for a save to occur.

# PromiseKit Extension

You can enable the Cadmium PromiseKit extension by adding

```
pod 'Cadmium/PromiseKit'
```

To your ```Podfile```.  This will enable the following functionality:

### Transaction Promises

With the PromiseKit extension, ```Cd.transact``` and ```Cd.transactWith``` are now given promise-return overrides.  In most
cases the compiler should be able to deduce these as long as you treat the return of the transaction like a promise:

```swift
Cd.transact {
    //...
}.then { _ -> Void in

}

Cd.transactWith(obj) { txObj in
    //...
}.then { _ -> Void in

}
```

The implementation is such that the transaction changes are committed before the promise is fulfilled, so the
transaction promise is fully atomic from the perspective of the promise chain.

Note that the compiler may need you to be somewhat explicit about the promise chain.  If you see odd errors, try
explicitly defining the promise signatures instead of letting the compiler try to infer them (e.g. how the example
above adds ```_ -> Void in``` instead of leaving it empty).

### Transactions Inside the Chain

If you would like to use a transaction inside the promise chain, some more options are available to you:

```swift
firstly {
    somePromise()
}.thenTransact(serial: ..., on: ...) { // Optionally use serial: and on: arguments
    // This block occurs inside a Cadmium transaction
    // Commit is called before the promise is fulfilled.
}.then {

}

// Or use the transactWith variant when the previous
// promise is fulfilled with a CdManagedObject

firstly {
    return employeeVarFromMainThread // <- CdManagedObject
}.thenTransactWith(serial: ..., on: ...) { (employee: Employee) -> Void in
    // This block occurs inside a Cadmium transaction with a
    // version of the argument belonging to the current context.
}.then {

}
```

There are times when you need to funnel a ```CdManagedObject``` from a transaction
back to the main thread.  For this, use ```thenOnMainWith```:

```swift
firstly {
    return employeeVarFromMainThread
}.thenTransactWith(serial: ..., on: ...) { (employee: Employee) -> Employee in
    employee.salary += 10000
    return employee
}.thenOnMainWith { (employee: Employee) -> Void
    // Here, employee is a read-only CdManagedObject from the main thread context.
    print("The salary is \(employee.salary)")
}

```

It should be noted that promise block for ```thenTransactWith``` can receive an optional in the pipe, but does not pass an optional as its block argument.
It is considered a promise error if the fulfillment value to ```thenTransactWith``` is ```nil```,
or if the internal ```Cd.useInCurrentContext``` returns a ```nil``` value.  In these cases the
chain will be rejected with ```CdPromiseError.NotAvailableInCurrentContext(value)```.

![Cadmium](/Assets/Banner.png)

Cadmium is a Core Data framework for Swift that enforces best practices and identifies common Core Data pitfalls exactly where you make them.

### Design Goals

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

# Installing

You can install Cadmium by adding it to your [CocoaPods](http://cocoapods.org/) ```Podfile```:

```ruby
pod 'Cadmium'
```

Or you can use a variety of ways to include the ```Cadmium.framework``` file from this project into your own.

### Initialization

Set up Cadmium with a single initialization call:

```swift
do {
    try Cd.initWithSQLStore(inbundleID: nil, momdName: "MyObjectModel.momd", sqliteFilename: "MyDB.sqlite")
} catch let error {
    print("\(error)")
}
```

This loads the object model, sets up the persistent store coordinator, and initializes important contexts.

If your object model is in a framework (not your main bundle), you'll have to pass the framework's bundle identifier to the first argument.

### Querying

Cadmium offers a chained query mechanism.  This can be used to query objects from the main thread (for read-only purposes), or from inside a transaction.

Querying starts with ```Cd.objects(..)``` and looks like this:

```swift
do {
    let employees = try Cd.objects(Employee.self)
                          .filter("name = %@", someName)
                          .sort("name", ascending: true)
                          .fetch()
    for e in employees {
        // Do something
    }
} catch let error {
    print("\(error)")
}
```

You begin by passing the managed object type into the parameter for ```Cd.objects(..)```.  This constructs a CdFetchRequest for managed objects of that type.

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

### Fetched Results Controller

### Managed Object Context Architecture

Core Data relies on a hierarchy of managed object contexts working in harmony across their respective dispatch queues.  For newcomers to Core Data this can be daunting -- fortunately we handle everything for you!

Cadmium uses a context hierarchy similar to CoreStore:

--insert image--

With this model, write transactions can only use background write contexts.  The main thread is read-only!  This allows the Core Data engine to process the save path entirely in the background, and update the main context incrementally for reads.


### Aggressively Identifying Coding Pitfalls

Most developers who use Core Data have gone through the same gauntlet of discovering the various pitfalls and complications of creating a multi-threaded Core Data application.  

Even seasoned veterans are still susceptible to the occasional ```1570: The operation couldn’t be completed``` or ```13300: NSManagedObjectReferentialIntegrityError```

Many of the common issues arise because the standard Core Data framework is lenient about allowing code that does the Wrong Thing; only throwing an error on the eventual attempt to save (which may not be proximal to the offending code.)

Cadmium performs aggressive checking on managed object operations to make sure you are coding correctly, and will raise exceptions on the offending lines rather than waiting for a save to occur.

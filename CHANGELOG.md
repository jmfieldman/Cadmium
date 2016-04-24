# Cadmium Changelog

## 0.12.1 -- 4/24/16

* Added support for forced serial transactions (See README section on forced serial transactions)

## 0.11.2 -- 4/17/16

* Address issue where newly inserted objects on the main context were not triggering fetched result controller insertion states.

## 0.11.1 -- 4/8/16

* Changed Cd.useInCurrentContext to be less heavy-handed out raising exceptions.  Now allows context-less objects with persistent IDs to be used.
* Added example of above issue to the basic example app (prints out property in the main thread of object created in a transaction)
* Added Updated case for the updateHandler.

## 0.10.3 -- 4/8/16

* Fixed bug that raised an incorrect excpetion during the main thread's merge handler.

## 0.10.2 -- 4/5/16

* Fixed main thread blocking error
* Changed userInfo to use Any as value

## 0.10.1 -- 4/5/16

* Added update handler hook to main-queue objects
* Added userInfo dictionary to CdManagedObject
* Fixed notification key for main thread context

## 0.9.1 -- 4/3/16

* Added support for expressions, grouping, properties and fetching dictionaries instead of managed objects. 
* changed onlyAttr to onlyProperties

## 0.8.4 -- 3/19/16

* Initial Release

//
//  Categorization.swift
//  CategorizationKit
//
//  Created by Johnny Vega on 3/31/19.
//  Copyright © 2019 Johnny Vega. All rights reserved.
//


import Foundation
#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
#else
import AppKit
#endif

/// Predicate typealias
public typealias Predicate<Element> = (Element)->Bool

@objcMembers open class Categorization<Element: Comparable>: NSObject {
    
    /// Array of Elements to categorized
    dynamic private var _items: Array<Element> = []
    dynamic open var items: Array<Element> {
        return _items
    }

    /// Array of items filtered and sorted according to selected category, user filter predidcate
    /// and sort predicate
    private var _itemsForSelectedCategory: Array<Element> = []
    @objc dynamic open var itemsForSelectedCategory: NSArray {
        return _itemsForSelectedCategory as NSArray
    }
    
    /// Array of Categories
    dynamic open var categories: [Category<Element>]!
    
    
    /// A block predicate to determine what Categories are visible in a User Interface
    dynamic open var visibleCategoryPredicate: ((Category<Element>) -> Bool)?
    
    
    /// A block predicate to apply an additonal filter to the categorized elements
    dynamic open var filterPredicate : Predicate<Element> = {element in return true} {
        didSet {
            if selectedCategoryIndex != -1,
                let categoryPredicate = categories[selectedCategoryIndex].predicate {
                finalPredicate = {element in self.filterPredicate(element) && categoryPredicate(element) }
            } else {
                finalPredicate = {element in self.filterPredicate(element) }
            }
            self.recategorizeItems()
        }
    }
    
    
    /// Variable to establish the final predicate to apply
    dynamic private var finalPredicate: Predicate<Element>!

    
    /// Selected Category Index
    @objc dynamic open var selectedCategoryIndex: Int = -1 {
        didSet {
            if  selectedCategoryIndex != -1,
                let categoryPredicate = categories[selectedCategoryIndex].predicate {
                finalPredicate = {element in self.filterPredicate(element) && categoryPredicate(element) }
            } else {
                finalPredicate = {element in self.filterPredicate(element) }
            }
            self.recategorizeItems()
        }
    }
    
    
    /// Array with category Titles
    dynamic private var categoryTitles: [String: Category<Element>]!
    
    
    /// Boolean to establish if categorized items should be sorted
    @objc dynamic open var isSorted: Bool = false {
        didSet {
            if isSorted {
                if self.sortPredicate == nil {
                    self.sortPredicate = { $0 < $1}
                }
                self.willChangeValue(forKey: #keyPath(itemsForSelectedCategory))
                try? self._itemsForSelectedCategory.sort(by: self.sortPredicate!)
                #if os(iOS) || targetEnvironment(macCatalyst)
                for (table,section) in tableViews {
                    table.reloadSections(IndexSet(integer: section), with: .automatic)
                }
                #else
                for (table,_) in tableViews {
                    table.reloadData()
                }
                #endif
                self.didChangeValue(forKey: #keyPath(itemsForSelectedCategory))
            }
        }
    }
    
    
    /// Block predicate with condition to sort categorized items
    dynamic open var sortPredicate: ((Element, Element) throws -> Bool)? {
        didSet {
            if sortPredicate != nil && self.isSorted {
                self.willChangeValue(forKey: #keyPath(itemsForSelectedCategory))
                try? self._itemsForSelectedCategory.sort(by: self.sortPredicate!)
                #if os(iOS) || targetEnvironment(macCatalyst)
                for (table,section) in tableViews {
                    table.reloadSections(IndexSet(integer: section), with: .automatic)
                }
                #else
                for (table,_) in tableViews {
                    table.reloadData()
                }
                #endif
                self.didChangeValue(forKey: #keyPath(itemsForSelectedCategory))
            }
        }
    }
    
    /// Table Views registered
    #if os(iOS) || targetEnvironment(macCatalyst)
    private var tableViews = [(UITableView,Int)]()
    
    public func registerTableView(_ tableView: UITableView, forSection section: Int) {
        tableViews.append((tableView,section))
    }
    
    public func deregisterTableView(_ tableView: UITableView, forSection section: Int) {
        tableViews.removeAll(where: {$0 == (tableView,section) })
    }
    
    #else
    private var tableViews = [(NSTableView,IndexSet)]()
    
    public func registerTableView(_ tableView: NSTableView, forColumns columns: IndexSet) {
        tableViews.append((tableView,columns))
    }
    
    public func deregisterTableView(_ tableView: NSTableView, forColumns columns: IndexSet) {
        tableViews.removeAll(where: {$0 == (tableView, columns) })
    }
    
    #endif
    
    /// Set (initialize) categorized items
    ///
    /// - parameter items: Array of Elements to categorize
    ///
    open func setItems(_ items: [Element]) {
        self._items = items
        self.recategorizeItems()
    }
    
    
    /// Update categorized items
    ///
    /// - parameter items: Array of Elements to update the items categorized
    ///
    open func updateItems(with items: [Element]) {
        for object in items {
            if let index = self.items.firstIndex(of: object) {
                self._items[index] = object
            } else {
                self._items.insert(object, at: 0)
            }
            if let index1 = self._itemsForSelectedCategory.firstIndex(of: object) {
                if self.finalPredicate(object) {
                    self.willChange(.replacement, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                    self._itemsForSelectedCategory[index1] = object
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.reloadRows(at: [IndexPath(row: index1, section: section)], with: .none)
                    }
                    #else
                    for (table,columns) in tableViews {
                        table.reloadData(forRowIndexes: IndexSet(integer: index1), columnIndexes: columns)
                    }
                    #endif
                    self.didChange(.replacement, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                } else {
                    self.willChange(.removal, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                    self._itemsForSelectedCategory.remove(at: index1)
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.deleteRows(at: [IndexPath(row: index1, section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.beginUpdates()
                        table.removeRows(at: IndexSet(integer: index1), withAnimation:  .effectFade)
                        table.endUpdates()
                    }
                    #endif
                    self.didChange(.removal, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                }
            } else if self.finalPredicate(object) {
                if self.sortPredicate != nil && self.isSorted,
                    let index = self._itemsForSelectedCategory.firstIndex(where: { item in  try! self.sortPredicate!(object,item) }) {
                    self.willChange(.insertion, valuesAt: IndexSet(integer: 0), forKey: #keyPath(itemsForSelectedCategory))
                    self._itemsForSelectedCategory.insert(object, at: index)
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.insertRows(at: [IndexPath(row: index, section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.insertRows(at: IndexSet(integer: index), withAnimation: .effectGap)
                    }
                    #endif
                    self.didChange(.insertion, valuesAt: IndexSet(integer: 0), forKey: #keyPath(itemsForSelectedCategory))
                } else {
                    self.willChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), forKey: #keyPath(itemsForSelectedCategory))
                    self._itemsForSelectedCategory.append(object)
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.insertRows(at: [IndexPath(row: table.numberOfRows(inSection: section), section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.removeRows(at: IndexSet(integer: table.numberOfRows), withAnimation:  .effectFade)
                    }
                    #endif
                    self.didChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), forKey: #keyPath(itemsForSelectedCategory))
                }
            }
        }
    }
    
    
    /// Return number of Items in on particular category
    ///
    /// - parameter title: Category title
    ///
    open func numberOfItemsInCategory(withTitle title: String) -> Int {
        if let category = categoryTitles[title] {
            let finalPredicate: Predicate = {element in self.filterPredicate (element) && category.predicate(element)}
            return items.filter(finalPredicate).count
        }
        return 0
    }
    
    
    /// Return number of Items part of a particular category
    ///
    /// - parameter index: Category position in the Categories array
    ///
    open func numberOfItemsInCategory(atPosition index:Int) -> Int {
        
        if let categoryPredicate = categories[index].predicate {
            let finalPredicate: Predicate = {element in self.filterPredicate (element) && categoryPredicate(element)}
            return items.filter(finalPredicate).count
        }
        return 0
    }
    
    
    /// A boolean value that determine if a partcular Category should be visible
    /// in the End User interface.  True is category should be visible, false otherwise
    ///
    /// - parameter title: Category title
    ///
    open func isVisibleCategory(withTitle title: String) -> Bool? {
        if let category = categoryTitles[title] {
            return visibleCategoryPredicate?(category)
        }
        return nil
    }
    
    
    /// A boolean value that determine if a partcular Category should be visible
    /// in the End User interface.  True is category should be visible, false otherwise
    ///
    /// - parameter index: position in the Categories Array
    ///
    open func isVisibleCategory(atPosition index: Int) -> Bool? {
        return visibleCategoryPredicate?(categories[index])
    }
        
    
    /// Return Array of Items part of a particular Category
    ///
    /// - parameter title: Category title
    ///
    open func itemsforCategory(withTitle title: String) -> [Element] {
        var items = [Element]()
        if let category = categoryTitles[title] {
            let finalPredicate: Predicate = {element in self.filterPredicate (element) && category.predicate(element)}
            items = self.items.filter(finalPredicate)
        }
        if self.isSorted {
            do {
                try items.sort(by: sortPredicate!)
            } catch {}
        }
        return items
    }
    
    
    /// Return Array of Items part of a particular Category
    ///
    /// - parameter index: position in the Categories Array
    ///
    open func itemsforCategory(atPosition index: Int) -> [Element] {
        var items = [Element]()
        if let categoryPredicate = categories[index].predicate {
            let finalPredicate: Predicate = {element in self.filterPredicate (element) && categoryPredicate(element)}
            items = self.items.filter(finalPredicate)
        }
        if self.isSorted {
            do {
                try items.sort(by: sortPredicate!)
            } catch {}
        }
        return items
    }
    
    
    /// Derived Items according to selected category, applying any existing filter predicate
    /// and sorting final items according to sort predicate
    ///
    open func recategorizeItems() {
        var items = self.items.filter(self.finalPredicate)
        if self.isSorted {
            do {
                try items.sort(by: self.sortPredicate!)
            } catch {}
        }
        self.willChangeValue(forKey: #keyPath(itemsForSelectedCategory))
        self._itemsForSelectedCategory = items
        #if os(iOS) || targetEnvironment(macCatalyst)
        for (table,section) in tableViews {
            table.reloadSections(IndexSet(integer: section), with: .automatic)
        }
        #else
        for (table,_) in tableViews {
            table.reloadData()
        }
        #endif
        self.didChangeValue(forKey: #keyPath(itemsForSelectedCategory))
    }
    
    
    /// Update a particular Item
    ///
    /// - parameter itemInfo: Item with new information to update
    ///
    open func updateItem(_ item: Element) {
        if let index = items.firstIndex(of: item) {
            self._items[index] = item
        }
        if let index1 = self._itemsForSelectedCategory.firstIndex(of: item) {
            self.willChange(.replacement, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
            self._itemsForSelectedCategory[index1] = item
            self.didChange(.replacement, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
            #if os(iOS) || targetEnvironment(macCatalyst)
            for (table,section) in tableViews {
                table.reloadRows(at: [IndexPath(row: index1, section: section)], with: .none)
            }
            #else
            for (table,columns) in tableViews {
                table.reloadData(forRowIndexes: IndexSet(integer: index1), columnIndexes: columns)
            }
            #endif
        }
    }
    
    
    /// Removes all Items that satisfy the given predicate.
    ///
    /// - parameter condition: A closure that takes an Element as its argument
    /// and returns a Boolean value indicating whether the element should be removed.
    ///
    open func removeItems(where condition: (Element) -> Bool) {
        self._items.removeAll(where: condition)
        let itemsToRemove = self._itemsForSelectedCategory.filter(condition)
        for item in itemsToRemove {
            if let index = self._itemsForSelectedCategory.firstIndex(of: item) {
                self.willChange(.removal, valuesAt: IndexSet(integer: index), forKey: #keyPath(itemsForSelectedCategory))
                self._itemsForSelectedCategory.remove(at: index)
                #if os(iOS) || targetEnvironment(macCatalyst)
                for (table,section) in tableViews {
                    table.deleteRows(at: [IndexPath(row: index, section: section)], with: .left)
                }
                #else
                for (table,_) in tableViews {
                    table.removeRows(at: IndexSet(integer: index), withAnimation:  .effectFade)
                }
                #endif
                self.didChange(.removal, valuesAt: IndexSet(integer: index), forKey: #keyPath(itemsForSelectedCategory))
            }
        }
    }
    
    
    /// Add an Item into the categorized item list according to category criteria and sorting condition
    ///
    /// - parameter item: The Item to add
    ///
    open func insertItem(_ item: Element) {
        self._items.append(item)
        if self.finalPredicate(item) {
            if self.sortPredicate != nil,
                self.isSorted,
                let index = self._itemsForSelectedCategory.firstIndex(where: { item in  try! self.sortPredicate!(item,item) }) {
                self.willChange(.insertion, valuesAt: IndexSet(integer: index), forKey: #keyPath(itemsForSelectedCategory))
                self._itemsForSelectedCategory.insert(item, at: index)
                #if os(iOS) || targetEnvironment(macCatalyst)
                for (table,section) in tableViews {
                    table.insertRows(at: [IndexPath(row: index, section: section)], with: .left)
                }
                #else
                for (table,_) in tableViews {
                    table.insertRows(at: IndexSet(integer: index), withAnimation: .effectGap)
                }
                #endif
                self.didChange(.insertion, valuesAt: IndexSet(integer: 0), forKey: #keyPath(itemsForSelectedCategory))
            } else {
                self.willChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), forKey: #keyPath(itemsForSelectedCategory))
                self._itemsForSelectedCategory.append(item)
                #if os(iOS) || targetEnvironment(macCatalyst)
                for (table,section) in tableViews {
                    table.insertRows(at: [IndexPath(row: table.numberOfRows(inSection: section), section: section)], with: .left)
                }
                #else
                for (table,_) in tableViews {
                    table.insertRows(at: IndexSet(integer: table.numberOfRows), withAnimation: .effectGap)
                }
                #endif
                self.didChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), forKey: #keyPath(itemsForSelectedCategory))
            }
        }
    }
    
    
    /// Initializer
    public override init() {
        self._items = []
        super.init()
        self.categories = [Category]()
        self.filterPredicate  = {element in return true}
    }
    
    
    /// Initializer
    ///
    /// - parameter items: Items to Categorized
    /// - parameter categories: Array of Categories
    ///
    public init(withItems items:[Element], withCategories categories: [Category<Element>], andUserFilter filter: @escaping Predicate<Element> = {element in return true}) {
        self._items = items
        super.init()
        self.categories = categories
        categoryTitles = [:]
        for category in categories {
            categoryTitles[category.title] = category
        }
        self.filterPredicate  = filter
    }
    
    
    /// Return Array of visible Categories
    ///
    open var visibleCategories: [Category<Element>] {
        return categories.filter(visibleCategoryPredicate ?? {_ in true} )
    }
    
    
    /// Return Number of visible Categories
    ///
    open var numberOfVisibleCategories: Int {
        return self.visibleCategories.count
    }
    
    
    class func keyPathsForValuesAffectingItemsforSelectedCategory() -> Set<AnyHashable>? {
        return Set<AnyHashable>(["items","selectedCategoryIndex","categories","sortPredicate","isSorted"])
    }
    
}

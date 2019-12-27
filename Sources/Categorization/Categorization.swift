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

/// Protocol TableViewDataCell Protocol
/// TableViewCell's objects conforming to the TableViewDataCell Protocol must implement the
/// update(withItem:) method.  This method is called during the update process of the
/// TableView.  If the TableViewCell returned by the TableView does not conform to this
/// Protocol, then the TableView Rows are reloaded instead of updated.
///
#if os(iOS) || targetEnvironment(macCatalyst)
@objc public protocol TableViewDataCell where Self: UITableViewCell {
    /// Update the UITableViewCell wuth the corresponding data provided by the item Object.
    /// - parameter item: TableView Datasource item with the data to update the CellView
    @objc func update(withItem item: Any)
}
#else
@objc public protocol TableViewDataCell where Self: NSTableCellView {
    /// Update the NSTableViewCell wuth the corresponding data provided by the item Object.
    /// - parameter item: TableView Datasource item with the data to update the CellView
    @objc func update(withItem item: Any)
    
    /// Return true if Table Cell Row View is selected
    @objc dynamic var isSelected: Bool {get set}
}
#endif

@objc public protocol CategoryElement where Self: AnyObject {
    @objc func update(with item: AnyObject)
}


/// Categorization Class
@objcMembers open class Categorization<Element: AnyObject & Comparable & Hashable>: NSObject {

    public typealias Predicate = (Element) ->Bool
    
    /// Array of Elements to categorized
    dynamic private var _items: Array<Element> = [Element]()
    dynamic open var items: Array<Element> {
        return _items
    }
    
    /// Array of items filtered and sorted according to selected category, user filter predidcate
    /// and sort predicate
    private var _itemsForSelectedCategory: Array<Element> = []
    @objc open var itemsForSelectedCategory: Array<AnyObject>  {
        return _itemsForSelectedCategory
    }
    
    /// Array of Categories
    dynamic open var categories: [Category<Element>]!
    
    
    /// A block predicate to determine what Categories are visible in a User Interface
    dynamic open var visibleCategoryPredicate: ((Category<Element>) -> Bool)?
    
    
    /// A block predicate to apply an additonal filter to the categorized elements
    dynamic open var filterPredicate : Predicate = {element in return true} {
        didSet {
            if selectedCategoryIndex != -1 {
                let categoryPredicate = categories[selectedCategoryIndex].predicate
                finalPredicate = {element in self.filterPredicate(element) && categoryPredicate(element) }
            } else {
                finalPredicate = {element in self.filterPredicate(element) }
            }
            self.recategorizeItems()
        }
    }
    
    
    /// Variable to establish the final predicate to apply
    dynamic private var finalPredicate: Predicate!
    
    
    /// Selected Category Index
    @objc dynamic open var selectedCategoryIndex: Int = -1 {
        didSet {
            if  selectedCategoryIndex != -1 {
                let categoryPredicate = categories[selectedCategoryIndex].predicate
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
                for (table,columns) in tableViews {
                    table.reloadData()
                    self.selectionIndexes = table.selectedRowIndexes
                    for index in self.selectionIndexes {
                        for column in columns {
                            if let cell = table.view(atColumn: column, row: index, makeIfNecessary: false) as? TableViewDataCell {
                                cell.isSelected = true
                            }
                        }
                    }
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
                self._itemsForSelectedCategory = self.sortItems(self._itemsForSelectedCategory)
                #if os(iOS) || targetEnvironment(macCatalyst)
                for (table,section) in tableViews {
                    table.reloadSections(IndexSet(integer: section), with: .automatic)
                }
                #else
                for (table,columns) in tableViews {
                    table.reloadData()
                    self.selectionIndexes = table.selectedRowIndexes
                    for index in self.selectionIndexes {
                        for column in columns {
                            if let cell = table.view(atColumn: column, row: index, makeIfNecessary: false) as? TableViewDataCell {
                                cell.isSelected = true
                            }
                        }
                    }
                }
                #endif
                self.didChangeValue(forKey: #keyPath(itemsForSelectedCategory))
            }
        }
    }
    
    private var _selectedObjects = [Int:Element]()
    /// Indexes for currently selected categorized items
    ///
    
    @objc dynamic open var selectedItems: Array<AnyObject> {
        return _selectedObjects.values.map{ $0 }
    }
    
    @objc dynamic open var selectionIndexes = IndexSet() {
        didSet {
            #if os(iOS) || targetEnvironment(macCatalyst)
            #else
            // Unflag previous TableView Cell
            for i in oldValue.subtracting(self.selectionIndexes) {
                for (tableView, columns) in self.tableViews {
                    for column in columns {
                        if i < tableView.numberOfRows {
                            if let cell = tableView.view(atColumn: column, row: i, makeIfNecessary: false) as? TableViewDataCell {
                                cell.isSelected = false
                            }
                        }
                    }
                }
                _selectedObjects[i] = nil
            }
             // Flag actual selected TableView Cell

            for i in selectionIndexes.subtracting(oldValue) {
                for (tableView, columns) in self.tableViews {
                    for column in columns {
                        if i < tableView.numberOfRows {
                            if let cell = tableView.view(atColumn: column, row: i, makeIfNecessary: false) as? TableViewDataCell {
                                cell.isSelected = true
                            }
                        }
                    }
                }
                _selectedObjects[i] = _itemsForSelectedCategory[i]
            }
            #endif
        }
    }
    
    
    /// Table Views registered
    #if os(iOS) || targetEnvironment(macCatalyst)
    private var tableViews = [(UITableView,Int)]()
    
    public func registerTableView(_ tableView: UITableView, forSection section: Int) {
        tableViews.append((tableView,section))
        if !(self._itemsForSelectedCategory.isEmpty) {
            tableView.reloadData()
        }
    }
    
    public func deregisterTableView(_ tableView: UITableView, forSection section: Int) {
        tableViews.removeAll(where: {$0 == (tableView,section) })
    }
    
    #else
    private var tableViews = [(NSTableView,IndexSet)]()
    
    public func registerTableView(_ tableView: NSTableView, forColumns columns: IndexSet) {
        tableViews.append((tableView,columns))
        tableView.bind(.selectionIndexes, to: self, withKeyPath: #keyPath(selectionIndexes), options: [NSBindingOption.validatesImmediately: true])
        if !(self._itemsForSelectedCategory.isEmpty) {
            tableView.reloadData()
            self.selectionIndexes = tableView.selectedRowIndexes
            for index in self.selectionIndexes {
                for column in columns {
                    if let cell = tableView.view(atColumn: column, row: index, makeIfNecessary: false) as? TableViewDataCell {
                        cell.isSelected = true
                    }
                }
            }
        }
    }
    
    public func deregisterTableView(_ tableView: NSTableView, forColumns columns: IndexSet) {
        tableViews.removeAll(where: {$0 == (tableView, columns) })
        tableView.unbind(.selectionIndexes)
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
        if self._items.isEmpty {
            self._items = items
            self.recategorizeItems()
        } else {
            for object in items {
                if let index = self.items.firstIndex(of: object) {
                    self._items[index] = object
                } else {
                    self._items.insert(object, at: 0)
                }
                if let index1 = self._itemsForSelectedCategory.firstIndex(of: object) {
                    var index2: Int?
                    if self.finalPredicate(object) {
                        self.willChange(.setting, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                        self._itemsForSelectedCategory[index1] = object
                        if self.isSorted,
                            index1 < self._itemsForSelectedCategory.count - 1,
                            self._itemsForSelectedCategory.count > 1,
                            !((try? self.sortPredicate!(object,self._itemsForSelectedCategory[self._itemsForSelectedCategory.index(after: index1)])) ?? true) {
                            try? self._itemsForSelectedCategory.sort(by: self.sortPredicate!)
                            index2 = self._itemsForSelectedCategory.firstIndex(of: object)
                            let indexes = IndexSet(integersIn: index1 < index2! ? index1...index2! : index2!...index1)
                            self.willChange(.replacement, valuesAt:
                                indexes, forKey: #keyPath(itemsForSelectedCategory))
                            self.didChange(.replacement, valuesAt: indexes, forKey: #keyPath(itemsForSelectedCategory))
                        }
                        if index2 != nil && selectionIndexes.contains(index1) {
                            self.willChangeValue(forKey: #keyPath(selectionIndexes))
                            self.willChangeValue(forKey: #keyPath(selectedItems))
                            self.selectionIndexes.remove(index1)
                            self._selectedObjects[index1] = nil
                            self.selectionIndexes.insert(index2!)
                            self._selectedObjects[index2!] = object
                            self.didChangeValue(forKey: #keyPath(selectedItems))
                        }
                        self.didChange(.setting, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                        #if os(iOS) || targetEnvironment(macCatalyst)
                        for (table,section) in self.tableViews {
                            if let cell = table.cellForRow(at: IndexPath(row: index1, section: section)) as? TableViewDataCell {
                                cell.update(withItem: object)
                            } else {
                                table.reloadRows(at: [IndexPath(row: index1, section: section)], with: .automatic)
                            }
                        }
                        #else
                        for (table,columns) in self.tableViews {
                            var indexes = IndexSet()
                            let index2 = self._itemsForSelectedCategory.firstIndex(of: object)
                            if index2 == index1 {
                                for column in columns {
                                    if let cell = table.view(atColumn: column, row: index1, makeIfNecessary: false) as? TableViewDataCell {
                                        cell.update(withItem: object)
                                    } else {
                                        table.reloadData(forRowIndexes: IndexSet(integer: index1), columnIndexes: IndexSet(integer: column))
                                    }
                                }
                                continue
                            }
                            if  index2 != nil,
                                index2 != index1 {
                                indexes = IndexSet(integersIn: index1 < index2! ? index1...index2! : index2!...index1)
                            }
                            else {
                                indexes = IndexSet(integer: index1)
                            }
                            for column in columns {
                                table.reloadData(forRowIndexes: indexes, columnIndexes: IndexSet(integer: column))
                            }
                        }
                        #endif
                        
                } else {
                    self.willChange(.removal, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                    self._itemsForSelectedCategory.remove(at: index1)
                        if selectionIndexes.contains(index1) {
                            self.willChangeValue(forKey: #keyPath(selectionIndexes))
                            self.willChangeValue(forKey: #keyPath(selectedItems))
                            self.selectionIndexes.remove(index1)
                            self._selectedObjects[index1] = nil
                            self.didChangeValue(forKey: #keyPath(selectionIndexes))
                            self.didChangeValue(forKey: #keyPath(selectedItems))
                        }
                    self.didChange(.removal, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.deleteRows(at: [IndexPath(row: index1, section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.removeRows(at: IndexSet(integer: index1), withAnimation:  .effectFade)
                    }
                    #endif
                    
                }
            } else if self.finalPredicate(object) {
                if self.sortPredicate != nil && self.isSorted,
                    let index = self._itemsForSelectedCategory.firstIndex(where: { item in  try! self.sortPredicate!(object,item) }) {
                    self.willChange(.insertion, valuesAt: IndexSet(integer: 0), forKey: #keyPath(itemsForSelectedCategory))
                    self._itemsForSelectedCategory.insert(object, at: index)
                    self.didChange(.insertion, valuesAt: IndexSet(integer: 0), forKey: #keyPath(itemsForSelectedCategory))
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.insertRows(at: [IndexPath(row: index, section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.insertRows(at: IndexSet(integer: index), withAnimation: .effectGap)
                    }
                    #endif
                   
                } else {
                    self.willChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), forKey: #keyPath(itemsForSelectedCategory))
                    self._itemsForSelectedCategory.append(object)
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.insertRows(at: [IndexPath(row: table.numberOfRows(inSection: section), section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.insertRows(at: IndexSet(integer: table.numberOfRows), withAnimation:  .effectFade)
                    }
                    #endif
                    self.didChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), forKey: #keyPath(itemsForSelectedCategory))
                }
            }
        }
    }
}
    
    private func sortItems(_ items: [Element]) -> [Element] {
        if  selectedCategoryIndex != -1,
            let category =  self.categories[self.selectedCategoryIndex] as? CompoundCategory<Element>,
            category.isSortedBySubcategories {
            var finalSortedItems = [Element]()
            for subcategory in category.subCategories {
                try? finalSortedItems.append(contentsOf:
                    items.filter(subcategory.predicate).sorted(by: self.sortPredicate!))
            }
           return finalSortedItems
        } else {
            return try! items.sorted(by: self.sortPredicate!)
        }
    }


/// Return number of Items in on particular category
///
/// - parameter title: Category title
///
open func numberOfItemsInCategory(withTitle title: String) -> Int {
    if let category = categoryTitles[title] {
        let finalPredicate: Predicate = {element in self.filterPredicate (element) && category.predicate(element)}
        return _items.filter(finalPredicate).count
    }
    return 0
}


/// Return number of Items part of a particular category
///
/// - parameter index: Category position in the Categories array
///
open func numberOfItemsInCategory(atPosition index:Int) -> Int {
    
    let categoryPredicate = categories[index].predicate
    let finalPredicate: Predicate = {element in self.filterPredicate (element) && categoryPredicate(element)}
    return _items.filter(finalPredicate).count
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
        items = self._items.filter(finalPredicate)
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
    let categoryPredicate = categories[index].predicate
    let finalPredicate: Predicate = {element in self.filterPredicate (element) && categoryPredicate(element)}
    items = self._items.filter(finalPredicate)
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
    self.willChangeValue(forKey: #keyPath(itemsForSelectedCategory))
    let items = self._items.filter(self.finalPredicate)
    if self.isSorted {
        self._itemsForSelectedCategory = self.sortItems(items)
    } else {
        self._itemsForSelectedCategory = items
    }
    if let category = categories[self.selectedCategoryIndex] as? CompoundCategory,
        !(category.isAllowingDuplicates) {
        self._itemsForSelectedCategory.removeDuplicates()
    }
    self.didChangeValue(forKey: #keyPath(itemsForSelectedCategory))
    #if os(iOS) || targetEnvironment(macCatalyst)
    for (table,_) in tableViews {
        //It should be the reloadSections method, but the HeaderView animation triggered by this method is annoying.
        //table.reloadSections(IndexSet(integer: section), with: .automatic)
        table.reloadData()
    }
    #else
    for (table,_) in tableViews {
        table.reloadData()
    }
    #endif
    var newIndexes = IndexSet()
    for (_,item) in _selectedObjects {
        if let index = _itemsForSelectedCategory.firstIndex(of: item) {
            if selectionIndexes.contains(index) {
                _selectedObjects[index] = item
            }
            newIndexes.insert(index)
        }
    }
    self.selectionIndexes = newIndexes
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
        self.willChange(.setting, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
        self._itemsForSelectedCategory[index1]=item
        self.didChange(.setting, valuesAt: IndexSet(integer: index1), forKey: #keyPath(itemsForSelectedCategory))
        #if os(iOS) || targetEnvironment(macCatalyst)
        for (table,section) in tableViews {
            if let cell = table.cellForRow(at: IndexPath(row: index1, section: section)) as? TableViewDataCell {
                cell.update(withItem: item)
            }else {
                table.reloadRows(at: [IndexPath(row: index1, section: section)], with: .automatic)
            }
        }
        #else
        for (table,columns) in tableViews {
            for column in columns {
                guard let cell = table.view(atColumn: column, row: index1, makeIfNecessary: false)  else { continue}
                if let cell = cell as?  TableViewDataCell {
                    cell.update(withItem: item)
                    cell.isSelected = self.selectionIndexes.contains(index1)
                } else {
                    table.reloadData(forRowIndexes: IndexSet(integer: index1), columnIndexes: IndexSet(integer: column))
                }
            }
        }
        #endif
        if self.isSorted,
            let index2 = self._itemsForSelectedCategory.firstIndex(where: { ritem in  try! self.sortPredicate!(item,ritem) }),
            let index3 = self._itemsForSelectedCategory.lastIndex(where: { litem in  try! self.sortPredicate!(litem,item) }),
            !((index3 < index1) && (index1 < index2)) {
            self.moveItem(from: index1, to: index2)
        }
        
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
            let index = self._itemsForSelectedCategory.firstIndex(where: { item1 in  try! self.sortPredicate!(item,item1) }) {
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

/// Move an Item into the categorized item list from one Index Position to another one.
///
/// - parameter source: Source index of item to move
/// - parameter destionation: Destination index
///
open func moveItem(from source: Int, to destination: Int) {
    let item = self._itemsForSelectedCategory[source]
    guard (0..<self._itemsForSelectedCategory.count) ~= source, (0...self._itemsForSelectedCategory.count) ~= destination else { return }
    if source == destination { return }
    let targetIndex = source < destination ? destination - 1 : destination

    self.willChange(.removal, valuesAt: IndexSet(integer: source), forKey: #keyPath(itemsForSelectedCategory))
    self._itemsForSelectedCategory.remove(at: source)
    self.didChange(.removal, valuesAt: IndexSet(integer: source), forKey: #keyPath(itemsForSelectedCategory))
    self.willChange(.insertion, valuesAt: IndexSet(integer: destination), forKey: #keyPath(itemsForSelectedCategory))
    self._itemsForSelectedCategory.insert(item, at: destination)
    self.didChange(.insertion, valuesAt: IndexSet(integer: targetIndex), forKey: #keyPath(itemsForSelectedCategory))
    
    #if os(iOS) || targetEnvironment(macCatalyst)
    for (table,section) in tableViews {
        table.moveRow(at: IndexPath(row: source, section: section), to: IndexPath(row: destination, section: section))
    }
    #else
    for (table,_) in tableViews {
        if table.isRowSelected(source) || table.isRowSelected(destination) {
            table.deselectAll(self)
        }
        table.moveRow(at: source, to: destination)
    }
    #endif
}
    
open func moveItems(from source: IndexSet, to destination: Int) {
    let movingData = source.map{ _itemsForSelectedCategory[$0] }
    let targetIndex = destination - source.filter{ $0 < destination }.count
    self.willChange(.removal, valuesAt: source, forKey: #keyPath(itemsForSelectedCategory))
    for (i, e) in source.enumerated() {
        self._itemsForSelectedCategory.remove(at: e - i)
    }
    self.didChange(.removal, valuesAt: source, forKey: #keyPath(itemsForSelectedCategory))
    self.willChange(.insertion, valuesAt: IndexSet(integer: targetIndex), forKey: #keyPath(itemsForSelectedCategory))
    self._itemsForSelectedCategory.insert(contentsOf: movingData, at: targetIndex)
    self.didChange(.insertion, valuesAt: IndexSet(integer: targetIndex), forKey: #keyPath(itemsForSelectedCategory))
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
public init(withItems items:[Element], withCategories categories: [Category<Element>], andUserFilter filter: @escaping Predicate = {element in return true}) {
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


class func keyPathsForValuesAffectingItemsForSelectedCategory() -> Set<AnyHashable>? {
    return Set<AnyHashable>(["_itemsForSelectedCategory"])
}

}


extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
    
    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}

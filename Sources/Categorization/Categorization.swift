//
//  Categorization.swift
//  CategorizationKit
//
//  Created by Johnny Vega on 3/31/19.
//  Copyright © 2019 Johnny Vega. All rights reserved.
//


import Foundation
import Combine
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

public protocol CategoryItem {
    
    func update(with item: Self)
}

public typealias Categorizable = AnyObject & Comparable & Hashable & Identifiable & CategoryItem

/// Categorization Class

@objcMembers open class Categorization<Element: Categorizable>: NSObject, ObservableObject  {
    

    public typealias Predicate = (Element) ->Bool
    
    /// Array of Elements to categorized
    @Published public private (set) var items: ContiguousArray<Element> = ContiguousArray<Element>()
    
    /// Array of items filtered and sorted according to selected category, user filter predidcate
    /// and sort predicate
    @Published public private (set) var itemsForSelectedCategory: ContiguousArray<Element> = []
    
    /// Array of Categories
    @Published open var categories: [Category<Element>]!
    
    
    /// A block predicate to determine what Categories are visible in a User Interface
    open var visibleCategoryPredicate: ((Category<Element>) -> Bool)?
    
    
    /// A block predicate to apply an additonal filter to the categorized elements
    open var filterPredicate : Predicate = {element in return true} {
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
    @Published public var finalPredicate: ((Element) ->Bool) = {element in return true}
    
    
    /// Selected Category Index
    @Published open var selectedCategoryIndex: Int = -1 {
        didSet {
            if  selectedCategoryIndex != -1 {
                let categoryPredicate = categories[selectedCategoryIndex].predicate
                finalPredicate = {element in self.filterPredicate(element) && categoryPredicate(element) }
            } else {
                finalPredicate = {element in self.filterPredicate(element) }
            }
        }
    }
    
    @objc open func selectCategory(withIndex index: Int) {
        self.selectedCategoryIndex = index
    }
    
    
    /// Array with category Titles
    private var categoryTitles: [String: Category<Element>]!
    
    
    /// Boolean to establish if categorized items should be sorted
    @objc dynamic open var isSorted: Bool = false {
        didSet {
            if isSorted {
                if self.sortPredicate == nil {
                    self.sortPredicate = { $0 < $1}
                }
                //self.willChangeValue(for: \.itemsForSelectedCategory)
                try? self.itemsForSelectedCategory.sort(by: self.sortPredicate!)
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
                //self.didChangeValue(for: \.itemsForSelectedCategory)
            }
        }
    }
    
    
    /// Block predicate with condition to sort categorized items
    open var sortPredicate: ((Element, Element) throws -> Bool)? {
        didSet {
            if sortPredicate != nil  {
                //self.willChangeValue(for: \.itemsForSelectedCategory
                try? self.itemsForSelectedCategory.sort(by: self.sortPredicate!)
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
                //self.didChangeValue(for: \.itemsForSelectedCategory)
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
                _selectedObjects[i] = itemsForSelectedCategory[i]
            }
            #endif
        }
    }
    
    
    /// Table Views registered
    #if os(iOS) || targetEnvironment(macCatalyst)
    private var tableViews = [(UITableView,Int)]()
    
    public func registerTableView(_ tableView: UITableView, forSection section: Int) {
        tableViews.append((tableView,section))
        if !(self.itemsForSelectedCategory.isEmpty) {
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
        if !(self.itemsForSelectedCategory.isEmpty) {
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
        self.itemsForSelectedCategory = ContiguousArray(items)
        try? self.itemsForSelectedCategory.sort(by: self.sortPredicate!)
    }
    
    
    /// Update categorized items
    ///
    /// - parameter items: Array of Elements to update the items categorized
    ///
    open func updateItems(with items: [Element]) {
        if self.itemsForSelectedCategory.isEmpty {
            self.itemsForSelectedCategory = ContiguousArray(items)
        } else {
            for object in items {
                if let index = self.itemsForSelectedCategory.firstIndex(of: object) {
                    self.itemsForSelectedCategory[index].update(with: object)
                    
                } else if self.sortPredicate != nil && self.isSorted,
                    let index1 = self.itemsForSelectedCategory.firstIndex(where: { item in  try! self.sortPredicate!(object,item) }) {
                    self.itemsForSelectedCategory.insert(object, at: index1)
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.insertRows(at: [IndexPath(row: index1, section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.insertRows(at: IndexSet(integer: index1), withAnimation: .effectGap)
                    }
                    #endif
                    
                } else {
                    self.itemsForSelectedCategory.insert(object, at: 0)
                    #if os(iOS) || targetEnvironment(macCatalyst)
                    for (table,section) in tableViews {
                        table.insertRows(at: [IndexPath(row: table.numberOfRows(inSection: section), section: section)], with: .left)
                    }
                    #else
                    for (table,_) in tableViews {
                        table.insertRows(at: IndexSet(integer: table.numberOfRows), withAnimation:  .effectFade)
                    }
                    #endif
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
@objc open func numberOfItemsInCategory(withTitle title: String) -> Int {
    if let category = categoryTitles[title] {
        let finalPredicate: Predicate = {element in self.filterPredicate (element) && category.predicate(element)}
        return itemsForSelectedCategory.filter(finalPredicate).count
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
    return items.filter(finalPredicate).count
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
    let categoryPredicate = categories[index].predicate
    let finalPredicate: Predicate = {element in self.filterPredicate (element) && categoryPredicate(element)}
    items = self.items.filter(finalPredicate)
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
    //self.willChangeValue(for: \.itemsForSelectedCategory)
    var items = self.items.filter(self.finalPredicate)
    if let sortPredicate = self.sortPredicate {
        try? items.sort(by: sortPredicate)
    }
    let seconds: Double = abs(items.count - itemsForSelectedCategory.count) > 1000 ? 0.1: 0.0
    self.itemsForSelectedCategory = []
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, qos:.userInteractive) {
        self.itemsForSelectedCategory = ContiguousArray(items)
       // if let category = self.categories[self.selectedCategoryIndex] as? CompoundCategory,
       //     !(category.isAllowingDuplicates) {
       //     self.itemsForSelectedCategory.removeDuplicates()
       // }
    }
    //self.didChangeValue(for: \.itemsForSelectedCategory)
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
        if let index = itemsForSelectedCategory.firstIndex(of: item) {
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
        DispatchQueue.main.async {
            self.items[index].update(with: item)
        }
    } else {
        self.items.insert(item, at: 0)
    }
    if let index1 = self.itemsForSelectedCategory.firstIndex(of: item) {
        //self.willChange(.setting, valuesAt: IndexSet(integer: index1), for: \.itemsForSelectedCategory)
        DispatchQueue.main.async {
            self.itemsForSelectedCategory[index1].update(with: item)
        }
            
        //self.didChange(.setting, valuesAt: IndexSet(integer: index1), for: \.itemsForSelectedCategory)
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
        
    } else if self.finalPredicate(item) {
        self.itemsForSelectedCategory.insert(item, at: 0)
    }
    let index1 = self.itemsForSelectedCategory.firstIndex(of: item)!
    if self.isSorted,
        let index2 = self.itemsForSelectedCategory.firstIndex(where: { ritem in  try! self.sortPredicate!(item,ritem) }),
        let index3 = self.itemsForSelectedCategory.lastIndex(where: { litem in  try! self.sortPredicate!(litem,item) }),
        !((index3 < index1) && (index1 < index2)) {
        self.moveItem(from: index1, to: index2)
    }
}


/// Removes all Items that satisfy the given predicate.
///
/// - parameter condition: A closure that takes an Element as its argument
/// and returns a Boolean value indicating whether the element should be removed.
///
open func removeItems(where condition: (Element) -> Bool) {
    self.items.removeAll(where: condition)
    let itemsToRemove = self.itemsForSelectedCategory.filter(condition)
    for item in itemsToRemove {
        if let index = self.itemsForSelectedCategory.firstIndex(of: item) {
            //self.willChange(.removal, valuesAt: IndexSet(integer: index), for: \.itemsForSelectedCategory)
            self.itemsForSelectedCategory.remove(at: index)
            #if os(iOS) || targetEnvironment(macCatalyst)
            for (table,section) in tableViews {
                table.deleteRows(at: [IndexPath(row: index, section: section)], with: .left)
            }
            #else
            for (table,_) in tableViews {
                table.removeRows(at: IndexSet(integer: index), withAnimation:  .effectFade)
            }
            #endif
            //self.didChange(.removal, valuesAt: IndexSet(integer: index), for: \.itemsForSelectedCategory)
        }
    }
}


/// Add an Item into the categorized item list according to category criteria and sorting condition
///
/// - parameter item: The Item to add
///
open func insertItem(_ item: Element) {
    self.items.append(item)
    if self.finalPredicate(item) {
        if self.sortPredicate != nil,
            self.isSorted,
            let index = self.itemsForSelectedCategory.firstIndex(where: { item1 in  try! self.sortPredicate!(item,item1) }) {
            //self.willChange(.insertion, valuesAt: IndexSet(integer: index), for: \.itemsForSelectedCategory)
            self.itemsForSelectedCategory.insert(item, at: index)
            #if os(iOS) || targetEnvironment(macCatalyst)
            for (table,section) in tableViews {
                table.insertRows(at: [IndexPath(row: index, section: section)], with: .left)
            }
            #else
            for (table,_) in tableViews {
                table.insertRows(at: IndexSet(integer: index), withAnimation: .effectGap)
            }
            #endif
            //self.didChange(.insertion, valuesAt: IndexSet(integer: 0), for: \.itemsForSelectedCategory)
        } else {
            //self.willChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), for: \.itemsForSelectedCategory)
            self.itemsForSelectedCategory.append(item)
            #if os(iOS) || targetEnvironment(macCatalyst)
            for (table,section) in tableViews {
                table.insertRows(at: [IndexPath(row: table.numberOfRows(inSection: section), section: section)], with: .left)
            }
            #else
            for (table,_) in tableViews {
                table.insertRows(at: IndexSet(integer: table.numberOfRows), withAnimation: .effectGap)
            }
            #endif
            //self.didChange(.insertion, valuesAt: IndexSet(integer: itemsForSelectedCategory.count), for: \.itemsForSelectedCategory)
        }
    }
}

/// Move an Item into the categorized item list from one Index Position to another one.
///
/// - parameter source: Source index of item to move
/// - parameter destionation: Destination index
///
open func moveItem(from source: Int, to destination: Int) {
    let item = self.itemsForSelectedCategory[source]
    guard (0..<self.itemsForSelectedCategory.count) ~= source, (0...self.itemsForSelectedCategory.count) ~= destination else { return }
    if source == destination { return }
    //let targetIndex = source < destination ? destination - 1 : destination

    //self.willChange(.removal, valuesAt: IndexSet(integer: source), for: \.itemsForSelectedCategory)
    self.itemsForSelectedCategory.remove(at: source)
    //self.didChange(.removal, valuesAt: IndexSet(integer: source), for: \.itemsForSelectedCategory)
    //self.willChange(.insertion, valuesAt: IndexSet(integer: destination), for: \.itemsForSelectedCategory)
    self.itemsForSelectedCategory.insert(item, at: destination)
    //self.didChange(.insertion, valuesAt: IndexSet(integer: targetIndex), for: \.itemsForSelectedCategory)
    
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
    let movingData = source.map{ itemsForSelectedCategory[$0] }
    let targetIndex = destination - source.filter{ $0 < destination }.count
    //self.willChange(.removal, valuesAt: source, for: \.itemsForSelectedCategory)
    for (i, e) in source.enumerated() {
        self.itemsForSelectedCategory.remove(at: e - i)
    }
    //self.didChange(.removal, valuesAt: source, for: \.itemsForSelectedCategory)
    //self.willChange(.insertion, valuesAt: IndexSet(integer: targetIndex), for: \.itemsForSelectedCategory)
    self.itemsForSelectedCategory.insert(contentsOf: movingData, at: targetIndex)
    //self.didChange(.insertion, valuesAt: IndexSet(integer: targetIndex), for: \.itemsForSelectedCategory)
}

/// Initializer
public override init() {
    self.items = []
    super.init()
    self.categories = [Category]()
    self.filterPredicate  = {element in return true}
    self.sortPredicate = { e1,e2 in return e1 > e2 }
}


/// Initializer
///
/// - parameter items: Items to Categorized
/// - parameter categories: Array of Categories
///
public init(withItems items:[Element], withCategories categories: [Category<Element>], andUserFilter filter: @escaping Predicate = {element in return true}) {
    super.init()
    self.categories = categories
    categoryTitles = [:]
    for category in categories {
        categoryTitles[category.title] = category
    }
    self.filterPredicate  = filter
    self.items = ContiguousArray(items)
    self.itemsForSelectedCategory = ContiguousArray(items)
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

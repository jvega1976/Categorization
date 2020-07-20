//
//  Categorization.swift
//  CategorizationKit
//
//  Created by Johnny Vega on 3/31/19.
//  Copyright © 2019 Johnny Vega. All rights reserved.
//


import Foundation
import Combine

public protocol CategoryItem {
    func update(with item: Self)
}

public typealias Categorizable = AnyObject &  Comparable & Hashable & Identifiable & CategoryItem

/// Categorization Class

@objcMembers open class Categorization<Element: Categorizable>: NSObject, ObservableObject  {
    

    public typealias Predicate = (Element) ->Bool
    
    /// Array of Elements to categorized
    @Published public private (set) var items: Set<Element> = Set<Element>()
    
    /// Array of items filtered and sorted according to selected category, user filter predidcate
    /// and sort predicate
    @Published public private (set) var itemsForSelectedCategory: Array<Element> = []
    
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
    lazy private var finalPredicate: ((Element) ->Bool) =  {
        return self.filterPredicate
    }()
    
    
    /// Selected Category Index
    @Published open var selectedCategoryIndex: Int = -1 {
        didSet {
            if  selectedCategoryIndex != -1 {
                let categoryPredicate = categories[selectedCategoryIndex].predicate
                finalPredicate = {element in self.filterPredicate(element) && categoryPredicate(element) }
            } else {
                finalPredicate = {element in self.filterPredicate(element) }
            }
            recategorizeItems()
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
                try? self.itemsForSelectedCategory.sort(by: self.sortPredicate!)
            }
        }
    }
    
    
    /// Block predicate with condition to sort categorized items
    open var sortPredicate: ((Element, Element) throws -> Bool)? {
        didSet {
            if sortPredicate != nil  {
                DispatchQueue.main.async {
                    try? self.itemsForSelectedCategory.sort(by: self.sortPredicate!)
                }
            }
        }
    }
    
    
    /// Set (initialize) categorized items
    ///
    /// - parameter items: Array of Elements to categorize
    ///
    open func setItems(_ items: Array<Element>) {
        self.items = Set(items)
        self.recategorizeItems()
    }
    
    
    /// Update categorized items
    ///
    /// - parameter items: Array of Elements to update the items categorized
    ///
    open func updateItems(with items: Array<Element>) {
        if self.items.isEmpty {
            self.items = Set(items)
            self.recategorizeItems()
        } else {
            for object in items {
                if let index = self.items.firstIndex(where: { item in item == object }) {
                    self.items[index].update(with: object)
                } else {
                    let (inserted,newObject) = self.items.insert(object)
                    if self.finalPredicate(object),
                       inserted {
                        if self.isSorted {
                            if self.sortPredicate != nil,
                               let index1 = self.itemsForSelectedCategory.firstIndex(where: { try! self.sortPredicate!(object,$0) }) {
                                self.itemsForSelectedCategory.insert(object, at: index1)
                            } else if self.sortPredicate == nil,
                                let index1 = self.itemsForSelectedCategory.firstIndex(where: { object < $0 }) {
                                self.itemsForSelectedCategory.insert(newObject, at: index1)
                            } else {
                                self.itemsForSelectedCategory.insert(newObject, at: 0)
                            }
                        } else {
                            self.itemsForSelectedCategory.append(newObject)
                        }
                        continue
                    }
                }
                if let index1 = self.itemsForSelectedCategory.firstIndex(of: object),
                   !self.finalPredicate(object) {
                        self.itemsForSelectedCategory.remove(at: index1)
                } else if self.finalPredicate(object),
                          !self.itemsForSelectedCategory.contains(object) {
                    if self.isSorted {
                        if self.sortPredicate != nil,
                           let index1 = self.itemsForSelectedCategory.firstIndex(where: { item in  try! self.sortPredicate!(object,item) }) {
                            self.itemsForSelectedCategory.insert(object, at: index1)
                        } else if let index1 = self.itemsForSelectedCategory.firstIndex(where: { object < $0 }) {
                            self.itemsForSelectedCategory.insert(object, at: index1)
                        } else {
                            self.itemsForSelectedCategory.append(object)
                        }
                    } else {
                        self.itemsForSelectedCategory.append(object)
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
@objc open func numberOfItemsInCategory(withTitle title: String) -> Int {
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
    let items =  self.items.filter(self.finalPredicate)
    if let sortPredicate = self.sortPredicate {
        self.itemsForSelectedCategory = (try? items.sorted(by: sortPredicate)) ?? Array(items)
    }

       // if let category = self.categories[self.selectedCategoryIndex] as? CompoundCategory,
       //     !(category.isAllowingDuplicates) {
       //     self.itemsForSelectedCategory.removeDuplicates()
       // }
}


/// Update a particular Item
///
/// - parameter itemInfo: Item with new information to update
///
open func updateItem(_ item: Element) {
    if objc_sync_enter(self) == OBJC_SYNC_SUCCESS {
        if let object = items.first(where: { $0 == item }) {
            object.update(with: item)
        } else {
            self.items.insert(item)
        }
        if let index1 = self.itemsForSelectedCategory.firstIndex(of: item) {
            self.itemsForSelectedCategory[index1].update(with: item)
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
        //try? self.itemsForSelectedCategory.sort(by: self.sortPredicate!)
        objc_sync_exit(self)
    } else {
        print("TransmissionRemote: Categorization could not lock itemsForSelectedCategory")
    }
}


/// Removes all Items that satisfy the given predicate.
///
/// - parameter condition: A closure that takes an Element as its argument
/// and returns a Boolean value indicating whether the element should be removed.
///
open func removeItems(where condition: (Element) -> Bool) {
    let itemsToRemove = self.items.filter(condition)
    self.items.subtract(itemsToRemove)
    self.itemsForSelectedCategory.removeAll(where: condition)
}


/// Add an Item into the categorized item list according to category criteria and sorting condition
///
/// - parameter item: The Item to add
///
open func insertItem(_ item: Element) {
    self.items.insert(item)
    if self.finalPredicate(item) {
        if self.sortPredicate != nil,
            self.isSorted,
            let index = self.itemsForSelectedCategory.firstIndex(where: { item1 in  try! self.sortPredicate!(item,item1) }) {
            self.itemsForSelectedCategory.insert(item, at: index)
        } else {
            self.itemsForSelectedCategory.append(item)
        }
    }
}

/// Move an Item into the categorized item list from one Index Position to another one.
///
/// - parameter source: Source index of item to move
/// - parameter destionation: Destination index
///
    open func moveItem(from source: Int, to destination: Int) {
        let element = self.itemsForSelectedCategory.remove(at: source)
        self.itemsForSelectedCategory.insert(element, at: destination)
    }
    
open func moveItems(from source: IndexSet, to destination: Int) {
    if objc_sync_enter(self) == OBJC_SYNC_SUCCESS {
        for i in source  {
            let element = self.itemsForSelectedCategory.remove(at: i)
            self.itemsForSelectedCategory.insert(element, at: destination)
        }
        objc_sync_exit(self)
    } else {
        print("TransmissionRemote: Categorization could not lock itemsForSelectedCategory")
    }
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
    self.items = Set(items)
    self.itemsForSelectedCategory = items
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

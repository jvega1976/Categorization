//
//  Categorization.swift
//  CategorizationKit
//
//  Created by Johnny Vega on 3/31/19.
//  Copyright © 2019 Johnny Vega. All rights reserved.
//


import Foundation

/// Predicate typealias
public typealias Predicate<Element> = (Element)->Bool

@objcMembers open class Categorization<Element: Comparable>: NSObject {
    
    /// Array of Elements to categorized
    public var items: Array<Element>!
    
    /// Array of Categories
    public var categories: [Category<Element>]!
    
    /// A block predicate to determine what Categories are visible in a User Interface
    public var visibleCategoryPredicate: ((Category<Element>) -> Bool)?
    
    /// A block predicate to apply an additonal filter to the categorized elements
    public var filterPredicate : Predicate<Element> = {element in return true}
    
    
    private var categoryTitles: [String: Category<Element>]!
    
    public var isSorted: Bool = false {
        didSet {
            if sortPredicate == nil {
                sortPredicate = { $0 < $1}
            }
        }
    }
    
    public var sortPredicate: ((Element, Element) throws -> Bool)?
    
    /// Update categorized items
    ///
    /// - parameter items: Array of Elements to update the items categorized
    ///
    open func updateItems(withArray items: [Element]) {
        
        for object in items {
            if let index = self.items.firstIndex(of: object) {
                self.items[index] = object
            } else {
                self.items.append(object)
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
    
    
    /// Update a particular Item
    ///
    /// - parameter itemInfo: Item with new information to update
    ///
    open func updateItem(withInfo itemInfo:Element) {
        if let index = items.firstIndex(of: itemInfo) {
            items[index] = itemInfo
        }
    }
    
    
    /// Initializer
    public override init() {
        super.init()
        self.categories = [Category]()
        self.items = []
        self.filterPredicate  = {element in return true}
    }
    
    /// Initializer
    ///
    /// - parameter items: Items to Categorized
    /// - parameter categories: Array of Categories
    ///
    public init(withItems items:[Element], withCategories categories: [Category<Element>], andUserFilter filter: @escaping Predicate<Element> = {element in return true}) {
        super.init()
        self.items = items
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
    
}

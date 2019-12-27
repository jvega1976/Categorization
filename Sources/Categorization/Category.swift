//
//  Category.swift
//  CategorizationKit
//
//  CreaCreated by Johnny Vega on 3/31/19.
//  Copyright © 2019 Johnny Vega. All rights reserved.
//


import Foundation

public typealias CategoryDef = Category

/*!
 @class Category
 Categories represent a categorization/grouping of Elements.  Category allow to present the items categorized information based in defined filter criterias.  Example of Categories in the Torrent world could be Active, Downloading, Tracker, etc.
 */
@objcMembers public class Category<Element>: NSObject {
    
    public typealias Element = Comparable
    public typealias Predicate = (Element)->Bool
    /*!
     @property title Title to identify Category. Example: "All", "Downloading", "Seeding", "Stopped", etc.
     */
    @objc dynamic public var title = ""
    
    /*!
     @property predicate Preedicate with the corresponding Category filter criteria
     */
    
    private var _predicate: Predicate!
    dynamic open var predicate: Predicate {
        return self._predicate
    }

    /*!
     @property alwaysVisible  This property determine if the Category will be visible in the final user interface, even if there is not items that satisfy the corresponding Group filter criteria.
     */
    @objc dynamic public var isAlwaysVisible = true
   
    /*!
     @property index Categorys can have an index number to help the arragement of multiple Categoriess
     */
    @objc dynamic public var sortIndex = 0
    
    /*!
     initializer
     */
    @objc public override init() {
        super.init()
        self.title = ""
        self._predicate = {_ in return true}
        self.sortIndex = -1
        self.isAlwaysVisible = false
    }
    
    /*! Convinience init method
         @param title Identifying Category title
         @param predicate  Predicate with group filter label criteria
         @param sortIndex Optional group label sort index
         @param visible  Boolean to establish if label will be always visible in the user interface even if there are not items that satisfy the label group criteria.
         */

    public init(withTitle title: String, filterPredicate predicate: @escaping Predicate, sortIndex index: Int, isAlwaysVisible alwaysVisible: Bool) {
        super.init()
        self.title = title
        self._predicate = predicate
        self.sortIndex = index
        self.isAlwaysVisible = alwaysVisible
    }

}

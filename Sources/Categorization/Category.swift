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
public class Category<Element:Comparable>: NSObject {

    /*!
     @property title Title to identify Category. Example: "All", "Downloading", "Seeding", "Stopped", etc.
     */
    public var title = ""
    
    /*!
     @property predicate Preedicate with the corresponding Category filter criteria
     */
    
    public var predicate: Predicate<Element>!

    /*!
     @property alwaysVisible  This property determine if the Category will be visible in the final user interface, even if there is not items that satisfy the corresponding Group filter criteria.
     */
    public var isAlwaysVisible = false
   
    /*!
     @property index Categorys can have an index number to help the arragement of multiple Categoriess
     */
    public var sortIndex = 0
    
    /*!
     initializer
     */
    public override init() {
        super.init()
        self.title = ""
        self.predicate = {_ in return true}
        self.sortIndex = -1
        self.isAlwaysVisible = false
    }
    
    /*! Convinience init method
         @param title Identifying Category title
         @param predicate  Predicate with group filter label criteria
         @param sortIndex Optional group label sort index
         @param visible  Boolean to establish if label will be always visible in the user interface even if there are not items that satisfy the label group criteria.
         */

    public init(withTitle title: String, filterPredicate predicate: @escaping Predicate<Element>, sortIndex index: Int, isAlwaysVisible alwaysVisible: Bool) {
        super.init()
        self.title = title
        self.predicate = predicate
        self.sortIndex = index
        self.isAlwaysVisible = alwaysVisible
    }

}

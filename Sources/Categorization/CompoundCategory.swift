//
//  File.swift
//  
//
//  Created by  on 12/29/19.
//

import Foundation


@objcMembers public class CompoundCategory<Element: Comparable>: Category<Element> {
    
    public typealias SubCategory = Category<Element>
    public var subCategories = Array<SubCategory>()
    public var isSortedBySubcategories: Bool = false
    public var isAllowingDuplicates: Bool = true

    public init(withTitle title: String, subCategories categories: [SubCategory], sortBySubCategories sortFlag: Bool? = nil, allowingDuplicates allowDuplicates: Bool? = nil) {
        super.init()
        self.subCategories = categories
        self.title = title
        self.isSortedBySubcategories = sortFlag ?? false
        self.isAllowingDuplicates = allowDuplicates ?? true
    }
    
    dynamic override open var predicate: Predicate {
        return { element in
                    return self.subCategories.reduce(false, { prev, category in
                        prev || category.predicate(element) })
                }
    }
    
}

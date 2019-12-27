import XCTest
@testable import Categorization

class Test: NSObject {
    var field1: Int!
    var field2: Bool!
    var field3: String!
    
    init(_ field1:Int, field2:Bool, field3: String) {
        super.init()
        self.field2 = field2
        self.field1 = field1
        self.field3 = field3
    }
    
    public static func == (lhs: Test, rhs: Test) -> Bool {
        return lhs.field1 == rhs.field1
    }
    
    public static func != (lhs: Test, rhs: Test) -> Bool {
        return lhs.field1 != rhs.field1
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        return (object as! Test).field1 == self.field1
    }
    
    open override var hash: Int {
        return self.field1
    }
}


final class CategorizationTests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let object1 = Test(1,field2: true, field3: "Test1")
        let object2 = Test(2,field2: true,field3: "Test2")
        let object3 = Test(3,field2: false,field3: "Test3")
        let object4 = Test(1,field2: false, field3: "Test4")
        var array = [object3, object2, object1]
        print(object1 == object4)
        print(object4 == object2)
        if let index = array.firstIndex(of: object4) {
            array[index] = object4
        }
        print(array)
        print(array.contains(object1))
        print(array.contains(object4))
        
        let p1 = NSPredicate(format: "field2 == true")
        /*let category1 = UICategorization.Ca
        let p2 = NSPredicate(format: "field2 == false")
        let category2 = NSCategory(withTitle: "Cat2", filterPredicate: p2, sortIndex: 1, isAlwaysVisible: true)
        let categories = Categories(categories: [category1,category2])
        
        let categorization = Categorization(forItems: array,withCategories: categories,andUserFilter: nil)
        categorization.updateItem(withInfo: object4)
        let index = categorization.items.firstIndex(of: object4)!
        print(index)
        print(categorization.items as Any)
        XCTAssertEqual(Categorization().text, "Hello, World!") */
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

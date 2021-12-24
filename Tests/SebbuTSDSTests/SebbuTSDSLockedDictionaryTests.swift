import XCTest
import SebbuTSDS
import Dispatch
import Foundation

final class SebbuTSDSLockedDictionaryTests: XCTestCase {
    func testBasics() {
        let dictionary = LockedDictionary<Int, String>()
        dictionary[1] = "one"
        XCTAssert(dictionary[1] == "one")
        
        XCTAssert(dictionary.keys.count == 1)
        XCTAssert(dictionary.values.count == 1)
        
        XCTAssert(dictionary.removeValue(forKey: 2) == nil)
        XCTAssert(dictionary.removeValue(forKey: 1) != nil)
        
        XCTAssert(dictionary.isEmpty)
    }
    
    func testConcurrentAccess() {
        class Object {
            let name: String
            
            init(name: String) {
                self.name = name
            }
        }
        
        let dictionary = LockedDictionary<Int, Object>()
        
        DispatchQueue.concurrentPerform(iterations: 10000) { index in
            for i in 0..<1000 {
                if !dictionary.contains(i) {
                    dictionary.setIfNotExist(i, value: Object(name: "\(i)th object!"))
                }
            }
        }
        XCTAssert(dictionary.values.count == 1000)
        for key in dictionary.keys {
            let object = dictionary[key]
            XCTAssert(object != nil)
            XCTAssert(object!.name == "\(key)th object!")
        }
    }
}

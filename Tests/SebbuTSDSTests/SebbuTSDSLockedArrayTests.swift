import XCTest
import SebbuTSDS
import Dispatch
import Foundation

final class SebbuTSDSLockedArrayTests: XCTestCase {
    func testBasics() {
        let lockedArray = LockedArray<Int>()
        lockedArray.append(1)
        lockedArray.append(2)
        XCTAssertTrue(lockedArray.count == 2)
        XCTAssertFalse(lockedArray.isEmpty)
        
        XCTAssert(lockedArray[0] == 1)
        XCTAssert(lockedArray[1] == 2)
        
        XCTAssert(lockedArray.removeFirst() == 1)
        XCTAssert(lockedArray.count == 1)
        lockedArray.remove(4)
        XCTAssert(lockedArray.count == 1)
        
        lockedArray.append(1)
        XCTAssert(lockedArray.count == 2)
        
        lockedArray.remove(1)
        XCTAssert(lockedArray.count == 1)
    }
    
    func testConcurrentAccess() {
        let lockedArray = LockedArray<Int>()
        for _ in 0..<1000 {
            lockedArray.append(0)
        }
        DispatchQueue.concurrentPerform(iterations: 10000) { index in
            for i in 0..<1000 {
                lockedArray.mutate(at: i) { value in
                    value + 1
                }
            }
        }
        for value in lockedArray.values {
            XCTAssert(value == 10000)
        }
    }
}

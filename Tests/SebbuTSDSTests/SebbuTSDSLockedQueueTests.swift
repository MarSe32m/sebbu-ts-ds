import XCTest
import SebbuTSDS

final class SebbuTSDSLockedQueueTests: XCTestCase {
    func testLockedQueue() {
        let lockedQueue = LockedQueue<(item: Int, thread: Int)>(size: 1000, resizeAutomatically: false)
        let lockedQueueAutomaticResize = LockedQueue<(item: Int, thread: Int)>(size: 1000, resizeAutomatically: true)
        
        // Should probably be based on the amount of cores the test machine has available
        let count = ProcessInfo.processInfo.processorCount >= 2 ? ProcessInfo.processInfo.processorCount : 2
        
        for i in 2...count {
            test(queue: lockedQueue, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: lockedQueueAutomaticResize, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: lockedQueue, writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: lockedQueueAutomaticResize, writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        let queueOfReferenceTypes = LockedQueue<Object>(size: 50000)
        test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: false)
    }
    
    func testLockedQueueSequenceConformance() {
        let queue = LockedQueue<Int>(size: 1_000)
        testQueueSequenceConformance(queue)
    }
    
    func testLockedQueueCount() {
        func remove(_ queue: LockedQueue<Int>) -> Int {
            return queue.dequeue() != nil ? -1 : 0
        }
        
        func add(_ queue: LockedQueue<Int>) -> Int {
            return queue.enqueue(Int.random(in: .min ... .max)) ? 1 : 0
        }
        
        var queue = LockedQueue<Int>(size: 2, resizeAutomatically: true)
        for i in 1...1_000_000 {
            queue.enqueue(i)
            XCTAssert(queue.count == i)
        }
        var elements = queue.count
        for _ in 0..<500000 {
            elements += remove(queue)
        }
        XCTAssertEqual(queue.count, elements)
        
        queue = LockedQueue<Int>(size: 32)
        elements = 0
        for i in 1...24 {
            elements += 1
            if !queue.enqueue(i) {
                print("WTF")
            }
            let count = queue.count
            XCTAssertEqual(elements, count)
        }
        
        for _ in 0..<10000000 {
            elements += Bool.random() ? add(queue) : remove(queue)
            XCTAssertEqual(queue.count, elements)
        }
    }
    
    func testSpinlockedQueue() {
        let spinlockedQueue = SpinlockedQueue<(item: Int, thread: Int)>(size: 1000, resizeAutomatically: false)
        let spinlockedQueueAutomaticResize = SpinlockedQueue<(item: Int, thread: Int)>(size: 16, resizeAutomatically: true)
        
        let count = ProcessInfo.processInfo.processorCount >= 2 ? ProcessInfo.processInfo.processorCount : 2
        
        for i in 2...count {
            test(queue: spinlockedQueue, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: spinlockedQueueAutomaticResize, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: spinlockedQueue, writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: spinlockedQueueAutomaticResize, writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        let queueOfReferenceTypes = SpinlockedQueue<Object>(size: 50000)
        test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: false)
    }
    
    func testSpinlockedQueueSequenceConformance() {
        let queue = SpinlockedQueue<Int>(size: 1_000)
        testQueueSequenceConformance(queue)
    }
    
    func testSpinlockedQueueCount() {
        func remove(_ queue: SpinlockedQueue<Int>) -> Int {
            return queue.dequeue() != nil ? -1 : 0
        }
        
        func add(_ queue: SpinlockedQueue<Int>) -> Int {
            return queue.enqueue(Int.random(in: .min ... .max)) ? 1 : 0
        }
        
        var queue = SpinlockedQueue<Int>(size: 2, resizeAutomatically: true)
        for i in 1...1_000_000 {
            queue.enqueue(i)
            XCTAssert(queue.count == i)
        }
        var elements = queue.count
        for _ in 0..<500000 {
            elements += remove(queue)
        }
        XCTAssertEqual(queue.count, elements)
        queue = SpinlockedQueue<Int>(size: 32)
        elements = 0
        for i in 1...24 {
            elements += 1
            if !queue.enqueue(i) {
                print("WTF")
            }
            let count = queue.count
            XCTAssertEqual(elements, count)
        }
        
        for _ in 0..<10000000 {
            elements += Bool.random() ? add(queue) : remove(queue)
            XCTAssertEqual(queue.count, elements)
        }
    }
    
    func testQueueDraining() {
        testDraining(SpinlockedQueue<Int>(size: 10000, resizeAutomatically: false))
        testDraining(SpinlockedQueue<Int>(size: 10000, resizeAutomatically: true))
        
        testDraining(LockedQueue<Int>(size: 10000, resizeAutomatically: false))
        testDraining(LockedQueue<Int>(size: 10000, resizeAutomatically: true))
    }
}

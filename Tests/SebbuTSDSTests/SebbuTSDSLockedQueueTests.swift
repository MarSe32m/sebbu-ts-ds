import XCTest
import SebbuTSDS

final class SebbuTSDSLockedQueueTests: XCTestCase {
    func testLockedQueue() {
        let lockedQueue = LockedQueue<(item: Int, thread: Int)>()
        let lockedBounded = LockedBoundedQueue<(item: Int, thread: Int)>(size: 1000)
        
        // Should probably be based on the amount of cores the test machine has available
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        
        for i in 2...count {
            test(queue: lockedQueue, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: lockedBounded, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: lockedQueue, writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: lockedBounded, writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        let queueOfReferenceTypes = LockedQueue<Object>()
        test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: false)
        
        let anotherQueueOfReferenceTypes = LockedBoundedQueue<Object>(size: 50000)
        test(queue: anotherQueueOfReferenceTypes, singleWriter: false, singleReader: false)
    }
    
    func testLockedQueueSequenceConformance() {
        let queue = LockedQueue<Int>()
        testQueueSequenceConformance(queue)
        
        let boundedQueue = LockedBoundedQueue<Int>(size: 10000)
        testQueueSequenceConformance(boundedQueue)
    }
    
    func testLockedQueueCount() {
        func remove<T: ConcurrentQueue>(_ queue: T) -> Int where T.Element == Int {
            return queue.dequeue() != nil ? -1 : 0
        }
        
        func add<T: ConcurrentQueue>(_ queue: T) -> Int where T.Element == Int {
            return queue.enqueue(Int.random(in: .min ... .max)) ? 1 : 0
        }
        
        let queue = LockedQueue<Int>()
        for i in 1...1_000_000 {
            queue.enqueue(i)
            XCTAssert(queue.count == i)
        }
        var elements = queue.count
        for _ in 0..<500000 {
            elements += remove(queue)
        }
        XCTAssertEqual(queue.count, elements)
        
        let _queue = LockedBoundedQueue<Int>(size: 32)
        elements = 0
        for i in 1...24 {
            elements += 1
            if !_queue.enqueue(i) {
                print("WTF")
            }
            let count = _queue.count
            XCTAssertEqual(elements, count)
        }
        
        for _ in 0..<10_000_000 {
            elements += Bool.random() ? add(_queue) : remove(_queue)
            XCTAssertEqual(_queue.count, elements)
        }
    }
    
    func testSpinlockedQueue() {
        let spinlockedQueue = SpinlockedQueue<(item: Int, thread: Int)>()
        let spinlockedBoundedQueue = SpinlockedBoundedQueue<(item: Int, thread: Int)>(size: 1000)
        
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        
        for i in 2...count {
            test(queue: spinlockedQueue, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: spinlockedBoundedQueue, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: spinlockedQueue, writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: spinlockedBoundedQueue, writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        let queueOfReferenceTypes = SpinlockedQueue<Object>()
        test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: false)
    }
    
    func testSpinlockedQueueSequenceConformance() {
        let boundedQueue = SpinlockedBoundedQueue<Int>(size: 1_000)
        testQueueSequenceConformance(boundedQueue)
        
        let queue = SpinlockedQueue<Int>()
        testQueueSequenceConformance(queue)
    }
    
    func testSpinlockedQueueCount() {
        func remove<T: ConcurrentQueue>(_ queue: T) -> Int where T.Element == Int{
            return queue.dequeue() != nil ? -1 : 0
        }
        
        func add<T: ConcurrentQueue>(_ queue: T) -> Int where T.Element == Int {
            return queue.enqueue(Int.random(in: .min ... .max)) ? 1 : 0
        }
        
        let queue = SpinlockedQueue<Int>()
        for i in 1...1_000_000 {
            queue.enqueue(i)
            XCTAssert(queue.count == i)
        }
        var elements = queue.count
        for _ in 0..<500000 {
            elements += remove(queue)
        }
        XCTAssertEqual(queue.count, elements)
        
        let _queue = SpinlockedBoundedQueue<Int>(size: 32)
        elements = 0
        for i in 1...24 {
            elements += 1
            if !_queue.enqueue(i) {
                print("WTF")
            }
            let count = _queue.count
            XCTAssertEqual(elements, count)
        }
        
        for _ in 0..<10_000_000 {
            elements += Bool.random() ? add(_queue) : remove(_queue)
            XCTAssertEqual(_queue.count, elements)
        }
    }
    
    func testQueueDraining() {
        testDraining(SpinlockedBoundedQueue<Int>(size: 10000))
        testDraining(SpinlockedQueue<Int>())
        
        testDraining(LockedBoundedQueue<Int>(size: 10000))
        testDraining(LockedQueue<Int>())
    }
}

import XCTest
import SebbuTSDS

final class SebbuTSDSLockFreeQueueTests: XCTestCase {
    func testSPSCBoundedQueue() {
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1_000_000), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1_000_000), writers: 1, readers: 1, elements: 10000)
        test(queue: SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1_000_000), writers: 1, readers: 1, elements: 10_000_000)
        
        testQueueSequenceConformance(SPSCBoundedQueue<Int>(size: 1_000))
        
        let queueOfReferenceTypes = SPSCBoundedQueue<Object>(size: 50000)
        test(queue: queueOfReferenceTypes, singleWriter: true, singleReader: true)
        
        let queue = SPSCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)
    }
    
    func testSPSCQueue() {
        test(queue: SPSCQueue<(item: Int, thread: Int)>(), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(), writers: 1, readers: 1, elements: 10_000)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(), writers: 1, readers: 1, elements: 10_000_000)
        
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 2000), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 2000), writers: 1, readers: 1, elements: 10_000)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 2000), writers: 1, readers: 1, elements: 10_000_000)
    
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: 1, readers: 1, elements: 128)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: 1, readers: 1, elements: 10_000)
        test(queue: SPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: 1, readers: 1, elements: 10_000_000)
        
        testQueueSequenceConformance(SPSCQueue<Int>())
        let queueOfReferenceTypes = SPSCQueue<Object>()
        test(queue: queueOfReferenceTypes, singleWriter: true, singleReader: true)
    }
    
    func testMPMCBoundedQueue() {
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128), writers: i - 1, readers: 1, elements: 1_000_00)

            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024), writers: i - 1, readers: 1, elements: 1_000_00)

            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(queue: MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: i - 1, readers: 1, elements: 1_000_00)
        }

        testQueueSequenceConformance(MPMCBoundedQueue<Int>(size: 1000))
        let queueOfReferenceTypes = MPMCBoundedQueue<Object>(size: 50000)
        test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: false)

        let queue = MPMCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)
    }
    
    func testSPMCBoundedQueue() {
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: SPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: i - 1, elements: 128)
            test(queue: SPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: i - 1, elements: 10_000)
            test(queue: SPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536), writers: 1, readers: i - 1, elements: 10_000_00)
        }

        testQueueSequenceConformance(SPMCBoundedQueue<Int>(size: 1000))

        let queueOfReferenceTypes = SPMCBoundedQueue<Object>(size: 50000)
        test(queue: queueOfReferenceTypes, singleWriter: true, singleReader: false)
        
        let queue = SPMCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)
    }
    
    func testMPSCQueue() {
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: MPSCQueue<(item: Int, thread: Int)>(), writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: MPSCQueue<(item: Int, thread: Int)>(cacheSize: 10000), writers: i - 1, readers: 1, elements: 1_000_00)
            test(queue: MPSCQueue<(item: Int, thread: Int)>(cacheSize: 65536), writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        testQueueSequenceConformance(MPSCQueue<Int>())
        let queueOfReferenceTypes = MPSCQueue<Object>()
        test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: true)
    }
    
    func testMPSCBoundedQueue() {
        for i in 2...ProcessInfo.processInfo.processorCount {
            test(queue: MPSCBoundedQueue<(item: Int, thread: Int)>(size: 10000), writers: i - 1, readers: 1, elements: 1_000_00)
        }
        testQueueSequenceConformance(MPSCBoundedQueue<Int>(size: 10000))
        
        let queueOfReferenceTypes = MPSCBoundedQueue<Object>(size: 50000)
        test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: true)
        
        let queue = MPSCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)
    }
    
    func testQueueDraining() {
        testDraining(SPSCBoundedQueue<Int>(size: 128))
        testDraining(SPSCBoundedQueue<Int>(size: 1024))
        testDraining(SPSCBoundedQueue<Int>(size: 65536))
        
        testDraining(SPSCQueue<Int>())
        
        testDraining(MPMCBoundedQueue<Int>(size: 128))
        testDraining(MPMCBoundedQueue<Int>(size: 1024))
        testDraining(MPMCBoundedQueue<Int>(size: 65536))
        
        testDraining(SPMCBoundedQueue<Int>(size: 128))
        testDraining(SPMCBoundedQueue<Int>(size: 1024))
        testDraining(SPMCBoundedQueue<Int>(size: 65536))
        
        testDraining(MPSCBoundedQueue<Int>(size: 128))
        testDraining(MPSCBoundedQueue<Int>(size: 1024))
        testDraining(MPSCBoundedQueue<Int>(size: 65536))
        
        testDraining(MPSCQueue<Int>())
    }
}


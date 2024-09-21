import XCTest
import SebbuTSDS

final class MPSCBoundedQueueTests: XCTestCase {
    func testQueue() async {
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        for i in 2...count {
            for size in [128, 1024, 10000, 65536] {
                for elements in [128, 1024, 10000, 1_000_000] {
                    let queue = MPSCBoundedQueue<(item: Int, task: Int)>(size: size)
                    await test(queue: queue, writers: i - 1, readers: 1, elements: elements)
                }
            }
        }
        testQueueSequenceConformance(MPSCBoundedQueue<Int>(size: 10000))
        
        let queueOfReferenceTypes = MPSCBoundedQueue<Object>(size: 50000)
        await test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: true)
        
        let queue = MPSCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)
        for size in [128, 1024, 65536] {
            let queue = MPSCBoundedQueue<Int>(size: size)
            testDraining(queue)
        }
    }
}


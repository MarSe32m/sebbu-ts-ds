import XCTest
import SebbuTSDS

final class SPMCBoundedQueueTests: XCTestCase {
    func testSPMCBoundedQueue() async {
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        for i in 2...count {
            for size in [128, 1024, 65536] {
                for elements in [128, 1024, 10_000, 1_000_000] {
                    let queue = SPMCBoundedQueue<(item: Int, task: Int)>(size: size)
                    await test(queue: queue, writers: 1, readers: i - 1, elements: elements)
                }
            }
        }

        testQueueSequenceConformance(SPMCBoundedQueue<Int>(size: 1000))

        let queueOfReferenceTypes = SPMCBoundedQueue<Object>(size: 50000)
        await test(queue: queueOfReferenceTypes, singleWriter: true, singleReader: false)
        
        let queue = SPMCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)

        for size in [128, 1024, 65536] {
            let queue = SPMCBoundedQueue<Int>(size: size)
            testDraining(queue)
        }
    }
}


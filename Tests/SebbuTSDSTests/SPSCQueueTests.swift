import XCTest
import SebbuTSDS

final class SPSCQueueTests: XCTestCase {
    func testQueue() async {
        for cacheSize in [128, 2000, 65536, 1_000_000] {
            for elements in [128, 1024, 10_000, 10_000_000] {
                let queue = SPSCQueue<(item: Int, task: Int)>(cacheSize: cacheSize)
                await test(queue: queue, writers: 1, readers: 1, elements: elements)
            }
        }
        
        testQueueSequenceConformance(SPSCQueue<Int>())
        let queueOfReferenceTypes = SPSCQueue<Object>()
        await test(queue: queueOfReferenceTypes, singleWriter: true, singleReader: true)
        for size in [128, 1024, 65536] {
            let queue = SPSCQueue<Int>(cacheSize: size)
            testDraining(queue)
        }
    }
}


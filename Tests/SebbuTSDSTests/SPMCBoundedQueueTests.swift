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
    
    func testNonCopyableObject() async {
        let queue = SPMCBoundedQueue<NonCopyableObject>(size: 128)
        let writers = 1
        let readers = 8
        let elementCount = 80_000
        await withDiscardingTaskGroup { group in
            for _ in 0..<writers {
                group.addTask {
                    let writes = elementCount / writers
                    for i in 0..<writes {
                        var object = NonCopyableObject(i)
                        while let newObject = queue.enqueue(object) {
                            await Task.yield()
                            object = consume newObject
                        }
                    }
                }
            }
            for _ in 0..<readers {
                group.addTask {
                    let reads = elementCount / readers
                    for _ in 0..<reads {
                        while queue.dequeue() == nil { await Task.yield() }
                    }
                }
            }
        }
        XCTAssertEqual(NonCopyableObject.count.load(ordering: .relaxed), 0)
    }
}


import XCTest
import SebbuTSDS

final class MPMCBoundedQueueTests: XCTestCase {
    func testQueue() async {
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        for i in 2...count {
            for size in [128, 1024, 65536] {
                let queue = MPMCBoundedQueue<(item: Int, task: Int)>(size: size)
                await test(queue: queue, writers: i / 2, readers: i / 2, elements: 1_000_00)
                await test(queue: queue, writers: i / 2, readers: i - i / 2, elements: 1_000_00)
                await test(queue: queue, writers: i - i / 2, readers: i / 2, elements: 1_000_00)
                await test(queue: queue, writers: i - 1, readers: 1, elements: 1_000_00)
            }
        }

        testQueueSequenceConformance(MPMCBoundedQueue<Int>(size: 1000))
        let queueOfReferenceTypes = MPMCBoundedQueue<Object>(size: 50000)
        await test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: false)

        let queue = MPMCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)

        for size in [128, 1024, 65536] {
            let queue = MPMCBoundedQueue<Int>(size: size)
            testDraining(queue)
        }
    }
    
    func testNonCopyableObject() async {
        let queue = MPMCBoundedQueue<NonCopyableObject>(size: 128)
        let writers = 8
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


import XCTest
import SebbuTSDS

final class SPSCBoundedQueueTests: XCTestCase {
    func testQueue() async {
        for size in [128, 1024, 65536, 1_000_000] {
            for elements in [128, 1024, 10000, 1_000_000, 10_000_000] {
                let queue = SPSCBoundedQueue<(item: Int, task: Int)>(size: size)
                await test(queue: queue, writers: 1, readers: 1, elements: elements)
            }
        }
        
        testQueueSequenceConformance(SPSCBoundedQueue<Int>(size: 1_000))
        
        let queueOfReferenceTypes = SPSCBoundedQueue<Object>(size: 50000)
        await test(queue: queueOfReferenceTypes, singleWriter: true, singleReader: true)
        
        let queue = SPSCBoundedQueue<Int>(size: 16)
        for i in 1...15 {
            queue.enqueue(i)
            XCTAssertEqual(queue.count, i)
        }
        XCTAssertTrue(queue.wasFull)
        _ = queue.dequeue()
        XCTAssertEqual(queue.count, 14)
        XCTAssertFalse(queue.wasFull)

        for size in [128, 1024, 65536] {
            let queue = SPSCBoundedQueue<Int>(size: size)
            testDraining(queue)
        }
    }
    
    func testNonCopyableObject() async {
        let queue = SPSCBoundedQueue<NonCopyableObject>(size: 128)
        let writers = 1
        let readers = 1
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


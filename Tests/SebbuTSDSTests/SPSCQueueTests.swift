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
    
    func testNonCopyableObject() async {
        let queue = SPSCQueue<NonCopyableObject>()
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


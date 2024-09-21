import XCTest
import SebbuTSDS

final class MPSCQueueTests: XCTestCase {
    func testQueue() async {
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        for i in 2...count {
            for cacheSize in [128, 1024, 10000, 65536] {
                for elements in [128, 1024, 10000, 1_000_000] {
                    let queue = MPSCQueue<(item: Int, task: Int)>(cacheSize: cacheSize)
                    await test(queue: queue, writers: i - 1, readers: 1, elements: elements)
                }
            }
        }
        
        testQueueSequenceConformance(MPSCQueue<Int>())
        let queueOfReferenceTypes = MPSCQueue<Object>()
        await test(queue: queueOfReferenceTypes, singleWriter: false, singleReader: true)
        for size in [128, 1024, 65536] {
            let queue = MPSCQueue<Int>(cacheSize: size)
            testDraining(queue)
        }
    }
    
    func testNonCopyableObject() async {
        let queue = MPSCQueue<NonCopyableObject>()
        let writers = 8
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


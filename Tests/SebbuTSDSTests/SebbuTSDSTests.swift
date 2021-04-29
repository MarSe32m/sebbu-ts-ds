import XCTest
import SebbuTSDS
import Atomics
import Dispatch
import Foundation

final class SebbuTSDSTests: XCTestCase {
    private func test<T: ConcurrentQueue>(name: String, queue: T, writers: Int, readers: Int, elements: Int = 10_000) where T.Element == (item: Int, thread: Int) {
        let threadCount = writers + readers
        let count = ManagedAtomic<Int>(0)
        let done = ManagedAtomic<Int>(writers)
        let accumulatedCount = ManagedAtomic<Int>(0)
        DispatchQueue.concurrentPerform(iterations: threadCount) { i in
            if i < writers {
                for index in 0..<elements {
                    let element = (item: index, thread: i)
                    while !queue.enqueue(element) {
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                    accumulatedCount.wrappingIncrement(by: index, ordering: .relaxed)
                }
                done.wrappingDecrement(ordering: .relaxed)
            }
            if i >= writers {
                while done.load(ordering: .relaxed) > 0 {
                    if let element = queue.dequeue() {
                        count.wrappingIncrement(by: element.item, ordering: .relaxed)
                        continue
                    }
                    Thread.sleep(forTimeInterval: 0.001)
                }
                queue.dequeueAll { (element) in
                    count.wrappingIncrement(by: element.item, ordering: .relaxed)
                }
            }
        }
        let finalCount = count.load(ordering: .sequentiallyConsistent)
        let finalAccumulated = accumulatedCount.load(ordering: .sequentiallyConsistent)
        XCTAssert(finalCount == finalAccumulated, "The queue wasn't deterministic")
        XCTAssertNil(queue.dequeue())
    }

    func testSPSCBoundedQueue128() {
        let spscBoundedQueue128 = SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128)
        test(name: "SPSCBoundedQueue128", queue: spscBoundedQueue128, writers: 1, readers: 1, elements: 128)
        test(name: "SPSCBoundedQueue128", queue: spscBoundedQueue128, writers: 1, readers: 1, elements: Int.random(in: 5000...10000))
        test(name: "SPSCBoundedQueue128", queue: spscBoundedQueue128, writers: 1, readers: 1, elements: Int.random(in: 5_000_000...10_000_000))
    }
    
    func testSPSCBoundedQueue1024() {
        let spscBoundedQueue1024 = SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024)
        test(name: "SPSCBoundedQueue1024", queue: spscBoundedQueue1024, writers: 1, readers: 1, elements: 128)
        test(name: "SPSCBoundedQueue1024", queue: spscBoundedQueue1024, writers: 1, readers: 1, elements: Int.random(in: 5000...10000))
        test(name: "SPSCBoundedQueue1024", queue: spscBoundedQueue1024, writers: 1, readers: 1, elements: Int.random(in: 5_000_000...10_000_000))
    }
    
    func testSPSCBoundedQueue65536() {
        let spscBoundedQueue65536 = SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536)
        test(name: "SPSCBoundedQueue65536", queue: spscBoundedQueue65536, writers: 1, readers: 1, elements: 128)
        test(name: "SPSCBoundedQueue65536", queue: spscBoundedQueue65536, writers: 1, readers: 1, elements: Int.random(in: 5000...10000))
        test(name: "SPSCBoundedQueue65536", queue: spscBoundedQueue65536, writers: 1, readers: 1, elements: Int.random(in: 5_000_000...10_000_000))
    }
    
    func testSPSCBoundedQueue1000000() {
        let spscBoundedQueue1000000 = SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1_000_000)
        test(name: "SPSCBoundedQueue1000000", queue: spscBoundedQueue1000000, writers: 1, readers: 1, elements: 128)
        test(name: "SPSCBoundedQueue1000000", queue: spscBoundedQueue1000000, writers: 1, readers: 1, elements: Int.random(in: 5000...10000))
        test(name: "SPSCBoundedQueue1000000", queue: spscBoundedQueue1000000, writers: 1, readers: 1, elements: Int.random(in: 5_000_000...10_000_000))
    }
    
    func testSPSCQueue() {
        let spscQueue = SPSCQueue<(item: Int, thread: Int)>()
        test(name: "SPSCQueue", queue: spscQueue, writers: 1, readers: 1, elements: 128)
        test(name: "SPSCQueue", queue: spscQueue, writers: 1, readers: 1, elements: Int.random(in: 5000...10000))
        test(name: "SPSCQueue", queue: spscQueue, writers: 1, readers: 1, elements: Int.random(in: 5_000_000...10_000_000))
    }
    
    func testMPMCBoundedQueue128() {
        let mpmcBoundedQueue128 = MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128)
        for i in 2...6 {
            test(name: "MPMCBoundedQueue128", queue: mpmcBoundedQueue128, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue128", queue: mpmcBoundedQueue128, writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue128", queue: mpmcBoundedQueue128, writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue128", queue: mpmcBoundedQueue128, writers: i - 1, readers: 1, elements: 1_000_00)
        }
    }
    
    func testMPMCBoundedQueue1024() {
        let mpmcBoundedQueue1024 = MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024)
        for i in 2...6 {
            test(name: "MPMCBoundedQueue1024", queue: mpmcBoundedQueue1024, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue1024", queue: mpmcBoundedQueue1024, writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue1024", queue: mpmcBoundedQueue1024, writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue1024", queue: mpmcBoundedQueue1024, writers: i - 1, readers: 1, elements: 1_000_00)
        }
    }
    
    func testMPMCBoundedQueue65536() {
        let mpmcBoundedQueue65536 = MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536)
        for i in 2...6 {
            test(name: "MPMCBoundedQueue65536", queue: mpmcBoundedQueue65536, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue65536", queue: mpmcBoundedQueue65536, writers: i / 2, readers: i - i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue65536", queue: mpmcBoundedQueue65536, writers: i - i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "MPMCBoundedQueue65536", queue: mpmcBoundedQueue65536, writers: i - 1, readers: 1, elements: 1_000_00)
        }
    }
    
    func testMPSCQueue() {
        let mpscQueue = MPSCQueue<(item: Int, thread: Int)>()
        for i in 2...6 {
            test(name: "MPSCQueue", queue: mpscQueue, writers: i - 1, readers: 1, elements: 1_000_00)
        }
    }
    
    func testLockedQueue() {
        let lockedQueue = LockedQueue<(item: Int, thread: Int)>(size: 1000, resizeAutomatically: false)
        let lockedQueueAutomaticResize = LockedQueue<(item: Int, thread: Int)>(size: 1000, resizeAutomatically: true)
        
        // Should probably be based on the amount of cores the test machine has available
        for i in 2...4 {
            test(name: "LockedQueue", queue: lockedQueue, writers: i / 2, readers: i / 2, elements: 1_000_000)
            test(name: "LockedQueueAutomaticResize", queue: lockedQueueAutomaticResize, writers: i / 2, readers: i / 2, elements: 1_000_000)
            test(name: "LockedQueue", queue: lockedQueue, writers: i - 1, readers: 1, elements: 1_000_000)
            test(name: "LockedQueueAutomaticResize", queue: lockedQueueAutomaticResize, writers: i - 1, readers: 1, elements: 1_000_000)
        }
    }
    
    func testDraining() {
        do {
            let spscBoundedQueue128 = SPSCBoundedQueue<(item: Int, thread: Int)>(size: 128)
            let spscBoundedQueue1024 = SPSCBoundedQueue<(item: Int, thread: Int)>(size: 1024)
            let spscBoundedQueue65536 = SPSCBoundedQueue<(item: Int, thread: Int)>(size: 65536)
            let spscQueue = SPSCQueue<(item: Int, thread: Int)>()
            
            let mpmcBoundedQueue128 = MPMCBoundedQueue<(item: Int, thread: Int)>(size: 128)
            let mpmcBoundedQueue1024 = MPMCBoundedQueue<(item: Int, thread: Int)>(size: 1024)
            let mpmcBoundedQueue65536 = MPMCBoundedQueue<(item: Int, thread: Int)>(size: 65536)
            
            let mpscQueue = MPSCQueue<(item: Int, thread: Int)>()
            let lockedQueue = LockedQueue<(item: Int, thread: Int)>(size: 10000, resizeAutomatically: false)
            let lockedQueueAutomaticResize = LockedQueue<(item: Int, thread: Int)>(size: 10000, resizeAutomatically: true)
            
            for i in 0..<1_000_000 {
                spscBoundedQueue128.enqueue((item: i, thread: 0))
                spscBoundedQueue1024.enqueue((item: i, thread: 0))
                spscBoundedQueue65536.enqueue((item: i, thread: 0))
                spscQueue.enqueue((item: i, thread: 0))
                mpmcBoundedQueue128.enqueue((item: i, thread: 0))
                mpmcBoundedQueue1024.enqueue((item: i, thread: 0))
                mpmcBoundedQueue65536.enqueue((item: i, thread: 0))
                mpscQueue.enqueue((item: i, thread: 0))
                lockedQueue.enqueue((item: i, thread: 0))
                lockedQueueAutomaticResize.enqueue((item: i, thread: 0))
            }
            spscBoundedQueue128.dequeueAll { _ in }
            spscBoundedQueue1024.dequeueAll { _ in }
            spscBoundedQueue65536.dequeueAll { _ in }
            spscQueue.dequeueAll { _ in }
            mpmcBoundedQueue128.dequeueAll { _ in }
            mpmcBoundedQueue1024.dequeueAll { _ in }
            mpmcBoundedQueue65536.dequeueAll { _ in }
            mpscQueue.dequeueAll { _ in }
            lockedQueue.dequeueAll { _ in }
            lockedQueueAutomaticResize.dequeueAll { _ in }
            
            XCTAssertNil(spscBoundedQueue128.dequeue())
            XCTAssertNil(spscBoundedQueue1024.dequeue())
            XCTAssertNil(spscBoundedQueue65536.dequeue())
            XCTAssertNil(spscQueue.dequeue())
            XCTAssertNil(mpmcBoundedQueue128.dequeue())
            XCTAssertNil(mpmcBoundedQueue1024.dequeue())
            XCTAssertNil(mpmcBoundedQueue65536.dequeue())
            XCTAssertNil(mpscQueue.dequeue())
            XCTAssertNil(lockedQueue.dequeue())
            XCTAssertNil(lockedQueueAutomaticResize.dequeue())
        }
    }
}

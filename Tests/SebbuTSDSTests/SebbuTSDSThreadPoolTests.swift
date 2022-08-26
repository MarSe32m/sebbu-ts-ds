//
//  SebbuTSDSThreadPoolTests.swift
//  
//
//  Created by Sebastian Toivonen on 15.1.2022.
//

#if canImport(Atomics)
import XCTest
import SebbuTSDS
import Dispatch
import Atomics
import Foundation

final class SebbuTSDSThreadPoolTests: XCTestCase {
    func testThreadPoolEnqueueing() {
        let enqueueCount = 10000000
        let threadPool = ThreadPool(numberOfThreads: 8)
        threadPool.start()
        let counter = ManagedAtomic<Int>((0..<enqueueCount).reduce(0, +))
        for i in 0..<enqueueCount {
            threadPool.run {
                counter.wrappingDecrement(by: i, ordering: .relaxed)
            }
        }
        while counter.load(ordering: .relaxed) != 0 { Thread.sleep(forTimeInterval: 0.01) }
        threadPool.stop()
    }
    
    func testSharedThreadPoolEnqueueing() {
        let enqueueCount = 10000000
        let counter = ManagedAtomic<Int>((0..<enqueueCount).reduce(0, +))
        for i in 0..<enqueueCount {
            ThreadPool.shared.run {
                counter.wrappingDecrement(by: i, ordering: .relaxed)
            }
        }
        while counter.load(ordering: .relaxed) != 0 { Thread.sleep(forTimeInterval: 0.01) }
    }
    
    func testThreadPoolEnqueueingFromMultipleThreads() {
        let enqueueCount = 1000000
        let enqueueingThreadCount = 6
        let threadPool = ThreadPool(numberOfThreads: 6)
        threadPool.start()
        let counter = ManagedAtomic<Int>((0...enqueueCount).reduce(0, +) * enqueueingThreadCount)
        DispatchQueue.concurrentPerform(iterations: enqueueingThreadCount) { thread in
            for i in 0...enqueueCount {
                threadPool.run {
                    counter.wrappingDecrement(by: i, ordering: .relaxed)
                }
            }
        }
        while counter.load(ordering: .relaxed) != 0 {}
        threadPool.stop()
    }
    
    func testThreadPoolWorkStealing() {
        let enqueueCount = 1000
        let threadPool = ThreadPool(numberOfThreads: 10)
        threadPool.start()
        let counter = ManagedAtomic<Int>(enqueueCount)
        for i in 0..<enqueueCount {
            threadPool.run {
                if i % 10 == 0 {
                    // Since the enqueueing strategy is round robin, we load the first thread with
                    // "heavy computation" work
                    Thread.sleep(forTimeInterval: 0.1)
                }
                counter.wrappingDecrement(ordering: .relaxed)
            }
        }
        let start = DispatchTime.now().uptimeNanoseconds
        while counter.load(ordering: .relaxed) != 0 {}
        let end = DispatchTime.now().uptimeNanoseconds
        threadPool.stop()
        XCTAssertLessThanOrEqual(Double(end - start) / 1_000_000_000.0, 2)
    }
    
    func testThreadPoolRunAfter() {
        let enqueueCount = 1000
        let threadPool = ThreadPool(numberOfThreads: 5)
        threadPool.start()
        let counter = ManagedAtomic<Int>(enqueueCount)
        let itemsToEnqueue = ManagedAtomic<Int>(enqueueCount)
        
        func enqueue() {
            threadPool.run(after: 10_000_000) {
                if itemsToEnqueue.wrappingDecrementThenLoad(ordering: .relaxed) < 0 { return }
                counter.wrappingDecrement(ordering: .relaxed)
                enqueue()
            }
        }
        
        for _ in 0..<5 {
            enqueue()
        }
        
        let start = DispatchTime.now().uptimeNanoseconds
        while counter.load(ordering: .relaxed) != 0 {}
        let end = DispatchTime.now().uptimeNanoseconds
        threadPool.stop()
        XCTAssertGreaterThanOrEqual(Double(end - start) / 1_000_000_000.0, 1)
    }
}
#endif

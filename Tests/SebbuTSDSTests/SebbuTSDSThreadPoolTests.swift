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
    func testThreadPoolEnqueueing() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount = 10_000_000
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
    
    func testBoundedThreadPoolEnqueueing() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount = 10_000_000
        let threadPool = BoundedThreadPool(size: 100_000, numberOfThreads: 8)
        threadPool.start()
        let counter = ManagedAtomic<Int>((0..<enqueueCount).reduce(0, +))
        for i in 0..<enqueueCount {
            while true {
                let enqueued = threadPool.run {
                    counter.wrappingDecrement(by: i, ordering: .relaxed)
                }
                if enqueued { break }
            }
        }
        while counter.load(ordering: .relaxed) != 0 { Thread.sleep(forTimeInterval: 0.01) }
        threadPool.stop()
    }
    
    func testSharedThreadPoolEnqueueing() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount = 10000000
        let counter = ManagedAtomic<Int>((0..<enqueueCount).reduce(0, +))
        for i in 0..<enqueueCount {
            ThreadPool.shared.run {
                counter.wrappingDecrement(by: i, ordering: .relaxed)
            }
        }
        while counter.load(ordering: .relaxed) != 0 { Thread.sleep(forTimeInterval: 0.01) }
    }
    
    func testThreadPoolEnqueueingFromMultipleThreads() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
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
    
    func testBoundedThreadPoolEnqueueingFromMultipleThreads() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount = 1000000
        let enqueueingThreadCount = 6
        let threadPool = BoundedThreadPool(size: 100000, numberOfThreads: 6)
        threadPool.start()
        let counter = ManagedAtomic<Int>((0...enqueueCount).reduce(0, +) * enqueueingThreadCount)
        DispatchQueue.concurrentPerform(iterations: enqueueingThreadCount) { thread in
            for i in 0...enqueueCount {
                while true {
                    let enqueued = threadPool.run {
                        counter.wrappingDecrement(by: i, ordering: .relaxed)
                    }
                    if enqueued { break }
                }
            }
        }
        while counter.load(ordering: .relaxed) != 0 {}
        threadPool.stop()
    }
    
    func testThreadPoolWorkStealing() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
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
        XCTAssertLessThanOrEqual(Double(end - start) / 1_000_000_000.0, 2)
        threadPool.stop()
    }
    
    func testBoundedThreadPoolWorkStealing() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount = 1000
        let threadPool = BoundedThreadPool(size: 100_000, numberOfThreads: 10)
        threadPool.start()
        let counter = ManagedAtomic<Int>(enqueueCount)
        for i in 0..<enqueueCount {
            let _ = threadPool.run {
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
        XCTAssertLessThanOrEqual(Double(end - start) / 1_000_000_000.0, 2)
        threadPool.stop()
    }
    
    func testThreadPoolRunAfter() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount: UInt64 = 1_100
        let threadPool = ThreadPool(numberOfThreads: 5)
        threadPool.start()
        let counter = ManagedAtomic<UInt64>(enqueueCount)
        
        for i: UInt64 in 0..<enqueueCount {
            threadPool.run(after: i * 1_000_000) {
                counter.wrappingDecrement(ordering: .relaxed)
            }
        }
        
        let start = DispatchTime.now().uptimeNanoseconds
        while counter.load(ordering: .relaxed) != 0 {
            let currentTime = DispatchTime.now().uptimeNanoseconds
            if currentTime - start > 10_000_000_000 {
                XCTFail("Test took too long. Counters left: \(counter.load(ordering: .relaxed))")
                return
            }
        }
        let end = DispatchTime.now().uptimeNanoseconds
        XCTAssertGreaterThanOrEqual(end - start, 1_000_000_000)
        XCTAssertLessThanOrEqual(Double(end - start) / 1_000_000_000.0, 10)
        threadPool.stop()
    }
    
    func testThreadPoolBatchRunAfter() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount = 1000
        let threadPool = ThreadPool(numberOfThreads: 5)
        threadPool.start()
        let counter = ManagedAtomic<Int>(enqueueCount)
        let itemsToEnqueue = ManagedAtomic<Int>(enqueueCount)
        
        func enqueue() {
            let _ = threadPool.run(after: 10_000_000) {
                if itemsToEnqueue.wrappingDecrementThenLoad(ordering: .relaxed) < 0 { return }
                counter.wrappingDecrement(ordering: .relaxed)
                enqueue()
            }
        }
        
        for _ in 0..<5 {
            enqueue()
        }
        
        let start = DispatchTime.now().uptimeNanoseconds
        while counter.load(ordering: .relaxed) > 0 {
            let currentTime = DispatchTime.now().uptimeNanoseconds
            if currentTime - start > 10_000_000_000 {
                XCTFail("Test took too long...")
                return
            }
        }
        let end = DispatchTime.now().uptimeNanoseconds
        XCTAssertGreaterThanOrEqual(Double(end - start) / 1_000_000_000.0, 1)
        XCTAssertLessThanOrEqual(Double(end - start) / 1_000_000_000.0, 10)
        threadPool.stop()
    }
    
    func testBoundedThreadPoolRunAfter() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount = 1000
        let threadPool = BoundedThreadPool(size: 100_000, numberOfThreads: 5)
        threadPool.start()
        let counter = ManagedAtomic<Int>(enqueueCount)
        let itemsToEnqueue = ManagedAtomic<Int>(enqueueCount)
        
        func enqueue() {
            let _ = threadPool.run(after: 10_000_000) {
                if itemsToEnqueue.wrappingDecrementThenLoad(ordering: .relaxed) < 0 { return }
                counter.wrappingDecrement(ordering: .relaxed)
                enqueue()
            }
        }
        
        for _ in 0..<5 {
            enqueue()
        }
        
        let start = DispatchTime.now().uptimeNanoseconds
        while counter.load(ordering: .relaxed) > 0 {
            let currentTime = DispatchTime.now().uptimeNanoseconds
            if currentTime - start > 10_000_000_000 {
                XCTFail("Test took too long...")
                return
            }
        }
        let end = DispatchTime.now().uptimeNanoseconds
        XCTAssertGreaterThanOrEqual(Double(end - start) / 1_000_000_000.0, 1)
        XCTAssertLessThanOrEqual(Double(end - start) / 1_000_000_000.0, 10)
        threadPool.stop()
    }
    
    func testBoundedThreadPoolBatchRunAfter() throws {
        try XCTSkipIf(true, "TODO: Reimplement with Synchronization")
        let enqueueCount: UInt64 = 1_100
        let threadPool = BoundedThreadPool(size: 10_000, numberOfThreads: 5)
        threadPool.start()
        let counter = ManagedAtomic<UInt64>(enqueueCount)
        
        for i: UInt64 in 0..<enqueueCount {
            threadPool.run(after: i * 1_000_000) {
                counter.wrappingDecrement(ordering: .relaxed)
            }
        }
        
        let start = DispatchTime.now().uptimeNanoseconds
        while counter.load(ordering: .relaxed) != 0 {
            let currentTime = DispatchTime.now().uptimeNanoseconds
            if currentTime - start > 10_000_000_000 {
                XCTFail("Test took too long. Counters left: \(counter.load(ordering: .relaxed))")
                return
            }
        }
        let end = DispatchTime.now().uptimeNanoseconds
        XCTAssertGreaterThanOrEqual(end - start, 1_000_000_000)
        XCTAssertLessThanOrEqual(Double(end - start) / 1_000_000_000.0, 10)
        threadPool.stop()
    }
}
#endif

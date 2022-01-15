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
        while counter.load(ordering: .relaxed) != 0 {}
        threadPool.stop()
    }
    
    func testThreadPoolEnqueueingFromMultipleThreads() {
        let enqueueCount = 1000000
        let enqueueingThreadCount = 8
        let threadPool = ThreadPool(numberOfThreads: 8)
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
    
    func testThreadPoolHavingManyThreadsEnqueueing() {
        let enqueueCount = 1000000
        let enqueueingThreadCount = 8
        let threadPool = ThreadPool(numberOfThreads: 100)
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
}
#endif

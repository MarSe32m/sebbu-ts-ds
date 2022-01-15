//
//  SebbuTSDSLockedBenchmarks.swift
//  
//
//  Created by Sebastian Toivonen on 14.1.2022.
//

import XCTest
import SebbuTSDS

final class SebbuTSDSLockedBenchmarks: XCTestCase {
    func testLockedQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = LockedQueue<Int>(size: 1000)
        for i in 0..<10000 {
            _ = queue.enqueue(i)
        }
        for _ in 0..<10000 {
            _ = queue.dequeue()
        }
        measure {
            for i in 0..<1000 {
                _ = queue.enqueue(i)
            }
            for _ in 0..<1000 {
                _ = queue.dequeue()
            }
        }
    }
    
    #if canImport(Atomics)
    func testSpinlockedQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = SpinlockedQueue<Int>(size: 1000)
        for i in 0..<10000 {
            _ = queue.enqueue(i)
        }
        for _ in 0..<10000 {
            _ = queue.dequeue()
        }
        measure {
            for i in 0..<1000 {
                _ = queue.enqueue(i)
            }
            for _ in 0..<1000 {
                _ = queue.dequeue()
            }
        }
    }
    #endif
    
    func testLockedDequeEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = LockedDeque<Int>()
        for i in 0..<10000 {
            queue.append(i)
        }
        for _ in 0..<10000 {
            _ = queue.popFirst()
        }
        measure {
            for i in 0..<1000 {
                queue.append(i)
            }
            for _ in 0..<1000 {
                _ = queue.popFirst()
            }
        }
    }
    
    #if canImport(Atomics)
    func testSpinlockedDequeEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = SpinlockedDeque<Int>()
        for i in 0..<10000 {
            queue.append(i)
        }
        for _ in 0..<10000 {
            _ = queue.popFirst()
        }
        measure {
            for i in 0..<1000 {
            queue.append(i)
            }
            for _ in 0..<1000 {
                _ = queue.popFirst()
            }
        }
    }
    #endif
}

//
//  File.swift
//  
//
//  Created by Sebastian Toivonen on 17.6.2021.
//

import Foundation
import XCTest
import SebbuTSDS

#if canImport(Atomics)
import Atomics

final class SebbuTSDSBenchmarkTests: XCTestCase {
    func testSPSCBoundedQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = SPSCBoundedQueue<Int>(size: 1000)
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
    
    func testSPSCQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = SPSCQueue<Int>(cacheSize: 512)
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
    
    func testSPMCBoundedQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = SPMCBoundedQueue<Int>(size: 1000)
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
    
    func testMPSCQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = MPSCQueue<Int>(cacheSize: 512)
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
    
    func testMPSCBoundedQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = MPSCBoundedQueue<Int>(size: 1000)
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
    
    func testMPMCBoundedQueueEnqueueDequeueBenchmark() {
        guard !isDebug() else { return }
        let queue = MPMCBoundedQueue<Int>(size: 1000)
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
}
#endif

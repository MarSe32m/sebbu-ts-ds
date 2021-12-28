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
#endif

final class SebbuTSDSBenchmarkTests: XCTestCase {
    func testSPSCBoundedQueueRoundTrip128() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCBoundedQueue<Int>(size: 128)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
    
    func testSPSCBoundedQueueRoundTrip1024() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCBoundedQueue<Int>(size: 1024)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
    
    func testSPSCBoundedQueueRoundTrip65536() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCBoundedQueue<Int>(size: 65536)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
    
    func testSPSCQueueRoundTrip() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCQueue<Int>()
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
    
    func testLockedQueueRoundTrip() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = LockedQueue<Int>(size: 1024, resizeAutomatically: false)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
    
    func testMPMCBoundedQueueRoundTrip() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = MPMCBoundedQueue<Int>(size: 1024)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
    
    func testMPSCQueueRoundTrip() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = MPSCQueue<Int>()
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
    
    func testSpinlockedQueueRoundTrip() {
#if canImport(Atomics)
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SpinlockedQueue<Int>(size: 1024, resizeAutomatically: false)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
#endif
    }
}

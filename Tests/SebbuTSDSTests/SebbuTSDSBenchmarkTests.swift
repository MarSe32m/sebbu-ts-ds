//
//  File.swift
//  
//
//  Created by Sebastian Toivonen on 17.6.2021.
//

import Foundation
import XCTest
import SebbuTSDS
import Atomics

final class SebbuTSDSBenchamrkTests: XCTestCase {
    func testSPSCBoundedQueueRoundTrip128() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCBoundedQueue<Int>(size: 128)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
    
    func testSPSCBoundedQueueRoundTrip1024() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCBoundedQueue<Int>(size: 1024)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
    
    func testSPSCBoundedQueueRoundTrip65536() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCBoundedQueue<Int>(size: 65536)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
    
    func testSPSCBoundedQueueRoundTrip1000000() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCBoundedQueue<Int>(size: 1000000)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
    
    func testSPSCQueueRoundTrip() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = SPSCQueue<Int>()
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
    
    func testLockedQueueRoundTrip() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = LockedQueue<Int>(size: 1024, resizeAutomatically: false)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
    
    func testMPMCBoundedQueueRoundTrip() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = MPMCBoundedQueue<Int>(size: 1024)
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
    
    func testMPSCQueueRoundTrip() {
        var isDebug = false
        assert({isDebug = true; return isDebug}())
        if isDebug { return }
        let queue = MPSCQueue<Int>()
        let canProduce = ManagedAtomic<Bool>(true)
        Thread.detachNewThread {
            while true {
                canProduce.store(false, ordering: .sequentiallyConsistent)
                for i in 0 ... 1_000_000 {
                    while !queue.enqueue(i) {}
                }
                while !canProduce.load(ordering: .sequentiallyConsistent) {}
            }
        }
        
        measure {
            while true {
                if let value = queue.dequeue() {
                    if value == 1_000_000 {
                        break
                    }
                }
            }
            canProduce.store(true, ordering: .sequentiallyConsistent)
        }
    }
}

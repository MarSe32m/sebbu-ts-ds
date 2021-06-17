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

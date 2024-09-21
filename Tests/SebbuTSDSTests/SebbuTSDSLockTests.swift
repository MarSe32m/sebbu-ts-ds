//
//  SebbuTSDSLockTests.swift
//  
//
//  Created by Sebastian Toivonen on 28.12.2021.
//

import XCTest
import SebbuTSDS
import Foundation
import Synchronization

final class SebbuTSDSLockTests: XCTestCase {
    func testSpinlockCounting() async {
        let spinlock = Spinlock()
        nonisolated(unsafe) var counter = 1_000_000 * 11
        let atomicCounter = Atomic<Int>(1_000_000 * 11)
        for _ in 0..<11 {
            Task.detached {
                for _ in 0..<1_000_000 {
                    spinlock.withLock {
                        counter -= 1
                    }
                    atomicCounter.subtract(1, ordering: .relaxed)
                }
            }
        }
        while atomicCounter.load(ordering: .relaxed) > 0 { await Task.yield() }
        spinlock.withLock {
            XCTAssert(counter == 0)
        }
    }
    
    func testNSLockCounting() async {
        let lock = NSLock()
        nonisolated(unsafe) var counter = 1_000_000 * 11
        let atomicCounter = Atomic<Int>(1_000_000 * 11)
        for _ in 0..<11 {
            Task.detached {
                for _ in 0..<1_000_000 {
                    lock.withLock {
                        counter -= 1
                    }
                    atomicCounter.subtract(1, ordering: .relaxed)
                }
            }
        }
        while atomicCounter.load(ordering: .relaxed) > 0 { await Task.yield() }
        lock.withLock {
            XCTAssert(counter == 0)
        }
    }
    
    func testTryLocking() {
        let spinlock = Spinlock()
        let lock = Mutex(())
        let nsLock = NSLock()
        
        XCTAssertTrue(spinlock.tryLock())
        XCTAssertTrue(lock._unsafeTryLock())
        XCTAssertTrue(nsLock.try())
        
        spinlock.unlock()
        lock._unsafeUnlock()
        nsLock.unlock()
        
        Thread.detachNewThread {
            spinlock.lock()
            lock._unsafeLock()
            nsLock.lock()
            Thread.sleep(forTimeInterval: 3)
            spinlock.unlock()
            lock._unsafeUnlock()
            nsLock.unlock()
        }
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(spinlock.tryLock())
        XCTAssertFalse(lock._unsafeTryLock())
        XCTAssertFalse(nsLock.try())
        
        Thread.sleep(forTimeInterval: 5)
        
        XCTAssertTrue(spinlock.tryLock())
        XCTAssertTrue(lock._unsafeTryLock())
        XCTAssertTrue(nsLock.try())
        
        spinlock.unlock()
        lock._unsafeUnlock()
        nsLock.unlock()
    }
}

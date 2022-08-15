//
//  SebbuTSDSLockTests.swift
//  
//
//  Created by Sebastian Toivonen on 28.12.2021.
//
#if canImport(Atomics)
import Atomics
#endif
import XCTest
import SebbuTSDS
import Foundation

final class SebbuTSDSLockTests: XCTestCase {
    #if canImport(Atomics)
    func testSpinlockCounting() {
        let spinlock = Spinlock()
        var counter = 1_000_000 * 11
        let atomicCounter = ManagedAtomic<Int>(1_000_000 * 11)
        for _ in 0..<11 {
            Thread.detachNewThread {
                for _ in 0..<1_000_000 {
                    spinlock.withLock {
                        counter -= 1
                    }
                    atomicCounter.wrappingDecrement(ordering: .relaxed)
                }
            }
        }
        while atomicCounter.load(ordering: .relaxed) > 0 {}
        spinlock.withLock {
            XCTAssert(counter == 0)
        }
    }
    
    func testLockCounting() {
        let lock = Lock()
        var counter = 1_000_000 * 11
        let atomicCounter = ManagedAtomic<Int>(1_000_000 * 11)
        for _ in 0..<11 {
            Thread.detachNewThread {
                for _ in 0..<1_000_000 {
                    lock.withLock {
                        counter -= 1
                    }
                    atomicCounter.wrappingDecrement(ordering: .relaxed)
                }
            }
        }
        while atomicCounter.load(ordering: .relaxed) > 0 {}
        lock.withLock {
            XCTAssert(counter == 0)
        }
    }
    
    func testNSLockCounting() {
        let lock = NSLock()
        var counter = 1_000_000 * 11
        let atomicCounter = ManagedAtomic<Int>(1_000_000 * 11)
        for _ in 0..<11 {
            Thread.detachNewThread {
                for _ in 0..<1_000_000 {
                    lock.withLock {
                        counter -= 1
                    }
                    atomicCounter.wrappingDecrement(ordering: .relaxed)
                }
            }
        }
        while atomicCounter.load(ordering: .relaxed) > 0 {}
        lock.withLock {
            XCTAssert(counter == 0)
        }
    }
    #endif
    
    func testTryLocking() {
        let spinlock = Spinlock()
        let lock = Lock()
        let nsLock = NSLock()
        
        XCTAssertTrue(spinlock.tryLock())
        XCTAssertTrue(lock.tryLock())
        XCTAssertTrue(nsLock.try())
        
        spinlock.unlock()
        lock.unlock()
        nsLock.unlock()
        
        Thread.detachNewThread {
            spinlock.lock()
            lock.lock()
            nsLock.lock()
            Thread.sleep(forTimeInterval: 3)
            spinlock.unlock()
            lock.unlock()
            nsLock.unlock()
        }
        
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(spinlock.tryLock())
        XCTAssertFalse(lock.tryLock())
        XCTAssertFalse(nsLock.try())
        
        Thread.sleep(forTimeInterval: 5)
        
        XCTAssertTrue(spinlock.tryLock())
        XCTAssertTrue(lock.tryLock())
        XCTAssertTrue(nsLock.try())
        
        spinlock.unlock()
        lock.unlock()
        nsLock.unlock()
    }
}

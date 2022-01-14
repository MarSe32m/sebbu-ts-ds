//
//  SebbuTSDSLockTests.swift
//  
//
//  Created by Sebastian Toivonen on 28.12.2021.
//
#if canImport(Atomics)
import XCTest
import SebbuTSDS
import Atomics
import Foundation

final class SebbuTSDSLockTests: XCTestCase {
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
}
#endif

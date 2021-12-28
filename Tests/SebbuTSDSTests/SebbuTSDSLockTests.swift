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
        var counter = 1_000_000 * 10
        let atomicCounter = ManagedAtomic<Int>(1_000_000 * 10)
        for _ in 0..<10 {
            Thread.detachNewThread {
                for _ in 0..<1_000_000 {
                    spinlock.withLock {
                        counter -= 1
                    }
                    atomicCounter.wrappingDecrement(ordering: .sequentiallyConsistent)
                }
            }
        }
        while atomicCounter.load(ordering: .relaxed) > 0 {}
        XCTAssert(counter == 0)
    }
}
#endif

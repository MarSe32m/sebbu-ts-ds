//
//  File.swift
//  
//
//  Created by Sebastian Toivonen on 29.12.2021.
//

import XCTest
import SebbuTSDS
import Dispatch
import Foundation
#if canImport(Atomics)
import Atomics
#endif
final class SebbuTSDSDequeTests: XCTestCase {
    private func test<T: ConcurrentDeque>(name: String, queue: T, writers: Int, readers: Int, elements: Int = 10_000) where T.Element == (item: Int, thread: Int) {
        let threadCount = writers + readers
        let countLock = NSLock()
        var count = 0
        var done = writers
        var accumulatedCount = 0
        DispatchQueue.concurrentPerform(iterations: threadCount) { i in
            if i < writers {
                for index in 0..<elements {
                    let element = (item: index, thread: i)
                    queue.append(element)
                    countLock.lock()
                    accumulatedCount &+= index
                    countLock.unlock()
                }
                countLock.lock()
                done &-= 1
                countLock.unlock()
            }
            if i >= writers {
                while true {
                    countLock.lock()
                    let isDone = done <= 0
                    countLock.unlock()
                    if isDone { break }
                    if let element = queue.popFirst() {
                        countLock.lock()
                        count &+= element.item
                        countLock.unlock()
                        continue
                    }
                }
                queue.removeAll { element in
                    countLock.lock()
                    count &+= element.item
                    countLock.unlock()
                    return true
                }
            }
        }
        let finalCount = count
        let finalAccumulated = accumulatedCount
        XCTAssert(finalCount == finalAccumulated, "The queue wasn't deterministic")
        XCTAssertNil(queue.popFirst())
    }

    func testLockedDeque() {
        let lockedDeque = LockedDeque<(item: Int, thread: Int)>()
        lockedDeque.append((item: 1, thread: 0))
        XCTAssertEqual(lockedDeque.count, 1)
        let _ = lockedDeque.popFirst()
        XCTAssertTrue(lockedDeque.isEmpty)
        
        // Should probably be based on the amount of cores the test machine has available
        let count = ProcessInfo.processInfo.processorCount >= 2 ? ProcessInfo.processInfo.processorCount : 2
        
        for i in 2...count {
            test(name: "LockedQueue", queue: lockedDeque, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "LockedQueue", queue: lockedDeque, writers: i - 1, readers: 1, elements: 1_000_00)
        }
    }
    
    func testSpinlockedDeque() {
#if canImport(Atomics)
        let spinlockedDeque = SpinlockedDeque<(item: Int, thread: Int)>()
        
        spinlockedDeque.append((item: 1, thread: 0))
        XCTAssertEqual(spinlockedDeque.count, 1)
        let _ = spinlockedDeque.popFirst()
        XCTAssertTrue(spinlockedDeque.isEmpty)
        
        // Should probably be based on the amount of cores the test machine has available
        let count = ProcessInfo.processInfo.processorCount >= 2 ? ProcessInfo.processInfo.processorCount : 2
        
        for i in 2...count {
            test(name: "SpinlockedQueue", queue: spinlockedDeque, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(name: "SpinlockedQueue", queue: spinlockedDeque, writers: i - 1, readers: 1, elements: 1_000_00)
        }
#endif
    }
    
    func testDraining() {
#if canImport(Atomics)
        do {
            let spinlockedDeque = SpinlockedDeque<(item: Int, thread: Int)>()
            for i in 0..<1_000_000 {
                spinlockedDeque.append((item: i, thread: 0))
            }
            spinlockedDeque.removeAll()
            XCTAssertNil(spinlockedDeque.popFirst())
        }
#endif
        
        let lockedDeque = LockedDeque<(item: Int, thread: Int)>()
        for i in 0..<1_000_000 {
            lockedDeque.append((item: i, thread: 0))
        }
        lockedDeque.removeAll()
        XCTAssertNil(lockedDeque.popFirst())
        
    }
}

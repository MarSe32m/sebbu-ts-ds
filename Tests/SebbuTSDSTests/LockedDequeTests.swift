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

final class SebbuTSDSDequeTests: XCTestCase {
    func testLockedDeque() async {
        let lockedDeque = LockedDeque<(item: Int, task: Int)>()
        lockedDeque.append((item: 1, task: 0))
        XCTAssertEqual(lockedDeque.count, 1)
        let _ = lockedDeque.popFirst()
        XCTAssertTrue(lockedDeque.isEmpty)
        
        // Should probably be based on the amount of cores the test machine has available
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        
        for i in 2...count {
            await test(queue: lockedDeque, writers: i / 2, readers: i / 2, elements: 1_000_00)
            await test(queue: lockedDeque, writers: i - 1, readers: 1, elements: 1_000_00)
        }
    }
    
    func testSpinlockedDeque() async {
        let spinlockedDeque = SpinlockedDeque<(item: Int, task: Int)>()
        
        spinlockedDeque.append((item: 1, task: 0))
        XCTAssertEqual(spinlockedDeque.count, 1)
        let _ = spinlockedDeque.popFirst()
        XCTAssertTrue(spinlockedDeque.isEmpty)
        
        // Should probably be based on the amount of cores the test machine has available
        var count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        if count < 2 {
            count = 2
        }
        
        for i in 2...count {
            await test(queue: spinlockedDeque, writers: i / 2, readers: i / 2, elements: 1_000_00)
            await test(queue: spinlockedDeque, writers: i - 1, readers: 1, elements: 1_000_00)
        }
    }
    
    func testDequeDraining() {
        testDraining(SpinlockedDeque<Int>())
        testDraining(LockedDeque<Int>())
    }
}

//
//  SebbuTSDSLockedStackTests.swift
//  
//
//  Created by Sebastian Toivonen on 7.8.2022.
//
import XCTest
import SebbuTSDS

final class SebbuTSDSLockedStackTests: XCTestCase {
    func testLockedStack() {
        let lockedStack = LockedStack<(item: Int, thread: Int)>()
        let lockedBoundedStack = LockedBoundedStack<(item: Int, thread: Int)>(capacity: 128)
        
        // Should probably be based on the amount of cores the test machine has available
        let count = ProcessInfo.processInfo.processorCount >= 2 ? ProcessInfo.processInfo.processorCount : 2
        
        for i in 2...count {
            test(stack: lockedStack, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(stack: lockedBoundedStack, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(stack: lockedStack, writers: i - 1, readers: 1, elements: 1_000_00)
            test(stack: lockedBoundedStack, writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        let stackOfReferenceTypes = LockedStack<Object>()
        let boundedStackOfReferenceTypes = LockedBoundedStack<Object>(capacity: 50000)
        
        test(stack: stackOfReferenceTypes, singleWriter: false, singleReader: false)
        test(stack: boundedStackOfReferenceTypes, singleWriter: false, singleReader: false)
    }
    
    func testLockedStackSequenceConformance() {
        let stack = LockedStack<Int>()
        testStackSequenceConformance(stack)
    }
    
    func testLockedStackCount() {
        func remove<T: ConcurrentStack>(_ stack: T) -> Int where T.Element == Int {
            return stack.pop() != nil ? -1 : 0
        }
        
        func add<T: ConcurrentStack>(_ stack: T) -> Int where T.Element == Int {
            return stack.push(Int.random(in: .min ... .max)) ? 1 : 0
        }
        
        let stack = LockedStack<Int>()
        for i in 1...1_000_000 {
            stack.push(i)
            XCTAssert(stack.count == i)
        }
        var elements = stack.count
        for _ in 0..<500000 {
            elements += remove(stack)
        }
        XCTAssertEqual(stack.count, elements)
        
        let boundedStack = LockedBoundedStack<Int>(capacity: 32)
        elements = 0
        for i in 1...24 {
            elements += 1
            boundedStack.push(i)
            let count = boundedStack.count
            XCTAssertEqual(elements, count)
        }
        
        for _ in 0..<10000000 {
            elements += Bool.random() ? add(boundedStack) : remove(boundedStack)
            XCTAssertEqual(boundedStack.count, elements)
        }
    }
    
    func testSpinlockedStack() {
        let lockedStack = SpinlockedStack<(item: Int, thread: Int)>()
        let lockedBoundedStack = SpinlockedBoundedStack<(item: Int, thread: Int)>(capacity: 128)
        
        // Should probably be based on the amount of cores the test machine has available
        let count = ProcessInfo.processInfo.processorCount >= 2 ? ProcessInfo.processInfo.processorCount : 2
        
        for i in 2...count {
            test(stack: lockedStack, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(stack: lockedBoundedStack, writers: i / 2, readers: i / 2, elements: 1_000_00)
            test(stack: lockedStack, writers: i - 1, readers: 1, elements: 1_000_00)
            test(stack: lockedBoundedStack, writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        let stackOfReferenceTypes = LockedStack<Object>()
        let boundedStackOfReferenceTypes = LockedBoundedStack<Object>(capacity: 50000)
        
        test(stack: stackOfReferenceTypes, singleWriter: false, singleReader: false)
        test(stack: boundedStackOfReferenceTypes, singleWriter: false, singleReader: false)
    }
    
    func testSpinlockedStackSequenceConformance() {
        let stack = SpinlockedStack<Int>()
        testStackSequenceConformance(stack)
    }
    
    func testSpinlockedStackCount() {
        func remove<T: ConcurrentStack>(_ stack: T) -> Int where T.Element == Int {
            return stack.pop() != nil ? -1 : 0
        }
        
        func add<T: ConcurrentStack>(_ stack: T) -> Int where T.Element == Int {
            return stack.push(Int.random(in: .min ... .max)) ? 1 : 0
        }
        
        let stack = SpinlockedStack<Int>()
        for i in 1...1_000_000 {
            stack.push(i)
            XCTAssert(stack.count == i)
        }
        var elements = stack.count
        for _ in 0..<500000 {
            elements += remove(stack)
        }
        XCTAssertEqual(stack.count, elements)
        
        let boundedStack = SpinlockedBoundedStack<Int>(capacity: 32)
        elements = 0
        for i in 1...24 {
            elements += 1
            boundedStack.push(i)
            let count = boundedStack.count
            XCTAssertEqual(elements, count)
        }
        
        for _ in 0..<10000000 {
            elements += Bool.random() ? add(boundedStack) : remove(boundedStack)
            XCTAssertEqual(boundedStack.count, elements)
        }
    }
    
    func testStackDraining() {
        testDraining(SpinlockedStack<Int>())
        testDraining(SpinlockedBoundedStack<Int>(capacity: 1000))
        
        testDraining(LockedStack<Int>())
        testDraining(LockedBoundedStack<Int>(capacity: 1000))
    }
}

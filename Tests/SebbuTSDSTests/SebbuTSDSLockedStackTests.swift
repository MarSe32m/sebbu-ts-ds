//
//  SebbuTSDSLockedStackTests.swift
//  
//
//  Created by Sebastian Toivonen on 7.8.2022.
//
import XCTest
import SebbuTSDS

final class SebbuTSDSLockedStackTests: XCTestCase {
    func testLockedStack() async {
        let lockedStack = LockedStack<(item: Int, task: Int)>()
        let lockedBoundedStack = LockedBoundedStack<(item: Int, task: Int)>(capacity: 128)
        
        // Should probably be based on the amount of cores the test machine has available
        let count = ProcessInfo.processInfo.activeProcessorCount < 8 ? ProcessInfo.processInfo.activeProcessorCount : 8
        
        for i in 2...count {
            await test(stack: lockedStack, writers: i / 2, readers: i / 2, elements: 100_000)
            await test(stack: lockedBoundedStack, writers: i / 2, readers: i / 2, elements: 100_000)
            await test(stack: lockedStack, writers: i - 1, readers: 1, elements: 100_000)
            await test(stack: lockedBoundedStack, writers: i - 1, readers: 1, elements: 100_000)
        }
        
        let stackOfReferenceTypes = LockedStack<Object>()
        let boundedStackOfReferenceTypes = LockedBoundedStack<Object>(capacity: 50000)
        
        await test(stack: stackOfReferenceTypes, singleWriter: false, singleReader: false)
        await test(stack: boundedStackOfReferenceTypes, singleWriter: false, singleReader: false)
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
            XCTAssertTrue(stack.push(i))
            XCTAssertEqual(stack.count, i)
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
    
    func testLockedStackNonCopyableObject() async {
        let queue = LockedStack<NonCopyableObject>()
        let writers = 8
        let readers = 8
        let elementCount = 80_000
        await withDiscardingTaskGroup { group in
            for _ in 0..<writers {
                group.addTask {
                    let writes = elementCount / writers
                    for i in 0..<writes {
                        var object = NonCopyableObject(i)
                        while let newObject = queue.push(object) {
                            await Task.yield()
                            object = consume newObject
                        }
                    }
                }
            }
            for _ in 0..<readers {
                group.addTask {
                    let reads = elementCount / readers
                    for _ in 0..<reads {
                        while queue.pop() == nil { await Task.yield() }
                    }
                }
            }
        }
        XCTAssertEqual(NonCopyableObject.count.load(ordering: .relaxed), 0)
    }
    
    func testLockedBoundedStackNonCopyableObject() async {
        let queue = LockedBoundedStack<NonCopyableObject>(capacity: 128)
        let writers = 8
        let readers = 8
        let elementCount = 80_000
        await withDiscardingTaskGroup { group in
            for _ in 0..<writers {
                group.addTask {
                    let writes = elementCount / writers
                    for i in 0..<writes {
                        var object = NonCopyableObject(i)
                        while let newObject = queue.push(object) {
                            await Task.yield()
                            object = consume newObject
                        }
                    }
                }
            }
            for _ in 0..<readers {
                group.addTask {
                    let reads = elementCount / readers
                    for _ in 0..<reads {
                        while queue.pop() == nil { await Task.yield() }
                    }
                }
            }
        }
        XCTAssertEqual(NonCopyableObject.count.load(ordering: .relaxed), 0)
    }
    
    func testSpinlockedStack() async {
        let lockedStack = SpinlockedStack<(item: Int, task: Int)>()
        let lockedBoundedStack = SpinlockedBoundedStack<(item: Int, task: Int)>(capacity: 128)
        
        // Should probably be based on the amount of cores the test machine has available
        let count = ProcessInfo.processInfo.activeProcessorCount >= 2 ? ProcessInfo.processInfo.activeProcessorCount : 2
        
        for i in 2...count {
            await test(stack: lockedStack, writers: i / 2, readers: i / 2, elements: 1_000_00)
            await test(stack: lockedBoundedStack, writers: i / 2, readers: i / 2, elements: 1_000_00)
            await test(stack: lockedStack, writers: i - 1, readers: 1, elements: 1_000_00)
            await test(stack: lockedBoundedStack, writers: i - 1, readers: 1, elements: 1_000_00)
        }
        
        let stackOfReferenceTypes = LockedStack<Object>()
        let boundedStackOfReferenceTypes = LockedBoundedStack<Object>(capacity: 50000)
        
        await test(stack: stackOfReferenceTypes, singleWriter: false, singleReader: false)
        await test(stack: boundedStackOfReferenceTypes, singleWriter: false, singleReader: false)
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
            XCTAssertTrue(stack.push(i))
            XCTAssertEqual(stack.count, i)
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
    
    func testSpinlockedStackNonCopyableObject() async {
        let queue = SpinlockedStack<NonCopyableObject>()
        let writers = 8
        let readers = 8
        let elementCount = 80_000
        await withDiscardingTaskGroup { group in
            for _ in 0..<writers {
                group.addTask {
                    let writes = elementCount / writers
                    for i in 0..<writes {
                        var object = NonCopyableObject(i)
                        while let newObject = queue.push(object) {
                            await Task.yield()
                            object = consume newObject
                        }
                    }
                }
            }
            for _ in 0..<readers {
                group.addTask {
                    let reads = elementCount / readers
                    for _ in 0..<reads {
                        while queue.pop() == nil { await Task.yield() }
                    }
                }
            }
        }
        XCTAssertEqual(NonCopyableObject.count.load(ordering: .relaxed), 0)
    }
    
    func testSpinlockedBoundedStackNonCopyableObject() async {
        let queue = SpinlockedBoundedStack<NonCopyableObject>(capacity: 128)
        let writers = 8
        let readers = 8
        let elementCount = 80_000
        await withDiscardingTaskGroup { group in
            for _ in 0..<writers {
                group.addTask {
                    let writes = elementCount / writers
                    for i in 0..<writes {
                        var object = NonCopyableObject(i)
                        while let newObject = queue.push(object) {
                            await Task.yield()
                            object = consume newObject
                        }
                    }
                }
            }
            for _ in 0..<readers {
                group.addTask {
                    let reads = elementCount / readers
                    for _ in 0..<reads {
                        while queue.pop() == nil { await Task.yield() }
                    }
                }
            }
        }
        XCTAssertEqual(NonCopyableObject.count.load(ordering: .relaxed), 0)
    }
    
    func testStackDraining() {
        testDraining(SpinlockedStack<Int>())
        testDraining(SpinlockedBoundedStack<Int>(capacity: 1000))
        
        testDraining(LockedStack<Int>())
        testDraining(LockedBoundedStack<Int>(capacity: 1000))
    }
}

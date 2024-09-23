//
//  SebbuTSDSTestUtils.swift
//  
//
//  Created by Sebastian Toivonen on 14.1.2022.
//

import SebbuTSDS
import Dispatch
import XCTest
import Synchronization

internal class Object {
    let age: Int
    static let count: Atomic<Int> = Atomic<Int>(0)
    
    init(_ age: Int) {
        self.age = age
        Object.count.add(1, ordering: .relaxed)
    }

    deinit {
        Object.count.subtract(1, ordering: .relaxed)
    }
}

internal struct NonCopyableObject: ~Copyable {
    let age: Int
    static let count: Atomic<Int> = Atomic<Int>(0)
    
    init(_ age: Int) {
        self.age = age
        NonCopyableObject.count.add(1, ordering: .relaxed)
    }
    
    deinit {
        NonCopyableObject.count.subtract(1, ordering: .relaxed)
    }
}

internal func test<T: ConcurrentQueue>(queue: T, singleWriter: Bool, singleReader: Bool) async where T.Element == Object {
    let writers = singleWriter ? 1 : 8
    let readers = singleReader ? 1 : 8
    let elementCount = 80_000
    await withDiscardingTaskGroup { group in
        for _ in 0..<writers {
            group.addTask {
                let writes = elementCount / writers
                for i in 0..<writes {
                    while !queue.enqueue(Object(i)) { await Task.yield() }
                }
            }
        }
        for _ in 0..<readers {
            group.addTask {
                let reads = elementCount / readers
                for _ in 0..<reads {
                    while queue.dequeue() == nil { await Task.yield() }
                }
            }
        }
    }
    XCTAssertEqual(Object.count.load(ordering: .relaxed), 0)
}

internal func test<T: ConcurrentQueue>(queue: T, writers: Int, readers: Int, elements: Int = 10_000) async where T.Element == (item: Int, task: Int) {
    let count = Atomic<Int>(0)
    let done = Atomic<Int>(writers)
    let accumulatedCount = Atomic<Int>(0)
    await withDiscardingTaskGroup { group in 
        // Writers
        for i in 0..<writers {
            group.addTask {
                for index in 0..<elements {
                    let element = (item: index, task: i)
                    while !queue.enqueue(element) {
                        await Task.yield()
                    }
                    accumulatedCount.add(index, ordering: .relaxed)
                }
                done.subtract(1, ordering: .relaxed)
            }
        }
        // Readers
        for _ in 0..<readers {
            group.addTask {
                var nextItem = 0
                var writerDictionary: [Int: Int] = [:]
                for i in 0..<writers {
                    writerDictionary[i] = -1
                }
                while true {
                    while let element = queue.dequeue() {
                        count.add(element.item, ordering: .relaxed)
                        if writers == 1 && readers == 1 {
                            XCTAssertEqual(nextItem, element.item)
                            nextItem += 1
                        } else {
                            XCTAssertGreaterThan(element.item, writerDictionary[element.task]!)
                            writerDictionary[element.task] = element.item
                        }
                    }
                    await Task.yield()
                    let isDone = done.load(ordering: .relaxed) <= 0
                    if isDone { break }
                }
                queue.dequeueAll { (element) in
                    count.add(element.item, ordering: .relaxed)
                }
            }
        }
    }
    let finalCount = count.load(ordering: .relaxed)
    let finalAccumulated = accumulatedCount.load(ordering: .relaxed)
    XCTAssertEqual(finalCount, finalAccumulated, "The queue wasn't deterministic. Queue: \(queue)")
    XCTAssertNil(queue.dequeue(), "Queue wasn't empty when it should be. Queue: \(queue)")
}

internal func test<T: ConcurrentStack>(stack: T, singleWriter: Bool, singleReader: Bool) async where T.Element == Object {
    let writers = singleWriter ? 1 : 8
    let readers = singleReader ? 1 : 8
    let elementCount = 80_000
    await withDiscardingTaskGroup { group in
        for _ in 0..<writers {
            group.addTask {
                let writes = elementCount / writers
                for i in 0..<writes {
                    while !stack.push(Object(i)) { await Task.yield() }
                }
            }
        }
        for _ in 0..<readers {
            group.addTask {
                let reads = elementCount / readers
                for _ in 0..<reads {
                    while stack.pop() == nil { await Task.yield() }
                }
            }
        }
    }
    XCTAssertEqual(Object.count.load(ordering: .relaxed), 0)
}

internal func test<T: ConcurrentStack>(stack: T, writers: Int, readers: Int, elements: Int = 10_000) async where T.Element == (item: Int, task: Int) {
    let count = Atomic<Int>(0)
    let done = Atomic<Int>(writers)
    let accumulatedCount = Atomic<Int>(0)
    await withDiscardingTaskGroup { group in
        for i in 0..<writers {
            group.addTask {
                for index in 0..<elements {
                    let element = (item: index, task: i)
                    while !stack.push(element) {
                        await Task.yield()
                    }
                    accumulatedCount.add(index, ordering: .relaxed)
                }
                done.subtract(1, ordering: .relaxed)
            }
        }
        for _ in 0..<readers {
            group.addTask {
                while true {
                    while let element = stack.pop() {
                        count.add(element.item, ordering: .relaxed)
                    }
                    let isDone = done.load(ordering: .relaxed) <= 0
                    if isDone { break }
                    await Task.yield()
                }
                stack.popAll { (element) in
                    count.add(element.item, ordering: .relaxed)
                }
            }
        }
    }
    let finalCount = count.load(ordering: .relaxed)
    let finalAccumulated = accumulatedCount.load(ordering: .relaxed)
    XCTAssertEqual(finalCount, finalAccumulated, "The stack wasn't deterministic. Stack: \(stack)")
    XCTAssertNil(stack.pop(), "Stack wasn't empty when it should be. Stack: \(stack)")
}

internal func test<T: ConcurrentDeque>(queue: T, writers: Int, readers: Int, elements: Int = 10_000) async where T.Element == (item: Int, task: Int) {
    let count = Atomic<Int>(0)
    let done = Atomic<Int>(writers)
    let accumulatedCount = Atomic<Int>(0)
    await withDiscardingTaskGroup { group in
        for i in 0..<writers {
            group.addTask {
                for index in 0..<elements {
                    let element = (item: index, task: i)
                    queue.append(element)
                    accumulatedCount.add(index, ordering: .relaxed)
                    if index % 1000 == 0 { await Task.yield() }
                }
                done.subtract(1, ordering: .relaxed)
            }
        }
        for _ in 0..<readers {
            group.addTask {
                var nextItem = 0
                var writerDictionary: [Int: Int] = [:]
                for i in 0..<writers {
                    writerDictionary[i] = -1
                }
                while true {
                    let isDone = done.load(ordering: .relaxed) <= 0
                    if isDone { break }

                    if let element = queue.popFirst() {
                        count.add(element.item, ordering: .relaxed)
                        if writers == 1 && readers == 1 {
                            XCTAssertEqual(nextItem, element.item)
                            nextItem += 1
                        } else {
                            XCTAssertGreaterThan(element.item, writerDictionary[element.task]!)
                            writerDictionary[element.task] = element.item
                        }
                    }
                    await Task.yield()
                }
                queue.removeAll { element in
                    count.add(element.item, ordering: .relaxed)
                    return true
                }
            }
        }
    }
    
    let finalCount = count.load(ordering: .relaxed)
    let finalAccumulated = accumulatedCount.load(ordering: .relaxed)
    XCTAssert(finalCount == finalAccumulated, "The queue wasn't deterministic")
    XCTAssertNil(queue.popFirst())
}

internal func testDraining<T: ConcurrentQueue>(_ queue: T) where T.Element == Int {
    for i in 0..<1_000_000 {
        if !queue.enqueue(i) {
            break
        }
    }
    for i in 0..<1_000_000 {
        if let element = queue.dequeue() {
            XCTAssertEqual(element, i)
        } else {
            break
        }
    }
    XCTAssertNil(queue.dequeue())
}

internal func testDraining<T: ConcurrentStack>(_ stack: T) where T.Element == Int {
    for i in 0..<1_000_000 {
        if !stack.push(i) { break }
    }
    for i in (0..<stack.count).reversed() {
        if let element = stack.pop() {
            XCTAssertEqual(element, i)
        } else { break }
    }
    XCTAssertNil(stack.pop())
}

internal func testDraining<T: ConcurrentDeque>(_ deque: T) where T.Element == Int {
    for i in 0..<1_000_000 {
        deque.append(i)
    }
    deque.removeAll(keepingCapacity: false)
    XCTAssertNil(deque.popFirst())
}

internal func testQueueSequenceConformance<T: ConcurrentQueue>(_ queue: T) where T: Sequence, T.Element == Int {
    for i in 0..<100 {
        _ = queue.enqueue(i)
    }
    XCTAssertEqual(queue.reduce(0, +), (0..<100).reduce(0, +))
    
    for i in 0..<100 {
        _ = queue.enqueue(i)
    }
    for (index, value) in queue.prefix(10).enumerated() {
        XCTAssertEqual(index, value)
    }
    
    for (index, value) in queue.dropFirst(10).enumerated() {
        XCTAssertEqual(index + 20, value)
    }
}

internal func testStackSequenceConformance<T: ConcurrentStack>(_ stack: T) where T: Sequence, T.Element == Int {
    for i in 0..<100 {
        _ = stack.push(i)
    }
    XCTAssertEqual(stack.reduce(0, +), (0..<100).reduce(0, +))
}

internal func isDebug() -> Bool {
    var isDebug = false
    assert({isDebug = true; return true}())
    return isDebug
}

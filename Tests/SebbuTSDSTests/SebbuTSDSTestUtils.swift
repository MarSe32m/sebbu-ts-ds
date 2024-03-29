//
//  SebbuTSDSTestUtils.swift
//  
//
//  Created by Sebastian Toivonen on 14.1.2022.
//

import SebbuTSDS
import Dispatch
import XCTest

internal class Object {
    let age: Int
    
    init(_ age: Int) {
        self.age = age
    }
}

internal func test<T: ConcurrentQueue>(queue: T, singleWriter: Bool, singleReader: Bool) where T.Element == Object {
    if singleReader && !singleWriter {
        DispatchQueue.concurrentPerform(iterations: 8) { i in
            if i == 0 {
                for _ in 0..<7 * 10000 {
                    while true {
                        if queue.dequeue() != nil {
                            break
                        }
                    }
                }
            } else {
                for j in 0..<10000 {
                    while !queue.enqueue(Object(j)){}
                }
            }
        }
    } else if singleWriter && !singleReader {
        DispatchQueue.concurrentPerform(iterations: 8) { i in
            if i == 0 {
                for j in 0..<10000 * 7 {
                    while !queue.enqueue(Object(j)){}
                }
            } else {
                for _ in 0..<10000 {
                    while true {
                        if queue.dequeue() != nil {
                            break
                        }
                    }
                }
            }
        }
    } else if singleWriter && singleReader {
        DispatchQueue.concurrentPerform(iterations: 2) { i in
            if i == 0 {
                for j in 0..<10000 * 7 {
                    while !queue.enqueue(Object(j)){}
                }
            } else {
                for _ in 0..<10000 * 7 {
                    while true {
                        if queue.dequeue() != nil {
                            break
                        }
                    }
                }
            }
        }
    } else {
        DispatchQueue.concurrentPerform(iterations: 8) { i in
            if i % 2 == 0 {
                for i in 0..<10000 {
                    _ = queue.enqueue(Object(i))
                }
            } else {
                for _ in 0..<10000 {
                    while true {
                        if queue.dequeue() != nil {
                            break
                        }
                    }
                }
            }
        }
    }
}

internal func test<T: ConcurrentQueue>(queue: T, writers: Int, readers: Int, elements: Int = 10_000) where T.Element == (item: Int, thread: Int) {
    let threadCount = writers + readers
    let countLock = Lock()
    var count = 0
    var done = writers
    var accumulatedCount = 0
    DispatchQueue.concurrentPerform(iterations: threadCount) { i in
        if i < writers {
            for index in 0..<elements {
                let element = (item: index, thread: i)
                while !queue.enqueue(element) {}
                countLock.lock()
                accumulatedCount &+= index
                countLock.unlock()
            }
            countLock.lock()
            done &-= 1
            countLock.unlock()
        }
        if i >= writers {
            var nextItem = 0
            var writerDictionary: [Int: Int] = [:]
            for i in 0..<writers {
                writerDictionary[i] = -1
            }
            while true {
                while let element = queue.dequeue() {
                    countLock.lock()
                    count &+= element.item
                    countLock.unlock()
                    if writers == 1 && readers == 1 {
                        XCTAssertEqual(nextItem, element.item)
                        nextItem += 1
                    } else {
                        XCTAssertGreaterThan(element.item, writerDictionary[element.thread]!)
                        writerDictionary[element.thread] = element.item
                    }
                    continue
                }
                countLock.lock()
                let isDone = done <= 0
                countLock.unlock()
                if isDone { break }
            }
            queue.dequeueAll { (element) in
                countLock.lock()
                count &+= element.item
                countLock.unlock()
            }
        }
    }
    let finalCount = count
    let finalAccumulated = accumulatedCount
    XCTAssertEqual(finalCount, finalAccumulated, "The queue wasn't deterministic. Queue: \(queue)")
    XCTAssertNil(queue.dequeue(), "Queue wasn't empty when it should be. Queue: \(queue)")
}

internal func test<T: ConcurrentStack>(stack: T, singleWriter: Bool, singleReader: Bool) where T.Element == Object {
    if singleReader && !singleWriter {
        DispatchQueue.concurrentPerform(iterations: 8) { i in
            if i == 0 {
                for _ in 0..<7 * 10000 {
                    while true {
                        if stack.pop() != nil {
                            break
                        }
                    }
                }
            } else {
                for j in 0..<10000 {
                    while !stack.push(Object(j)){}
                }
            }
        }
    } else if singleWriter && !singleReader {
        DispatchQueue.concurrentPerform(iterations: 8) { i in
            if i == 0 {
                for j in 0..<10000 * 7 {
                    while !stack.push(Object(j)){}
                }
            } else {
                for _ in 0..<10000 {
                    while true {
                        if stack.pop() != nil {
                            break
                        }
                    }
                }
            }
        }
    } else if singleWriter && singleReader {
        DispatchQueue.concurrentPerform(iterations: 2) { i in
            if i == 0 {
                for j in 0..<10000 * 7 {
                    while !stack.push(Object(j)){}
                }
            } else {
                for _ in 0..<10000 * 7 {
                    while true {
                        if stack.pop() != nil {
                            break
                        }
                    }
                }
            }
        }
    } else {
        DispatchQueue.concurrentPerform(iterations: 8) { i in
            if i % 2 == 0 {
                for i in 0..<10000 {
                    _ = stack.push(Object(i))
                }
            } else {
                for _ in 0..<10000 {
                    while true {
                        if stack.pop() != nil {
                            break
                        }
                    }
                }
            }
        }
    }
}

internal func test<T: ConcurrentStack>(stack: T, writers: Int, readers: Int, elements: Int = 10_000) where T.Element == (item: Int, thread: Int) {
    let threadCount = writers + readers
    let countLock = Lock()
    var count = 0
    var done = writers
    var accumulatedCount = 0
    DispatchQueue.concurrentPerform(iterations: threadCount) { i in
        if i < writers {
            for index in 0..<elements {
                let element = (item: index, thread: i)
                while !stack.push(element) {}
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
                while let element = stack.pop() {
                    countLock.lock()
                    count &+= element.item
                    countLock.unlock()
                    continue
                }
                countLock.lock()
                let isDone = done <= 0
                countLock.unlock()
                if isDone { break }
            }
            stack.popAll { (element) in
                countLock.lock()
                count &+= element.item
                countLock.unlock()
            }
        }
    }
    let finalCount = count
    let finalAccumulated = accumulatedCount
    XCTAssertEqual(finalCount, finalAccumulated, "The stack wasn't deterministic. Stack: \(stack)")
    XCTAssertNil(stack.pop(), "Stack wasn't empty when it should be. Stack: \(stack)")
}

internal func test<T: ConcurrentDeque>(queue: T, writers: Int, readers: Int, elements: Int = 10_000) where T.Element == (item: Int, thread: Int) {
    let threadCount = writers + readers
    let countLock = Lock()
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
            var nextItem = 0
            var writerDictionary: [Int: Int] = [:]
            for i in 0..<writers {
                writerDictionary[i] = -1
            }
            while true {
                countLock.lock()
                let isDone = done <= 0
                countLock.unlock()
                if isDone { break }
                if let element = queue.popFirst() {
                    countLock.lock()
                    count &+= element.item
                    countLock.unlock()
                    if writers == 1 && readers == 1 {
                        XCTAssertEqual(nextItem, element.item)
                        nextItem += 1
                    } else {
                        XCTAssertGreaterThan(element.item, writerDictionary[element.thread]!)
                        writerDictionary[element.thread] = element.item
                    }
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

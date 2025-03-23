//
//  SPSCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

import Synchronization
public final class SPSCBoundedQueue<Element: ~Copyable>: @unchecked Sendable {
    /// The size of the queue
    public var size: Int {
        buffer.count - 1
    }
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element>
    
    //TODO: Cache aligned
    @usableFromInline
    internal let tail: Atomic<Int> = .init(0)
    
    @usableFromInline
    internal var headCached: Int = 0
    
    //TODO: Cache aligned
    @usableFromInline
    internal let head: Atomic<Int> = .init(0)
    
    @usableFromInline
    internal var tailCached: Int = 0
    
    /// The amount of elements that the queue contains
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (buffer.count - 1 - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    @inlinable
    public var wasFull: Bool {
        buffer.count - 1 - count == 1
    }

    public init(size: Int) {
        precondition(size >= 2, "Queue capacity too small")
        self.mask = size.nextPowerOf2() - 1
        self.buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2() + 1)
    }
    
    deinit {
        while dequeue() != nil {}
        buffer.deallocate()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: consuming Element) -> Element? {
        let pos = tail.load(ordering: .relaxed)
        let nextPos = pos + 1
        if (headCached - nextPos) & mask < 1 {
            headCached = head.load(ordering: .acquiring)
            if (headCached - nextPos) & mask < 1 {
                return value
            }
        }
        buffer.initializeElement(at: pos & mask, to: value)
        tail.store(pos + 1, ordering: .releasing)
        return nil
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        let pos = head.load(ordering: .relaxed)
        if (tailCached - pos) & mask < 1 {
            tailCached = tail.load(ordering: .acquiring)
            if (tailCached - pos) & mask < 1 {
                return nil
            }
        }
        let value = buffer.moveElement(from: pos & mask)
        head.store(pos + 1, ordering: .releasing)
        return value
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (consuming Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }

    @inline(__always)
    public func withFirst<T>(_ body: (borrowing Element?) throws -> T) rethrows -> T {
        let pos = head.load(ordering: .relaxed)
        if (tailCached - pos) & mask < 1 {
            tailCached = tail.load(ordering: .acquiring)
            if (tailCached - pos) & mask < 1 { 
                return try body(nil)
            }
        }
        var value: Element? = buffer.moveElement(from: pos & mask)
        let result = try body(value)
        buffer.initializeElement(at: pos & mask, to: value.take()!)
        return result
    }
}

extension SPSCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: SPSCBoundedQueue
        
        @inlinable
        internal init(queue: SPSCBoundedQueue) {
            self.queue = queue
        }
        
        @inlinable
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}

extension SPSCBoundedQueue: ConcurrentQueue {}

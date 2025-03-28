//
//  LockedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
import Synchronization

public final class LockedBoundedQueue<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    internal let lock = Mutex(())
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element>
    
    @usableFromInline
    internal var headIndex = 0
    
    @usableFromInline
    internal var tailIndex = 0
    
    @inlinable
    internal var mask: Int {
        return self.buffer.count &- 1
    }
    
    @inlinable
    internal var _count: Int {
        return tailIndex < headIndex ? (buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public var count: Int {
        lock.withLock { _ in _count }
    }
    
    @inlinable
    public var wasFull: Bool {
        lock.withLock { _ in
            (tailIndex + 1) & self.mask == headIndex
        }
    }
    
    public init(size: Int) {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2())
    }
    
    deinit {
        while dequeue() != nil {}
        buffer.deallocate()
    }
    
    /// Enqueues an item at the end of the queue
    @discardableResult
    public func enqueue(_ value: consuming sending Element) -> Element? {
        lock._unsafeLock(); defer { lock._unsafeUnlock() }
        return _enqueue(value)
    }
    
    @inline(__always)
    internal func _enqueue(_ value: consuming sending Element) -> Element? {
        if (tailIndex + 1) & self.mask == headIndex {
            return value
        }
        buffer.initializeElement(at: tailIndex, to: value)
        tailIndex = (tailIndex + 1) & self.mask
        return nil
    }
    
    /// Dequeues the next element in the queue if there are any
    public func dequeue() -> sending Element? {
        lock._unsafeLock(); defer { lock._unsafeUnlock() }
        return _dequeue()
    }
    
    @inline(__always)
    @usableFromInline
    internal func _dequeue() -> Element? {
        if headIndex == tailIndex { return nil }
        let result = buffer.moveElement(from: headIndex)
        headIndex = (headIndex + 1) & self.mask
        return result
    }
    
    /// Dequeues all of the elements
    @inline(__always)
    public func dequeueAll(_ closure: (consuming sending Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
    
    /// Removes all the elements specified by the given predicate. This will aquire the lock for the whole duration of the removal.
    public func removeAll(where shouldBeRemoved: (borrowing Element) throws -> Bool) rethrows {
        lock._unsafeLock(); defer { lock._unsafeUnlock() }
        let elementCount = _count
        if elementCount == 0 { return }
        for _ in 0..<elementCount {
            guard let element = _dequeue() else {
                fatalError("Failed to dequeue an item from a non empty queue?")
            }
            if try !shouldBeRemoved(element) {
                let enqueued = _enqueue(element)
                assert(enqueued != nil)
            }
        }
    }
    
    /// Removes all the elements specified by the given predicate.
    /// Returning nil means that the element will be removed.
    /// Note: The underlying lock will be held for whole duration of the removal.
    public func removeAll(where shouldBeRemoved: (consuming Element) throws -> Element?) rethrows {
        lock._unsafeLock(); defer { lock._unsafeLock() }
        let elementCount = _count
        if elementCount == 0 { return }
        for _ in 0..<elementCount {
            guard let element = _dequeue() else {
                fatalError("Failed to dequeue an item from a non empty queue?")
            }
            if let element = try shouldBeRemoved(element) {
                let enqueued = _enqueue(element)
                assert(enqueued != nil)
            }
        }
    }
}

extension LockedBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let queue: LockedBoundedQueue
        
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}

extension LockedBoundedQueue: ConcurrentQueue {}

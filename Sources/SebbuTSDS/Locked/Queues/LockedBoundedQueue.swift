//
//  LockedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

//TODO: Implement shrinking when automaticResizing is enabled?
public final class LockedBoundedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal let lock = Lock()
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element?>
    
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
        lock.withLock {
            _count
        }
    }
    
    @inlinable
    public var wasFull: Bool {
        lock.withLock {
            (tailIndex + 1) & self.mask == headIndex
        }
    }
    
    public init(size: Int) {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2())
        buffer.initialize(repeating: nil)
    }
    
    deinit {
        buffer.baseAddress?.deinitialize(count: buffer.count)
        buffer.deallocate()
    }
    
    /// Enqueues an item at the end of the queue
    @discardableResult
    public func enqueue(_ value: Element) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _enqueue(value)
    }
    
    @inline(__always)
    internal func _enqueue(_ value: Element) -> Bool {
        if (tailIndex + 1) & self.mask == headIndex {
            return false
        }
        buffer[tailIndex] = value
        tailIndex = (tailIndex + 1) & self.mask
        return true
    }
    
    /// Dequeues the next element in the queue if there are any
    public func dequeue() -> Element? {
        lock.lock(); defer { lock.unlock() }
        return _dequeue()
    }
    
    @inline(__always)
    @usableFromInline
    internal func _dequeue() -> Element? {
        if headIndex == tailIndex { return nil }
        defer {
            buffer[headIndex] = nil
            headIndex = (headIndex + 1) & self.mask
        }
        return buffer[headIndex]
    }
    
    /// Dequeues all of the elements
    @inline(__always)
    public func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
        //TODO: Maybe an option for this type of dequeueing?
        /*
        lock.lock(); defer { lock.unlock() }
        while let element = _dequeue() {
            closure(element)
        }
        */
    }
    
    /// Removes all the elements specified by the given predicate. This will aquire the lock for the whole duration of the removal.
    public func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        lock.lock(); defer { lock.unlock() }
        let elementCount = _count
        if elementCount == 0 { return }
        for _ in 0..<elementCount {
            guard let element = _dequeue() else {
                fatalError("Failed to dequeue an item from a non empty queue?")
            }
            if try !shouldBeRemoved(element) {
                let enqueued = _enqueue(element)
                assert(enqueued)
            }
        }
    }
    
    /// Removes all the elements specified by the given predicate and returns the removed elements.
    /// This will aquire the lock for the whole duration of the removal.
    public func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows -> [Element] {
        lock.lock(); defer { lock.unlock() }
        let elementCount = _count
        if elementCount == 0 { return [] }
        var result = [Element]()
        result.reserveCapacity(elementCount / 4 > 1 ? elementCount / 4 : 2)
        for _ in 0..<elementCount {
            guard let element = _dequeue() else {
                fatalError("Failed to dequeue an item from a non empty queue?")
            }
            if try !shouldBeRemoved(element) {
                let enqueued = _enqueue(element)
                assert(enqueued)
            } else {
                result.append(element)
            }
        }
        return result
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

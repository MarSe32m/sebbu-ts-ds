//
//  SpinlockedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 28.12.2021.
//

//TODO: Implement shrinking when automaticResizing is enabled?
/// Differs from the LockedQueue by just the lock. Instead of a standard lock, this one uses a spinlock.
public final class SpinlockedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal let lock = Spinlock()
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element?>
    
    @usableFromInline
    internal var headIndex = 0
    
    @usableFromInline
    internal var tailIndex = 0
    
    @usableFromInline
    internal var _resizeAutomatically: Bool
    
    @inline(__always)
    public var resizeAutomatically: Bool {
        get {
            lock.withLock {
                _resizeAutomatically
            }
        }
        set {
            lock.lock()
            _resizeAutomatically = newValue
            lock.unlock()
        }
    }
    
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
            !_resizeAutomatically && ((tailIndex + 1) & self.mask == headIndex)
        }
    }
    
    public init(size: Int, resizeAutomatically: Bool = false) {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2())
        buffer.initialize(repeating: nil)
        _resizeAutomatically = resizeAutomatically
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
            if _resizeAutomatically {
                _grow()
            } else {
                return false
            }
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
    
    /// Empties the queue and resizes the queue to a new size.
    /// Optionally one can pass a closure to inspect / transform the removed nodes, such
    /// as requeue them.
    @inlinable
    public func resize(to newSize: Int, _ block: ((Element) -> Void)? = nil) {
        lock.lock();
        let size = newSize.nextPowerOf2()
        var removedElements = [Element]()
        removedElements.reserveCapacity(_count)
        while let element = _dequeue() { removedElements.append(element)}
        buffer.baseAddress?.deinitialize(count: buffer.count)
        buffer.deallocate()
        buffer = UnsafeMutableBufferPointer.allocate(capacity: size)
        buffer.initialize(repeating: nil)
        lock.unlock()
        if let block = block {
            removedElements.forEach { block($0) }
        }
    }
    
    /// Doubles the queue size
    @inlinable
    internal func _grow() {
        let nextSize = Swift.max(buffer.count, (buffer.count + 1).nextPowerOf2())
        var newBuffer = UnsafeMutableBufferPointer<Element?>.allocate(capacity: nextSize)
        newBuffer.initialize(repeating: nil)
        let oldMask = self.mask
        
        for index in 0..<buffer.count {
            newBuffer[index] = buffer[(index + headIndex) & oldMask]
        }
        
        tailIndex = buffer.count - 1
        headIndex = 0
        swap(&buffer, &newBuffer)
        newBuffer.baseAddress?.deinitialize(count: newBuffer.count)
        newBuffer.deallocate()
    }
}

extension SpinlockedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let queue: SpinlockedQueue
        
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}

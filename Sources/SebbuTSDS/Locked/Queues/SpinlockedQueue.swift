//
//  SpinlockedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 28.12.2021.
//

import DequeModule

/// An unbounded locked queue
public final class SpinlockedQueue<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    internal let lock = Spinlock()
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element>

    @usableFromInline
    internal var readIndex: Int = 0

    @usableFromInline
    internal var writeIndex: Int = 0

    @inlinable
    public var count: Int {
        lock.withLock { _count }
    }
    
    @inlinable
    internal var _count: Int {
        readIndex <= writeIndex ? writeIndex - readIndex : buffer.count - readIndex + writeIndex
    }

    public var wasFull: Bool {
        false       
    }


    public init() {
        buffer = .allocate(capacity: 16)
    }

    deinit {
        while dequeue() != nil {}
        buffer.deallocate()
    }

    /// Enqueues an item at the end of the queue
    @inline(__always)
    public func enqueue(_ value: consuming sending Element) -> Element? {
        lock.lock(); defer { lock.unlock() }
        _enqueue(value)
        return nil
    }
    
    @inline(__always)
    @inlinable
    internal func _enqueue(_ value: consuming sending Element) {
        if (writeIndex + 1) % buffer.count == readIndex { _grow() }
        buffer.initializeElement(at: writeIndex, to: value)
        //TODO: Is this modulo a noticable performance penalty?
        writeIndex = (writeIndex + 1) % buffer.count
    }

    /// Dequeues the next element in the queue if there are any
    @inline(__always)
    public func dequeue() -> sending Element? {
        lock.lock(); defer { lock.unlock() }
        return _dequeue()
    }
    
    @inline(__always)
    @inlinable
    internal func _dequeue() -> sending Element? {
        if readIndex == writeIndex { return nil }
        let element = buffer.moveElement(from: readIndex)
        readIndex = (readIndex + 1) % buffer.count
        return element
    }

    /// Dequeues all of the elements
    @inline(__always)
    public func dequeueAll(_ closure: (consuming sending Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
    
    @inlinable
    public func reserveCapacity(_ capacity: Int) {
        lock.lock(); defer { lock.unlock() }
        if _count >= capacity { return }
        _resize(capacity) 
    }

    @inline(__always)
    @inlinable
    internal func _grow() {
        let newSize = Int(Double(buffer.count) * 1.618)
        _resize(newSize)
    }

    @inlinable
    internal func _resize(_ newSize: Int) {
        let newBuffer = UnsafeMutableBufferPointer<Element>.allocate(capacity: newSize)
        var newWriteIndex = 0
        while let element = _dequeue() {
            newBuffer.initializeElement(at: newWriteIndex, to: element)
            newWriteIndex += 1
        }
        self.writeIndex = newWriteIndex
        self.readIndex = 0
        self.buffer.deallocate()
        self.buffer = newBuffer
    }
}

extension SpinlockedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let queue: SpinlockedQueue
        
        @inline(__always)
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}

extension SpinlockedQueue: ConcurrentQueue {}

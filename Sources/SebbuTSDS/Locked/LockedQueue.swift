//
//  LockedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

import Foundation

public final class LockedQueue<Element>: ConcurrentQueue {
    @usableFromInline
    internal let lock = NSLock()
    
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
            lock.lock()
            let returnValue = _resizeAutomatically
            lock.unlock()
            return returnValue
        }
        set (newValue) {
            lock.lock()
            _resizeAutomatically = newValue
            lock.unlock()
        }
    }
    
    @inlinable
    internal var mask: Int {
        return self.buffer.count &- 1
    }
    
    public init(size: Int, resizeAutomatically: Bool = false) {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2())
        buffer.initialize(repeating: nil)
        _resizeAutomatically = resizeAutomatically
    }
    
    deinit {
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
    public func removeAll(where predicate: (Element) -> Bool) {
        lock.lock(); defer { lock.unlock() }
        var notRemoved = [Element]()
        while let element = _dequeue() {
            if !predicate(element) {
                notRemoved.append(element)
            }
        }
        for element in notRemoved {
            let enqueued = _enqueue(element)
            // This should always be true, because either we have the same amount of elements as we started with
            // or we removed some so the queue can't be full
            assert(enqueued)
        }
    }
    
    /// Empties the queue and resizes the queue to a new size
    @inlinable
    public func resize(to newSize: Int) {
        lock.lock(); defer { lock.unlock() }
        let size = newSize.nextPowerOf2()
        buffer.deallocate()
        buffer = UnsafeMutableBufferPointer.allocate(capacity: size)
        buffer.initialize(repeating: nil)
    }
    
    /// Doubles the queue size
    @inlinable
    internal func _grow() {
        let nextSize = max(buffer.count, (buffer.count + 1).nextPowerOf2())
        var newBuffer = UnsafeMutableBufferPointer<Element?>.allocate(capacity: nextSize)
        newBuffer.initialize(repeating: nil)
        let oldMask = self.mask
        
        for index in 0..<buffer.count {
            newBuffer[index] = buffer[(index + headIndex) & oldMask]
        }
        
        tailIndex = buffer.count - 1
        headIndex = 0
        swap(&buffer, &newBuffer)
        newBuffer.deallocate()
    }
    
    /// Doubles the queue size
    /*@inlinable
    internal func _grow() {
        let nextSize = max(backingArray.count, (backingArray.count + 1).nextPowerOf2())
        let copy = backingArray
        let oldMask = self.mask
        backingArray = Array<Element?>(repeating: nil, count: nextSize)
        for index in 0..<copy.count {
            backingArray[index] = copy[(index + headIndex) & oldMask]
        }
        
        tailIndex = copy.count - 1
        headIndex = 0
    }
     */
}


//
//  LockedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

import Foundation
import Atomics

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
    internal var _resizeAutomatically: ManagedAtomic<Bool>
    
    @inline(__always)
    public var resizeAutomatically: Bool {
        get {
            return _resizeAutomatically.load(ordering: .relaxed)
        }
        set (newValue) {
            _resizeAutomatically.store(newValue, ordering: .relaxed)
        }
    }
    
    @inlinable
    internal var mask: Int {
        return self.buffer.count &- 1
    }
    
    public init(size: Int, resizeAutomatically: Bool = false) {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: size.nextPowerOf2())
        buffer.initialize(repeating: nil)
        _resizeAutomatically = ManagedAtomic<Bool>(resizeAutomatically)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    /// Enqueues an item at the end of the queue
    @discardableResult
    @inlinable
    public func enqueue(_ value: Element) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if (tailIndex + 1) & self.mask == headIndex {
            if _resizeAutomatically.load(ordering: .relaxed) {
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
    @inlinable
    public func dequeue() -> Element? {
        lock.lock(); defer { lock.unlock() }
        if headIndex == tailIndex { return nil }
        defer { headIndex = (headIndex + 1) & self.mask }
        return buffer[headIndex]
    }
    
    /// Dequeues all of the elements
    @inlinable
    public func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
        //TODO: Maybe an option for this type of dequeueing?
        /*
        lock.lock(); defer { lock.unlock() }
        let mask = self.mask
        while headIndex != tailIndex {
            closure(backingArray[headIndex]!)
            headIndex = (headIndex + 1) & mask
        }
        headIndex = tailIndex
        */
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


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
    internal var backingArray = [Element?]()
    
    @usableFromInline
    internal var headIndex = 0
    
    @usableFromInline
    internal var tailIndex = 0
    
    @usableFromInline
    internal var _resizeAutomatically: ManagedAtomic<Bool>
    
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
        return self.backingArray.count &- 1
    }
    
    public init(size: Int, resizeAutomatically: Bool = false) {
        backingArray = Array<Element?>(repeating: nil, count: size.nextPowerOf2())
        _resizeAutomatically = ManagedAtomic<Bool>(resizeAutomatically)
    }
    
    deinit {
        backingArray.removeAll()
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
        backingArray[tailIndex] = value
        tailIndex = (tailIndex + 1) & self.mask
        return true
    }
    
    /// Dequeues the next element in the queue if there are any
    @inlinable
    public func dequeue() -> Element? {
        lock.lock(); defer { lock.unlock() }
        if headIndex == tailIndex { return nil }
        defer { headIndex = (headIndex + 1) & self.mask }
        return backingArray[headIndex]
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
        backingArray = Array<Element?>(repeating: nil, count: size)
    }
    
    /// Doubles the queue size
    @inlinable
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
}


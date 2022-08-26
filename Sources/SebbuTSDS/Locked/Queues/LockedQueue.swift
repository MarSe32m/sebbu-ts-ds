//
//  LockedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 15.8.2022.
//

import DequeModule

/// An unbounded locked queue
public final class LockedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal let lock = Lock()
    
    @usableFromInline
    internal var _storage: Deque<Element> = Deque()
    
    @inlinable
    public var count: Int {
        lock.withLock {
            _storage.count
        }
    }
    
    @inlinable
    public var wasFull: Bool { false }
    
    
    public init(cacheSize: Int = 128) {
        _storage.reserveCapacity(cacheSize)
    }
    
    /// Enqueues an item at the end of the queue
    @discardableResult
    public func enqueue(_ value: Element) -> Bool {
        lock.withLockVoid {
            _storage.append(value)
        }
        return true
    }
    
    /// Dequeues the next element in the queue if there are any
    public func dequeue() -> Element? {
        lock.lock()
        let result = _storage.popFirst()
        lock.unlock()
        return result
    }
    
    /// Dequeues all of the elements
    @inline(__always)
    public func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension LockedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let queue: LockedQueue
        
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}

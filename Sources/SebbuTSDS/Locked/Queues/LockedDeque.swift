//
//  LockedDeque.swift
//  
//
//  Created by Sebastian Toivonen on 29.12.2021.
//

import DequeModule
import Synchronization

public final class LockedDeque<Element>: @unchecked Sendable {
    @usableFromInline
    internal var _deque = Deque<Element>()
    
    @usableFromInline
    internal let lock = Mutex(())
    
    public var isEmpty: Bool {
        lock.withLock { _ in
            _deque.isEmpty
        }
    }
    
    public var count: Int {
        lock.withLock { _ in
            _deque.count
        }
    }
    
    public init() {}
    
    @inlinable
    public final func popFirst() -> Element? {
        lock.withLock { _ in
            _deque.popFirst()
        }
    }
    
    @inlinable
    public final func popLast() -> Element? {
        lock.withLock { _ in
            _deque.popLast()
        }
    }
    
    @inlinable
    public final func removeFirst() -> Element {
        lock.withLock { _ in
            _deque.removeFirst()
        }
    }
    
    @inlinable
    public final func removeFirst(_ n: Int) {
        lock.withLock { _ in
            _deque.removeFirst(n)
        }
    }
    
    @inlinable
    public final func removeLast() -> Element {
        lock.withLock { _ in
            _deque.removeLast()
        }
    }
    
    @inlinable
    public final func removeAll(keepingCapacity: Bool = false) {
        lock.withLock { _ in
            _deque.removeAll(keepingCapacity: keepingCapacity)
        }
    }
    
    @inlinable
    public final func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        try lock.withLock { _ in
            try _deque.removeAll(where: shouldBeRemoved)
        }
    }
    
    @inlinable
    public final func append(_ newElement: Element) {
        lock.withLock { _ in
            _deque.append(newElement)
        }
    }
    
    @inlinable
    public final func append<T: Sequence>(contentsOf elements: T) where T.Element == Element {
        lock.withLock { _ in
            _deque.append(contentsOf: elements)
        }
    }
    
    @inlinable
    public final func append<T: Collection>(contentsOf elements: T) where T.Element == Element {
        lock.withLock { _ in
            _deque.append(contentsOf: elements)
        }
    }
    
    @inlinable
    public final func prepend(_ newElement: Element) {
        lock.withLock { _ in
            _deque.prepend(newElement)
        }
    }
    
    @inlinable
    public final func prepend<T: Sequence>(contentsOf elements: T) where T.Element == Element {
        lock.withLock { _ in
            _deque.prepend(contentsOf: elements)
        }
    }
    
    @inlinable
    public final func prepend<T: Collection>(contentsOf elements: T) where T.Element == Element {
        lock.withLock { _ in
            _deque.prepend(contentsOf: elements)
        }
    }
    
    @inlinable
    public final func contains(where predicate: (Element) throws -> Bool) rethrows -> Bool {
        try lock.withLock { _ in
            try _deque.contains(where: predicate)
        }
    }
}

extension LockedDeque: ConcurrentDeque {}
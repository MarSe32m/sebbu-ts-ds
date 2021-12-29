//
//  SpinlockedDeque.swift
//  
//
//  Created by Sebastian Toivonen on 29.12.2021.
//
#if canImport(Atomics)
import DequeModule

public final class SpinlockedDeque<Element>: ConcurrentDeque {
    @usableFromInline
    internal var _deque = Deque<Element>()
    
    @usableFromInline
    internal let lock = Spinlock()
    
    public var isEmpty: Bool {
        lock.withLock {
            _deque.isEmpty
        }
    }
    
    public var count: Int {
        lock.withLock {
            _deque.count
        }
    }
    
    public init() {}
    
    public final func popFirst() -> Element? {
        lock.withLock {
            _deque.popFirst()
        }
    }
    
    public final func popLast() -> Element? {
        lock.withLock {
            _deque.popLast()
        }
    }
    
    public final func removeFirst() -> Element {
        lock.withLock {
            _deque.removeFirst()
        }
    }
    
    public final func removeFirst(_ n: Int) {
        lock.withLock {
            _deque.removeFirst(n)
        }
    }
    
    public final func removeLast() -> Element {
        lock.withLock {
            _deque.removeLast()
        }
    }
    
    public final func removeAll(keepingCapacity: Bool = false) {
        lock.withLock {
            _deque.removeAll(keepingCapacity: keepingCapacity)
        }
    }
    
    public final func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        try lock.withLock {
            try _deque.removeAll(where: shouldBeRemoved)
        }
    }
    
    public final func append(_ newElement: Element) {
        lock.withLock {
            _deque.append(newElement)
        }
    }
    
    public final func append<T: Sequence>(contentsOf elements: T) where T.Element == Element {
        lock.withLock {
            _deque.append(contentsOf: elements)
        }
    }
    
    public final func append<T: Collection>(contentsOf elements: T) where T.Element == Element {
        lock.withLock {
            _deque.append(contentsOf: elements)
        }
    }
    
    public final func prepend(_ newElement: Element) {
        lock.withLock {
            _deque.prepend(newElement)
        }
    }
    
    public final func prepend<T: Sequence>(contentsOf elements: T) where T.Element == Element {
        lock.withLock {
            _deque.prepend(contentsOf: elements)
        }
    }
    
    public final func prepend<T: Collection>(contentsOf elements: T) where T.Element == Element {
        lock.withLock {
            _deque.prepend(contentsOf: elements)
        }
    }
    
    public final func contains(where predicate: (Element) throws -> Bool) rethrows -> Bool {
        try lock.withLock {
            try _deque.contains(where: predicate)
        }
    }
}

#endif

//
//  LockedArray.swift
//  
//
//  Created by Sebastian Toivonen on 24.12.2021.
//

import Foundation

public final class LockedArray<Element> {
    private var _buffer: [Element] = []
    private let _lock = NSLock()
    
    public var values: [Element] {
        _lock.withLock {
            _buffer
        }
    }
    
    public var count: Int {
        _lock.withLock {
            _buffer.count
        }
    }
    
    public var isEmpty: Bool {
        _lock.withLock {
            _buffer.isEmpty
        }
    }
    
    public init() {}
    
    public init(_ array: [Element]) {
        _buffer = array
    }
    
    public final func append(_ newElement: Element) {
        _lock.withLock {
            _buffer.append(newElement)
        }
    }
    
    public final func contains(where predicate: (Element) throws -> Bool) rethrows -> Bool {
        try _lock.withLock {
            try _buffer.contains(where: predicate)
        }
        
    }
    
    public final func remove(at index: Int) -> Element {
        _lock.withLock {
            _buffer.remove(at: index)
        }
    }
    
    public final func removeAll(keepingCapacity keepCapacity: Bool = false) {
        _lock.withLock {
            _buffer.removeAll(keepingCapacity: keepCapacity)
        }
    }
    
    public final func removeAll(where shouldBeRemoved: (Element) throws -> Bool) rethrows {
        try _lock.withLock {
            try _buffer.removeAll(where: shouldBeRemoved)
        }
    }
    
    public final func removeFirst(_ k: Int) {
        _lock.withLock {
            _buffer.removeFirst(k)
        }
    }
    
    public final func removeFirst() -> Element {
        _lock.withLock {
            _buffer.removeFirst()
        }
    }
    
    public final func value(at index: Int) -> Element {
        _lock.withLock {
            _buffer[index]
        }
    }
    
    public final func mutate(at index: Int, transformation: (Element) -> Element) {
        _lock.withLock {
            let value = _buffer[index]
            _buffer[index] = transformation(value)
        }
    }
    
    public subscript(index: Int) -> Element {
        get {
            return value(at: index)
        }
        set {
            _lock.withLock {
                _buffer[index] = newValue
            }
        }
    }
    
    public subscript(safe index: Int) -> Element? {
        get {
            _lock.withLock {
                guard index >= 0 && index < _buffer.count else {
                    return nil
                }
                return _buffer[index]
            }
        }
    }
}

extension LockedArray: ExpressibleByArrayLiteral {
    public convenience init(arrayLiteral elements: Element...) {
        let buffer = Array(elements)
        self.init(buffer)
    }
}

extension LockedArray where Element: Equatable {
    public final func removeAll(_ element: Element) {
        self.removeAll {$0 == element}
    }
    
    public final func remove(_ element: Element) {
        self.removeAll(element)
    }
    
    public final func removeFirst(_ element: Element) {
        _lock.withLock {
            var index = 0
            for i in 0..<_buffer.count {
                if _buffer[i] == element {
                    index = i
                    break
                }
            }
            _buffer.remove(at: index)
        }
    }
    
    public final func contains(_ element: Element) -> Bool {
        _lock.withLock {
            for value in _buffer {
                if value == element { return true }
            }
            return false
        }
    }
}

//
//  LockedBoundedStack.swift
//  
//
//  Created by Sebastian Toivonen on 7.8.2022.
//

import Synchronization

/// An bounded locked stack
public final class LockedBoundedStack<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    internal let lock = Mutex(())
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element>
    
    @usableFromInline
    internal var index: Int = -1
    
    @inlinable
    public var count: Int {
        lock.withLock { _ in
            index + 1
        }
    }
    
    public init(capacity: Int) {
        assert(capacity > 0, "The stack must have some capacity to push elements...")
        buffer = UnsafeMutableBufferPointer.allocate(capacity: capacity)
    }
    
    deinit {
        while pop() != nil {}
        buffer.deallocate()
    }
    
    @inlinable
    @discardableResult
    public final func push(_ value: consuming Element) -> Element? {
        lock._unsafeLock(); defer { lock._unsafeUnlock() }
        return _push(value)
    }
    
    @inlinable
    @inline(__always)
    internal final func _push(_ value: consuming Element) -> Element? {
        if index == buffer.count - 1 { return value }
        index += 1
        buffer.initializeElement(at: index, to: value)
        return nil
    }
    
    @inlinable
    public final func pop() -> Element? {
        lock.withLock { _ in
            _pop()
        }
    }
    
    @inlinable
    @inline(__always)
    internal final func _pop() -> Element? {
        if index < 0 { return nil }
        let result = buffer.moveElement(from: index)
        index -= 1
        return result
    }
    
    @inline(__always)
    public final func popAll(_ closure: (consuming Element) -> Void) {
        while let element = pop() {
            closure(element)
        }
    }

    @inlinable
    public func reserveCapacity(_ capacity: Int) {
        lock._unsafeLock(); defer { lock._unsafeUnlock() }
        if index + 1 >= capacity { return }
        _resize(capacity) 
    }

    @inlinable
    internal func _resize(_ newSize: Int) {
        let newBuffer = UnsafeMutableBufferPointer<Element>.allocate(capacity: newSize)
        var newIndex = -1
        for i in 0..<index + 1 {
            newBuffer.initializeElement(at: i, to: buffer.moveElement(from: i))
            newIndex += 1
        }
        self.index = newIndex
        self.buffer.deallocate()
        self.buffer = newBuffer
    }
}

extension LockedBoundedStack: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let stack: LockedBoundedStack
        
        public func next() -> Element? {
            stack.pop()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(stack: self)
    }
}

extension LockedBoundedStack: ConcurrentStack {}
//
//  LockedStack.swift
//  
//
//  Created by Sebastian Toivonen on 7.8.2022.
//

import Synchronization

/// An unbounded locked stack
public final class LockedStack<Element: ~Copyable>: @unchecked Sendable {
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
    
    public init() {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: 16)
    }
    
    deinit {
        while pop() != nil {}
        buffer.deallocate()
    }
    
    @inlinable
    public final func push(_ value: consuming Element) -> Element? {
        lock._unsafeLock(); defer { lock._unsafeUnlock() }
        _push(value)
        return nil
    }
    
    @inlinable
    @inline(__always)
    internal final func _push(_ value: consuming Element) {
        if index == buffer.count - 1 { _grow() }
        index += 1
        buffer.initializeElement(at: index, to: value)
    }
    
    @inlinable
    public final func pop() -> Element? {
        lock.withLock { _ in _pop() }
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
    
    /// Empties the stack and resizes the stack to a new size.
    /// Optionally one can pass a closure to inspect / transform the removed nodes, such
    /// as re-push them.
    @inlinable
    public func reserveCapacity(_ capacity: Int) {
        lock.withLock { _ in 
            if index + 1 >= capacity { return }
            _resize(capacity)
        }
    }
    
    /// Grows the capacity to 1.5 times the old capacity
    @inlinable
    internal func _grow() {
        let newSize = nextSize(buffer.count)
        _resize(newSize)
    }

    @inlinable
    internal func _resize(_ newSize: Int) {
        assert(newSize >= buffer.count)
        var newBuffer = UnsafeMutableBufferPointer<Element>.allocate(capacity: newSize)
        for index in 0..<buffer.count {
            newBuffer.initializeElement(at: index, to: buffer.moveElement(from: index))
        }
        buffer.deallocate()
        swap(&buffer, &newBuffer)
    }

    @inlinable
    @inline(__always)
    internal final func nextSize(_ size: Int) -> Int {
        (size * 2) &- (size >> 1)
    }
}

extension LockedStack: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let stack: LockedStack
        
        public func next() -> Element? {
            stack.pop()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(stack: self)
    }
}

extension LockedStack: ConcurrentStack {}
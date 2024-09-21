//
//  SpinlockedBoundedStack.swift
//  
//
//  Created by Sebastian Toivonen on 7.8.2022.
//

/// An bounded spinlocked stack
public final class SpinlockedBoundedStack<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    internal let lock = Spinlock()
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element>
    
    @usableFromInline
    internal var index: Int = -1
    
    @inlinable
    public var count: Int {
        lock.withLock {
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
        lock.lock(); defer { lock.unlock() }
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
        lock.lock(); defer { lock.unlock() }
        return _pop()
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
        lock.lock(); defer { lock.unlock() }
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

extension SpinlockedBoundedStack: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let stack: SpinlockedBoundedStack
        
        public func next() -> Element? {
            stack.pop()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(stack: self)
    }
}

extension SpinlockedBoundedStack: ConcurrentStack {}
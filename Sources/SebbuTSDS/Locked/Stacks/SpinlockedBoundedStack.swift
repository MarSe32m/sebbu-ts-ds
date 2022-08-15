//
//  SpinlockedBoundedStack.swift
//  
//
//  Created by Sebastian Toivonen on 7.8.2022.
//

/// An bounded spinlocked stack
public final class SpinlockedBoundedStack<Element>: @unchecked Sendable, ConcurrentStack {
    @usableFromInline
    internal let lock = Spinlock()
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<Element?>
    
    @usableFromInline
    internal var index: Int = -1
    
    @inlinable
    public var count: Int {
        lock.withLock {
            index + 1
        }
    }
    
    public init(capacity: Int) {
        assert(capacity > 0, "A bounded stack must have some room to push elements...")
        buffer = UnsafeMutableBufferPointer.allocate(capacity: capacity)
        buffer.initialize(repeating: nil)
    }
    
    deinit {
        buffer.baseAddress?.deinitialize(count: buffer.count)
        buffer.deallocate()
    }
    
    @inlinable
    @discardableResult
    public final func push(_ value: Element) -> Bool {
        lock.withLock {
            _push(value)
        }
    }
    
    @inlinable
    @inline(__always)
    internal final func _push(_ value: Element) -> Bool {
        if index == buffer.count - 1 { return false }
        index += 1
        buffer[index] = value
        return true
    }
    
    @inlinable
    public final func pop() -> Element? {
        lock.withLock {
            _pop()
        }
    }
    
    @inlinable
    @inline(__always)
    internal final func _pop() -> Element? {
        if index < 0 { return nil }
        let result = buffer[index]
        buffer[index] = nil
        index -= 1
        return result
    }
    
    @inline(__always)
    public final func popAll(_ closure: (Element) -> Void) {
        while let element = pop() {
            closure(element)
        }
    }
    
    /// Empties the stack and resizes the stack to a new size.
    /// Optionally one can pass a closure to inspect / transform the removed nodes, such
    /// as re-push them.
    @inlinable
    public func resize(to newSize: Int, _ block: ((Element) -> Void)? = nil) {
        assert(newSize > 0)
        lock.lock();
        let oldBuffer = buffer
        buffer  = UnsafeMutableBufferPointer<Element?>.allocate(capacity: newSize)
        buffer.initialize(repeating: nil)
        index = 0
        lock.unlock()
        guard let block = block else { return }
        for i in 0..<oldBuffer.count {
            if let element = oldBuffer[i] {
                block(element)
            } else { return }
        }
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

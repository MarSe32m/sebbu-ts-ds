//
//  LockedStack.swift
//  
//
//  Created by Sebastian Toivonen on 7.8.2022.
//

/// An unbounded locked stack
public final class LockedStack<Element>: @unchecked Sendable, ConcurrentStack {
    @usableFromInline
    internal let lock = Lock()
    
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
    
    public init() {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: 16)
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
        if index == buffer.count - 1 { _grow() }
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
        oldBuffer.baseAddress?.deinitialize(count: oldBuffer.count)
        oldBuffer.deallocate()
    }
    
    /// Grows the capacity to 1.5 times the old capacity
    @inlinable
    internal func _grow() {
        let nextSize = nextSize(buffer.count)
        
        var newBuffer = UnsafeMutableBufferPointer<Element?>.allocate(capacity: nextSize)
        newBuffer.initialize(repeating: nil)
        for index in 0..<buffer.count {
            newBuffer[index] = buffer[index]
        }
        buffer.baseAddress?.deinitialize(count: buffer.count)
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

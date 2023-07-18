//
//  MPMCStack.swift
//  
//
//  Created by Sebastian Toivonen on 26.4.2022.
//

#if canImport(Atomics)
import Atomics

public final class MPMCStack<Element>: ConcurrentStack, @unchecked Sendable {
    @usableFromInline
    internal struct StackNode {
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal var next: UnsafeMutablePointer<StackNode>?
        
        @usableFromInline
        internal init(data: Element?) {
            self.data = data
            self.next = nil
        }
        
        @usableFromInline
        internal init(data: Element?, next: UnsafeMutablePointer<StackNode>?) {
            self.data = data
            self.next = next
        }
    }
    
    @usableFromInline
    internal let _top: UnsafeAtomic<UnsafeMutablePointer<StackNode>?> = .createCacheAligned(nil)
    
    @usableFromInline
    internal let _count: UnsafeAtomic<Int> = .createCacheAligned(0)
    
    public var top: Element? {
        guard let top = _top.load(ordering: .acquiring) else { return nil }
        return top.pointee.data
    }
    
    public var count: Int {
        _count.load(ordering: .relaxed)
    }
    
    public var wasFull: Bool { false }
    
    public var wasEmpty: Bool { _top.load(ordering: .relaxed) == nil }
    
    public init() {}
    
    deinit {
        while pop() != nil {}
        _top.destroy()
        _count.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func push(_ value: Element) -> Bool {
        //TODO: Use cache
        let newNode = UnsafeMutablePointer<StackNode>.allocate(capacity: 1)
        newNode.initialize(to: StackNode(data: value, next: _top.load(ordering: .relaxed)))
        
        while true {
            let (exchanged, original) = _top.weakCompareExchange(expected: newNode.pointee.next, desired: newNode, successOrdering: .relaxed, failureOrdering: .relaxed)
            if exchanged { break }
            newNode.pointee.next = original
        }
        _count.wrappingIncrement(ordering: .relaxed)
        return true
    }
    
    @inlinable
    public final func pop() -> Element? {
        var top = _top.load(ordering: .relaxed)
        if top == nil { return nil }
        var newFront = top?.pointee.next
        while true {
            let (exchanged, original) = _top.weakCompareExchange(expected: top, desired: newFront, successOrdering: .releasing, failureOrdering: .relaxed)
            if exchanged { break }
            top = original
            if top == nil { return nil }
            newFront = top?.pointee.next
        }
        _count.wrappingDecrement(ordering: .relaxed)
        let result = top?.pointee.data
        //TODO: Cache
        top?.deinitialize(count: 1)
        top?.deallocate()
        return result
    }
    
    @inline(__always)
    public final func popAll(_ closure: (Element) -> Void) {
        while let element = pop() {
            closure(element)
        }
    }
}

extension MPMCStack: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let stack: MPMCStack<Element>
        
        @inlinable
        internal init(stack: MPMCStack<Element>) {
            self.stack = stack
        }
        
        @inlinable
        public func next() -> Element? {
            stack.pop()
        }
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(stack: self)
    }
}
#endif

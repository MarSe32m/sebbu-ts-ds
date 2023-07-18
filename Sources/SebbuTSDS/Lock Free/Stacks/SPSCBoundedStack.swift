//
//  SPSCBoundedStack.swift
//  
//
//  Created by Sebastian Toivonen on 2.6.2023.
//

#if canImport(Atomics)
import Atomics

public final class SPSCBoundedStack<Element>: ConcurrentStack, @unchecked Sendable {
    @usableFromInline
    internal struct BufferNode {
        @usableFromInline
        internal var data: UnsafeMutablePointer<Element?>
        
        @usableFromInline
        internal let sequence: UnsafeAtomic<Int> = .create(0)
        
        init(data: Element?) {
            self.data = .allocate(capacity: 1)
            self.data.initialize(to: data)
        }
    }
    
    @usableFromInline
    internal let size: Int
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal let buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal var head = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal var tail = UnsafeAtomic<Int>.create(0)
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (size - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public var wasFull: Bool {
        size - count == 1
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.size = size
        self.mask = size - 1
        self.buffer = .allocate(capacity: size)
        for i in 0..<size {
            let node = BufferNode(data: nil)
            node.sequence.store(i, ordering: .relaxed)
            buffer.baseAddress?.advanced(by: i).initialize(to: node)
        }
    }
    
    deinit {
        while pop() != nil {}
        for item in buffer {
            item.data.deinitialize(count: 1)
            item.data.deallocate()
            item.sequence.destroy()
        }
        buffer.deallocate()
        head.destroy()
        tail.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func push(_ value: Element) -> Bool {
        fatalError("NOT IMPLEMENTED")
    }
    
    @inlinable
    public final func pop() -> Element? {
        fatalError("NOT IMPLEMENTED")
    }
    
    @inline(__always)
    public final func popAll(_ closure: (Element) -> Void) {
        while let element = pop() {
            closure(element)
        }
    }
}

extension SPSCBoundedStack: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let stack: SPSCBoundedStack<Element>
        
        @inlinable
        internal init(stack: SPSCBoundedStack<Element>) {
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

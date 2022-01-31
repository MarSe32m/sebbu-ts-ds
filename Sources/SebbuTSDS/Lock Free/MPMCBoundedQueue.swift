//
//  MPMCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Atomics)
import Atomics

public final class MPMCBoundedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
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
        while dequeue() != nil {}
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
    public final func enqueue(_ value: Element) -> Bool {
        var node: UnsafeMutablePointer<BufferNode>!
        var pos = tail.load(ordering: .relaxed)
        
        while true {
            node = buffer.baseAddress?.advanced(by: pos & mask)
            let seq = node.pointee.sequence.load(ordering: .acquiring)
            let difference = seq - pos
            
            if difference == 0 {
                if tail.weakCompareExchange(expected: pos,
                                            desired: pos + 1,
                                            successOrdering: .relaxed,
                                            failureOrdering: .relaxed).exchanged {
                    break
                }
            } else if difference < 0 {
                return false
            } else {
                pos = tail.load(ordering: .relaxed)
            }
        }
        
        node.pointee.data.pointee = value
        node.pointee.sequence.store(pos + 1, ordering: .releasing)
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        var node: UnsafeMutablePointer<BufferNode>!
        var pos = head.load(ordering: .relaxed)
        
        while true {
            node = buffer.baseAddress?.advanced(by: pos & mask)
            let seq = node.pointee.sequence.load(ordering: .acquiring)
            let difference = seq - (pos + 1)
            
            if difference == 0 {
                if head.weakCompareExchange(expected: pos, desired: pos + 1, successOrdering: .relaxed, failureOrdering: .relaxed).exchanged {
                    break
                }
            } else if difference < 0 {
                return nil
            } else {
                pos = head.load(ordering: .relaxed)
            }
        }
        defer {
            node.pointee.sequence.store(pos + mask + 1, ordering: .releasing)
        }
        return node.pointee.data.pointee
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension MPMCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: MPMCBoundedQueue
        
        @inlinable
        internal init(queue: MPMCBoundedQueue) {
            self.queue = queue
        }
        
        @inlinable
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}
#endif

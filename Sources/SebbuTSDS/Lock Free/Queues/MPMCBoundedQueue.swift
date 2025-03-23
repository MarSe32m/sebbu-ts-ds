//
//  MPMCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
import Synchronization

public final class MPMCBoundedQueue<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    internal struct BufferNode: ~Copyable {
        @usableFromInline
        internal var data: UnsafeMutablePointer<Element>
        
        @usableFromInline
        internal let sequence: Atomic<Int> = .init(0)
        
        @inlinable
        init(data: consuming Element) {
            self.data = .allocate(capacity: 1)
            self.data.initialize(to: data)
        }
        
        @inlinable
        init() {
            self.data = .allocate(capacity: 1)
        }
    }
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal let buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal let head: Atomic<Int> = .init(0)
    
    @usableFromInline
    internal let tail: Atomic<Int> = .init(0)
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public var wasFull: Bool {
        buffer.count - count == 1
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.mask = size - 1
        self.buffer = .allocate(capacity: size)
        for i in 0..<size {
            buffer.baseAddress?.advanced(by: i).initialize(to: BufferNode())
            buffer[i].sequence.store(i, ordering: .relaxed)
        }
    }
    
    deinit {
        while dequeue() != nil {}
        for i in 0..<buffer.count {
            let item = buffer.moveElement(from: i)
            item.data.deallocate()
        }
        buffer.deallocate()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: consuming Element) -> Element? {
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
                return value
            } else {
                pos = tail.load(ordering: .relaxed)
            }
        }
        node.pointee.data.initialize(to: value)
        node.pointee.sequence.store(pos + 1, ordering: .releasing)
        return nil
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
        let result = node.pointee.data.move()
        node.pointee.sequence.store(pos + mask + 1, ordering: .releasing)
        return result
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (consuming Element) -> Void) {
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

extension MPMCBoundedQueue: ConcurrentQueue {}

//
//  SPMCBoundedQueue.swift
//
//
//  Created by Sebastian Toivonen on 13.1.2022.
//

import Synchronization

public final class SPMCBoundedQueue<Element: ~Copyable>: @unchecked Sendable {
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
        
        init() {
            self.data = .allocate(capacity: 1)
        }
    }
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal var _buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal let head: Atomic<Int> = .init(0)
    
    @usableFromInline
    internal var tail = 0
    
    public var count: Int {
        let headIndex = head.load(ordering: .relaxed)
        let tailIndex = tail
        return tailIndex < headIndex ? (_buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    public var wasFull: Bool {
        _buffer.count - count == 1
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.mask = size - 1
        self._buffer = .allocate(capacity: size)
        for i in 0..<size {
            _buffer.baseAddress?.advanced(by: i).initialize(to: BufferNode())
            _buffer[i].sequence.store(i, ordering: .releasing)
        }
    }
    
    deinit {
        while dequeue() != nil {}
        for i in 0..<_buffer.count {
            let item = _buffer.moveElement(from: i)
            item.data.deallocate()
        }
        _buffer.deallocate()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: consuming Element) -> Element? {
        let pos = tail
        let node: UnsafeMutablePointer<BufferNode> = _buffer.baseAddress!.advanced(by: pos & mask)
        let seq = node.pointee.sequence.load(ordering: .acquiring)
        let difference = seq - pos
        
        if difference == 0 {
            tail += 1
        } else if difference < 0 {
            return value
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
            node = _buffer.baseAddress!.advanced(by: pos & mask)
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

extension SPMCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: SPMCBoundedQueue
        
        @inlinable
        internal init(queue: SPMCBoundedQueue) {
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

extension SPMCBoundedQueue: ConcurrentQueue {}

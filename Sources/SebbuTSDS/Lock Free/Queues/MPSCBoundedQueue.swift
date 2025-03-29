//
//  MPSCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 11.1.2022.
//
import Synchronization

public final class MPSCBoundedQueue<Element: ~Copyable>: @unchecked Sendable {
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
    internal let _buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal var head: Int = 0
    
    @usableFromInline
    internal let tail: Atomic<Int> = .init(0)
    
    @inlinable
    public var count: Int {
        let headIndex = head
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (_buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    @inlinable
    public var wasFull: Bool {
        _buffer.count - count == 1
    }
    
    @inline(__always)
    public func withFirst<T>(_ body: (borrowing Element?) throws -> T) rethrows -> T {
        let node: UnsafeMutablePointer<BufferNode> = _buffer.baseAddress!.advanced(by: head & mask)
        let seq = node.pointee.sequence.load(ordering: .acquiring)
        if seq - (head + 1) < 0 { return try body(nil) }
        var element = Optional(node.pointee.data.move())
        assert(element != nil)
        let result = try body(element)
        node.pointee.data.initialize(to: element.take()!)
        return result
    }

    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.mask = size - 1
        self._buffer = .allocate(capacity: size)
        for i in 0..<size {
            _buffer.baseAddress?.advanced(by: i).initialize(to: BufferNode())
            _buffer[i].sequence.store(i, ordering: .relaxed)
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
    public final func enqueue(_ value: consuming sending Element) -> Element? {
        var node: UnsafeMutablePointer<BufferNode>!
        var pos = tail.load(ordering: .relaxed)
        
        while true {
            node = _buffer.baseAddress?.advanced(by: pos & mask)
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
    public final func dequeue() -> sending Element? {
        let pos = head
        let node: UnsafeMutablePointer<BufferNode> = _buffer.baseAddress!.advanced(by: pos & mask)
        let seq = node.pointee.sequence.load(ordering: .acquiring)
        let difference = seq - (pos + 1)
        if difference == 0 {
            head += 1
        } else if difference < 0 {
            return nil
        }
        let result = node.pointee.data.move()
        node.pointee.sequence.store(pos + mask + 1, ordering: .releasing)
        return result
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (consuming sending Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension MPSCBoundedQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: MPSCBoundedQueue
        
        @inlinable
        internal init(queue: MPSCBoundedQueue) {
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

extension MPSCBoundedQueue: ConcurrentQueue {}

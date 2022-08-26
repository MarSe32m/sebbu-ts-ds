//
//  MPSCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 11.1.2022.
//

#if canImport(Atomics)
import Atomics

public final class MPSCBoundedQueue<Element>: ConcurrentQueue, @unchecked Sendable {
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
    internal let _buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal var head: Int = 0
    
    @usableFromInline
    internal let tail = UnsafeAtomic<Int>.create(0)
    
    @inlinable
    public var count: Int {
        let headIndex = head
        let tailIndex = tail.load(ordering: .relaxed)
        return tailIndex < headIndex ? (_buffer.count - headIndex + tailIndex) : (tailIndex - headIndex)
    }
    
    @inlinable
    public var wasFull: Bool {
        size - count == 1
    }
    
    @inlinable
    public var first: Element? {
        let node: UnsafeMutablePointer<BufferNode> = _buffer.baseAddress!.advanced(by: head & mask)
        let seq = node.pointee.sequence.load(ordering: .acquiring)
        if seq - (head + 1) < 0 { return nil }
        return node.pointee.data.pointee
    }
    
    public init(size: Int) {
        let size = size.nextPowerOf2()
        self.size = size
        self.mask = size - 1
        self._buffer = .allocate(capacity: size)
        for i in 0..<size {
            _buffer.baseAddress?.advanced(by: i).initialize(to: BufferNode(data: nil))
            _buffer[i].sequence.store(i, ordering: .relaxed)
        }
    }
    
    deinit {
        while dequeue() != nil {}
        for item in _buffer {
            item.sequence.destroy()
            item.data.deinitialize(count: 1)
            item.data.deallocate()
        }
        _buffer.deallocate()
        tail.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
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
        let pos = head
        let node: UnsafeMutablePointer<BufferNode> = _buffer.baseAddress!.advanced(by: pos & mask)
        let seq = node.pointee.sequence.load(ordering: .acquiring)
        let difference = seq - (pos + 1)
        if difference == 0 {
            head += 1
        } else if difference < 0 {
            return nil
        }
        
        defer {
            node.pointee.data.pointee = nil
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
#else
public typealias MPSCBoundedQueue<Element> = LockedBoundedQueue<Element>
#endif


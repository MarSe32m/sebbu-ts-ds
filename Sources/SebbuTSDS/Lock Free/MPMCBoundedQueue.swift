//
//  MPMCBoundedQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
import Atomics

public final class MPMCBoundedQueue<Element>: ConcurrentQueue {
    
    @usableFromInline
    internal class BufferNode {
        
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal let sequence: ManagedAtomic<Int> = ManagedAtomic<Int>(0)
    }
    
    @usableFromInline
    internal let size: Int
    
    @usableFromInline
    internal let mask: Int
    
    @usableFromInline
    internal var buffer: UnsafeMutableBufferPointer<BufferNode>
    
    @usableFromInline
    internal var head = ManagedAtomic<Int>(0)
    
    @usableFromInline
    internal var tail = ManagedAtomic<Int>(0)
    
    public init(size _size: Int) {
        self.size = _size.nextPowerOf2()
        self.mask = _size.nextPowerOf2() - 1
        self.buffer = UnsafeMutableBufferPointer.allocate(capacity: _size.nextPowerOf2())
        self.buffer.initialize(repeating: BufferNode())
        for i in 0..<_size.nextPowerOf2() {
            let node = BufferNode()
            node.sequence.store(i, ordering: .relaxed)
            buffer[i] = node
        }
    }
    
    deinit {
        buffer.deallocate()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        var node: BufferNode!
        var pos = tail.load(ordering: .relaxed)
        
        while true {
            node = buffer[pos & mask]
            let seq = node.sequence.load(ordering: .acquiring)
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
        
        node.data = value
        node.sequence.store(pos + 1, ordering: .releasing)
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        var node: BufferNode!
        var pos = head.load(ordering: .relaxed)
        
        while true {
            node = buffer[pos & mask]
            let seq = node.sequence.load(ordering: .acquiring)
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
            node.sequence.store(pos + mask + 1, ordering: .releasing)
        }
        return node.data
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

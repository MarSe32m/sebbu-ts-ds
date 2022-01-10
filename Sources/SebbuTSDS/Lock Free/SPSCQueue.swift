//
//  SPSCQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Atomics)
import Atomics

public final class SPSCQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal struct Node {
        
        @usableFromInline
        internal var next: UnsafeMutablePointer<Node>?
        
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        init(data: Element?) {
            self.data = data
        }
    }
    
    @usableFromInline
    internal var head: UnsafeMutablePointer<Node>
    
    @usableFromInline
    internal var tail: UnsafeMutablePointer<Node>
    
    public init() {
        head = UnsafeMutablePointer<Node>.allocate(capacity: 1)
        head.initialize(to: Node(data: nil))
        tail = head
    }
 
    deinit {
        while let _ = dequeue() {}
        tail.deallocate()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        let node = UnsafeMutablePointer<Node>.allocate(capacity: 1)
        node.initialize(to: Node(data: value))
        
        atomicMemoryFence(ordering: .acquiringAndReleasing)
        tail.pointee.next = node
        tail = node
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        atomicMemoryFence(ordering: .acquiring)
        if head.pointee.next == nil {
            return nil
        }
        let result = head.pointee.next?.pointee.data
        atomicMemoryFence(ordering: .acquiringAndReleasing)
        let front = head
        head = front.pointee.next!
        front.deallocate()
        return result
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}

extension SPSCQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        internal let queue: SPSCQueue
        
        public func next() -> Element? {
            queue.dequeue()
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(queue: self)
    }
}
#endif

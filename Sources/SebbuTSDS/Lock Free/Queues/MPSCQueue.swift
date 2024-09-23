//
//  MPSCQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//
#if canImport(Synchronization)
import Synchronization

public final class MPSCQueue<Element: ~Copyable>: @unchecked Sendable {
    @usableFromInline
    internal struct BufferNode: ~Copyable {
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal let next: Atomic<UnsafeMutablePointer<BufferNode>?> = .init(nil)
        
        @usableFromInline
        internal init(data: consuming Element?) {
            self.data = data
        }
    }
    
    @usableFromInline
    internal let head: Atomic<UnsafeMutablePointer<BufferNode>>
    
    @usableFromInline
    internal let tail: Atomic<UnsafeMutablePointer<BufferNode>>
    
    @usableFromInline
    internal let cache: SPMCBoundedQueue<UnsafeMutablePointer<BufferNode>>
    
    @inlinable
    public var wasFull: Bool { false }

    @inlinable
    public init(cacheSize: Int = 1024) {
        let node = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
        node.initialize(to: BufferNode(data: nil))
        self.head = .init(node)
        self.tail = .init(node)
        self.cache = SPMCBoundedQueue(size: cacheSize)
    }
    
    deinit {
        while let _ = dequeue() {}
        while let node = cache.dequeue() {
            node.deinitialize(count: 1)
            node.deallocate()
        }
        tail.load(ordering: .relaxed).deinitialize(count: 1)
        tail.load(ordering: .relaxed).deallocate()
    }
    
    @inlinable
    public final func enqueue(_ value: consuming Element) -> Element? {
        let bufferNode = allocateNode()
        bufferNode.pointee.data = consume value
        let previous = tail.exchange(bufferNode, ordering: .acquiringAndReleasing)
        previous.pointee.next.store(bufferNode, ordering: .releasing)
        return nil
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        let currentHead = head.load(ordering: .relaxed)
        guard let next = currentHead.pointee.next.load(ordering: .acquiring) else {
            return nil
        }
        let result = next.pointee.data.take()
        head.store(next, ordering: .releasing)
        if !cache.enqueue(currentHead) {
            currentHead.deinitialize(count: 1)
            currentHead.deallocate()
        }
        return result
    }
    
    @inline(__always)
    public func withFirst<T>(_ body: (borrowing Element?) throws -> T) rethrows -> T {
        let currentHead = head.load(ordering: .relaxed)
        guard let next = currentHead.pointee.next.load(ordering: .acquiring) else { 
            return try body(nil)
        }
        let first = next.pointee.data.take()
        let result = try body(first)
        next.pointee.data = first
        return result
    }

    @inline(__always)
    public final func dequeueAll(_ closure: (consuming Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
    
    @inlinable
    internal final func allocateNode() -> UnsafeMutablePointer<BufferNode> {
        if let node = cache.dequeue() {
            node.pointee.next.store(nil, ordering: .relaxed)
            return node
        }
        let node: UnsafeMutablePointer<BufferNode> = .allocate(capacity: 1)
        node.initialize(to: BufferNode(data: nil))
        return node
    }
}

#elseif canImport(Atomics)
import Atomics

public final class MPSCQueue<Element>: ConcurrentQueue, @unchecked Sendable {
    @usableFromInline
    internal struct BufferNode {
        @usableFromInline
        internal var data: Element?
        
        @usableFromInline
        internal let next: UnsafeAtomic<UnsafeMutablePointer<BufferNode>?> = .create(nil)
        
        @usableFromInline
        internal init(data: Element?) {
            self.data = data
        }
    }
    
    @usableFromInline
    internal let head: UnsafeAtomic<UnsafeMutablePointer<BufferNode>>
    
    @usableFromInline
    internal let tail: UnsafeAtomic<UnsafeMutablePointer<BufferNode>>
    
    @usableFromInline
    internal let cache: SPMCBoundedQueue<UnsafeMutablePointer<BufferNode>>
    
    @inlinable
    public var wasFull: Bool { false }
    
    @inlinable
    public var first: Element? {
        let currentHead = head.load(ordering: .relaxed)
        guard let next = currentHead.pointee.next.load(ordering: .acquiring) else {
            return nil
        }
        return next.pointee.data
    }
    
    @inlinable
    public init(cacheSize: Int = 1024) {
        let node = UnsafeMutablePointer<BufferNode>.allocate(capacity: 1)
        node.initialize(to: BufferNode(data: nil))
        self.head = .createCacheAligned(node)
        self.tail = .createCacheAligned(node)
        self.cache = SPMCBoundedQueue(size: cacheSize)
    }
    
    deinit {
        while let _ = dequeue() {}
        while let node = cache.dequeue() {
            node.pointee.next.destroy()
            node.deinitialize(count: 1)
            node.deallocate()
        }
        tail.load(ordering: .relaxed).pointee.next.destroy()
        tail.load(ordering: .relaxed).deinitialize(count: 1)
        tail.load(ordering: .relaxed).deallocate()
        head.destroy()
        tail.destroy()
    }
    
    @discardableResult
    @inlinable
    public final func enqueue(_ value: Element) -> Bool {
        let bufferNode = allocateNode()
        bufferNode.pointee.data = value
        let previous = tail.exchange(bufferNode, ordering: .acquiringAndReleasing)
        previous.pointee.next.store(bufferNode, ordering: .releasing)
        return true
    }
    
    @inlinable
    public final func dequeue() -> Element? {
        let currentHead = head.load(ordering: .relaxed)
        guard let next = currentHead.pointee.next.load(ordering: .acquiring) else {
            return nil
        }
        let result = next.pointee.data
        next.pointee.data = nil
        head.store(next, ordering: .releasing)
        if !cache.enqueue(currentHead) {
            currentHead.pointee.next.destroy()
            currentHead.deinitialize(count: 1)
            currentHead.deallocate()
        }
        return result
    }
    
    @inline(__always)
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
    
    @inlinable
    internal final func allocateNode() -> UnsafeMutablePointer<BufferNode> {
        if let node = cache.dequeue() {
            node.pointee.next.store(nil, ordering: .relaxed)
            return node
        }
        let node: UnsafeMutablePointer<BufferNode> = .allocate(capacity: 1)
        node.initialize(to: BufferNode(data: nil))
        return node
    }
}
#else
public typealias MPSCQueue<Element> = LockedQueue<Element>
#endif

extension MPSCQueue: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        internal let queue: MPSCQueue
        
        @inlinable
        internal init(queue: MPSCQueue) {
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

extension MPSCQueue: ConcurrentQueue {}
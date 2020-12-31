//
//  SPSCQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

import Atomics

public final class SPSCQueue<Element>: ConcurrentQueue {
    struct Node {
        var next: UnsafeMutablePointer<Node>?
        var data: Element?
        
        init(data: Element?) {
            self.data = data
        }
    }
    
    private var head: UnsafeMutablePointer<Node>
    private var tail: UnsafeMutablePointer<Node>
    
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
    public final func enqueue(_ value: Element) -> Bool {
        let node = UnsafeMutablePointer<Node>.allocate(capacity: 1)
        node.initialize(to: Node(data: value))
        
        atomicMemoryFence(ordering: .acquiringAndReleasing)
        tail.pointee.next = node
        tail = node
        return true
    }
    
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
    
    public final func dequeueAll(_ closure: (Element) -> Void) {
        while let element = dequeue() {
            closure(element)
        }
    }
}


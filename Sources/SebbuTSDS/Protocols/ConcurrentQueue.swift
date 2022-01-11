//
//  ConcurrentQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

/// FIFO queue
public protocol ConcurrentQueue {
    associatedtype Element
    
    /// Enqueues an item to the queue
    /// - returns Boolean value based on if the item was enqueued successfully
    @inlinable
    func enqueue(_ value: Element) -> Bool
    
    /// Dequeues the next element in the queue if there are any
    @inlinable
    func dequeue() -> Element?
    
    /// Dequeues all of the items from the queue
    @inline(__always)
    func dequeueAll(_ closure: (Element) -> Void)
}

public extension ConcurrentQueue {
    @inlinable
    func blockingEnqueue(_ value: Element) {
        while !enqueue(value) {}
    }
    
    @inlinable
    func blockingDequeue() -> Element {
        while true {
            if let value = dequeue() {
                return value
            }
        }
    }
}

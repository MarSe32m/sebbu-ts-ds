//
//  ConcurrentQueue.swift
//  
//
//  Created by Sebastian Toivonen on 6.12.2020.
//

/// FIFO queue
public protocol ConcurrentQueue {
    associatedtype Element
    
    @inlinable
    var wasFull: Bool { get }
    
    /// Enqueues an item to the queue
    /// - returns The value back if it wasn't possible to be enqueued
    @inlinable
    func enqueue(_ value: consuming sending Element) -> Element?
    
    /// Dequeues the next element in the queue if there are any
    @inlinable
    func dequeue() -> sending Element?
    
    /// Dequeues all of the items from the queue
    @inline(__always)
    func dequeueAll(_ closure: (consuming sending Element) -> Void)
}

// Extensions for Copyable elements
public extension ConcurrentQueue {
    @inlinable
    func enqueue(_ value: Element) -> Bool { enqueue(value) == nil }

    @inlinable
    func blockingEnqueue(_ value: consuming sending Element) {
        while !enqueue(value) {}
    }
    
    @inlinable
    func blockingDequeue() -> sending Element {
        while true {
            if let value = dequeue() {
                return value
            }
        }
    }
}

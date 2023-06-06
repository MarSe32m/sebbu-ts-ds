//
//  LockedPriorityQueue.swift
//  
//
//  Created by Sebastian Toivonen on 13.4.2023.
//

import HeapModule

public final class LockedPriorityQueue<Element>: @unchecked Sendable where Element: Comparable {
    @usableFromInline
    internal var _heap: Heap<Element>
    
    @usableFromInline
    internal let lock = Lock()
    
    /// A Boolean value indicating whether or not the priority queue is empty.
    ///
    /// - Complexity: O(1)
    @inlinable @inline(__always)
    public var isEmpty: Bool {
        lock.withLock {
            _heap.isEmpty
        }
    }

    /// The number of elements in the priority queue.
    ///
    /// - Complexity: O(1)
    @inlinable @inline(__always)
    public var count: Int {
        lock.withLock {
            _heap.count
        }
    }

    /// A read-only view into the underlying array.
    ///
    /// Note: The elements aren't _arbitrarily_ ordered (it is, after all, a
    /// heap). However, no guarantees are given as to the ordering of the elements
    /// or that this won't change in future versions of the library.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var unordered: [Element] {
        lock.withLock {
            _heap.unordered
        }
    }
    
    /// Creates an empty heap.
    public init() {
        _heap = Heap()
    }
    
    public init(_ elements: some Sequence<Element>) {
        _heap = Heap(elements)
    }
    
    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    /// Inserts the given element into the priority queue.
    ///
    /// - Complexity: O(log(`count`)) element comparisons
    @inlinable
    public func insert(_ element: Element) {
        lock.withLock {
            _heap.insert(element)
        }
    }

    /// Returns the element with the lowest priority, if available.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func min() -> Element? {
        lock.withLock {
            _heap.min()
        }
    }

    /// Returns the element with the highest priority, if available.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func max() -> Element? {
        lock.withLock {
            _heap.max()
        }
    }

    /// Removes and returns the element with the lowest priority, if available.
    ///
    /// - Complexity: O(log(`count`)) element comparisons
    @inlinable
    public func popMin() -> Element? {
        lock.withLock {
            _heap.popMin()
        }
    }

    /// Removes and returns the element with the highest priority, if available.
    ///
    /// - Complexity: O(log(`count`)) element comparisons
    @inlinable
    public func popMax() -> Element? {
        lock.withLock {
            _heap.popMax()
        }
    }

    /// Removes and returns the element with the lowest priority.
    ///
    /// The priority queue *must not* be empty.
    ///
    /// - Complexity: O(log(`count`)) element comparisons
    @inlinable
    public func removeMin() -> Element {
      return popMin()!
    }

    /// Removes and returns the element with the highest priority.
    ///
    /// The priority queue *must not* be empty.
    ///
    /// - Complexity: O(log(`count`)) element comparisons
    @inlinable
    public func removeMax() -> Element {
      return popMax()!
    }

    /// Replaces the minimum value in the priority queue with the given replacement,
    /// then updates priority queue contents to reflect the change.
    ///
    /// The priority queue must not be empty.
    ///
    /// - Parameter replacement: The value that is to replace the current
    ///   minimum value.
    /// - Returns: The original minimum value before the replacement.
    ///
    /// - Complexity: O(log(`count`)) element comparisons
    @inlinable
    @discardableResult
    public func replaceMin(with replacement: Element) -> Element {
        lock.withLock {
            _heap.replaceMin(with: replacement)
        }
    }

    /// Replaces the maximum value in the priority queue with the given replacement,
    /// then updates priority queue contents to reflect the change.
    ///
    /// The priority must not be empty.
    ///
    /// - Parameter replacement: The value that is to replace the current maximum
    ///   value.
    /// - Returns: The original maximum value before the replacement.
    ///
    /// - Complexity: O(log(`count`)) element comparisons
    @inlinable
    @discardableResult
    public func replaceMax(with replacement: Element) -> Element {
        lock.withLock {
            _heap.replaceMax(with: replacement)
        }
    }
    
}

extension LockedPriorityQueue: CustomStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
      "LockedPriorityQueue<\(Element.self)>(count: \(count))"
  }
}

extension LockedPriorityQueue: CustomDebugStringConvertible {
  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    description
  }
}


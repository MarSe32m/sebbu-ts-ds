//
//  ThreadPool.swift
//  
//
//  Created by Sebastian Toivonen on 15.1.2022.
//

//TODO: Create your own threads etc.
import Foundation
import Dispatch
import PriorityQueueModule

#if canImport(Atomics)
import Atomics

public final class ThreadPool: @unchecked Sendable {
    // There is a big problem in using this setup.
    // There is a possibility that the heaviest computations are
    // enqueued to a specific thread, while the other threads
    // run short computations and when done, have to wait for
    // more work... This is worked around by having the workers
    // have two queues, a bounded stealable MPMC queue and an
    // unbounded MPSC queue. The stealable queue is always filled first
    // and when a worker runs out of work, they will drain the other workers
    // stealable work queues. This way the probability of a worker being idle
    // while having potential work is decreased but not totally removed.
    @usableFromInline
    internal let workerIndex = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal var workers: [Worker] = []
    
    @usableFromInline
    internal let timedWorkQueue: MPSCQueue<TimedWork>
    
    @usableFromInline
    internal var timedWork: Heap<TimedWork> = Heap()
    
    @usableFromInline
    internal let isTimedWorkHandled: UnsafeAtomic<Bool> = .create(false)
    
    public let numberOfThreads: Int
    
    public init(numberOfThreads: Int, workerThreadCacheSize: Int = 4096) {
        self.numberOfThreads = numberOfThreads
        self.timedWorkQueue = MPSCQueue(cacheSize: workerThreadCacheSize)
        for _ in 0..<numberOfThreads {
            workers.append(Worker(queueCacheSize: workerThreadCacheSize))
        }
    }
    
    @inlinable
    public final func start() {
        for worker in workers {
            Thread.detachNewThread {
                worker.start(threadPool: self)
            }
        }
    }
    
    @inlinable
    public final func run(_ block: @escaping () -> ()) {
        let index = getNextIndex()
        workers[index % numberOfThreads].submit(block)
    }
    
    @inlinable
    public final func run(after nanoseconds: UInt64, _ block: @escaping () -> ()) {
        let deadline = DispatchTime.now().uptimeNanoseconds + nanoseconds
        timedWorkQueue.enqueue(TimedWork(block, deadline))
        let index = getNextIndex()
        workers[index % numberOfThreads].semaphore.signal()
    }
    
    @inlinable
    @discardableResult
    internal final func handleTimedWork() -> Int {
        // Is someone else handling timed out work?
        if isTimedWorkHandled.exchange(true, ordering: .acquiring) { return 0 }
        defer { isTimedWorkHandled.store(false, ordering: .releasing) }
        
        // Move the enqueued work into the priority queue
        for work in timedWorkQueue {
            timedWork.insert(TimedWork(work.work, work.deadline))
        }
        
        // Process the priority queue
        while let workItem = timedWork.max() {
            //TODO: Hoist this outside the loop?
            let currentTime = DispatchTime.now().uptimeNanoseconds
            if workItem.deadline > currentTime {
                return currentTime.distance(to: workItem.deadline)
            }
            let workItem = timedWork.removeMax()
            // Enqueue the work to a worker thread
            run(workItem.work)
        }
        return 0
    }
    
    @inlinable
    public final func stop() {
        workers.forEach { $0.stop() }
    }
    
    @inlinable
    internal final func getNextIndex() -> Int {
        var index = workerIndex.loadThenWrappingIncrement(ordering: .relaxed)
        if _slowPath(index < 0) {
            workerIndex.store(0, ordering: .relaxed)
            index = workerIndex.wrappingIncrementThenLoad(ordering: .relaxed)
        }
        return index
    }
    
    deinit {
        stop()
        workerIndex.destroy()
        isTimedWorkHandled.destroy()
    }
}

@usableFromInline
internal struct Work {
    @usableFromInline
    let work: () -> ()
    
    @inlinable
    init(_ work: @escaping () -> ()) {
        self.work = work
    }
}

@usableFromInline
internal struct TimedWork: Comparable {
    @usableFromInline
    let work: () -> ()
    
    @usableFromInline
    let deadline: UInt64
    
    @inlinable
    init(_ work: @escaping () -> (), _ deadline: UInt64) {
        self.work = work
        self.deadline = deadline
    }
    
    @usableFromInline
    static func < (lhs: TimedWork, rhs: TimedWork) -> Bool {
        lhs.deadline > rhs.deadline
    }

    @usableFromInline
    static func == (lhs: TimedWork, rhs: TimedWork) -> Bool {
        lhs.deadline == rhs.deadline
    }
}

@usableFromInline
internal final class Worker {
    // We wrap the work in a struct to avoid allocations on every enqueue.
    // Workaround for: https://bugs.swift.org/browse/SR-15872
    // The ThreadPool tests run much faster (~25 seconds -> ~15.4 seconds)
    //@usableFromInline
    //typealias Work = () -> ()
    
    public let workQueue: MPSCQueue<Work>
    public let stealableWorkQueue: MPMCBoundedQueue<Work>
    
    public let semaphore: DispatchSemaphore = .init(value: 0)
    public let running: UnsafeAtomic<Bool> = .create(false)
    
    init(queueCacheSize: Int) {
        workQueue = MPSCQueue(cacheSize: queueCacheSize)
        stealableWorkQueue = MPMCBoundedQueue(size: queueCacheSize)
    }
    
    @inline(__always)
    public final func submit(_ work: @escaping () -> ()) {
        let work = Work(work)
        if stealableWorkQueue.wasFull || !stealableWorkQueue.enqueue(work) {
            workQueue.enqueue(work)
        }
        semaphore.signal()
    }
    
    @inline(__always)
    public final func start(threadPool: ThreadPool) {
        self.run(threadPool: threadPool)
    }
    
    @inlinable
    public final func run(threadPool: ThreadPool) {
        // If the value was already true, then don't run again...
        if running.exchange(true, ordering: .relaxed) { return }
        let maxIterations = 32 // Maybe this should be configurable?
        let stealableWork = WorkIterator(threadPool.workers)
        while running.load(ordering: .relaxed) {
            for _ in 0..<maxIterations {
                threadPool.handleTimedWork()
                if let work = stealableWorkQueue.dequeue() {
                    work.work()
                }
                if let work = workQueue.dequeue() {
                    work.work()
                }
                while let work = workQueue.dequeue() {
                    if !stealableWorkQueue.enqueue(work) {
                        work.work()
                        break
                    }
                }
            }
            
            // Steal other workers work
            for work in stealableWork {
                work.work()
            }
            
            let waitTime = threadPool.handleTimedWork()
            if waitTime > 0 {
                _ = semaphore.wait(timeout: .now() + .nanoseconds(waitTime))
            } else {
                semaphore.wait()
            }
        }
    }
    
    @inlinable
    public final func steal() -> Work? {
        stealableWorkQueue.dequeue()
    }
    
    @inlinable
    public final func stop() {
        running.store(false, ordering: .relaxed)
        semaphore.signal()
    }
    
    deinit {
        stealableWorkQueue.dequeueAll { work in
            work.work()
        }
        workQueue.dequeueAll { work in
            work.work()
        }
        running.destroy()
    }

    @usableFromInline
    internal struct WorkIterator: Sequence, IteratorProtocol {
        @usableFromInline
        internal let workers: [Worker]
        @usableFromInline
        internal var index = 0
        
        @inlinable
        public init(_ workers: [Worker]) {
            self.workers = workers
        }
        
        @inlinable
        public mutating func next() -> Work? {
            let startIndex = index
            repeat {
                if let work = workers[index].steal() {
                    return work
                }
                index = (index + 1) % workers.count
            } while index != startIndex
            return nil
        }
        
        @inlinable
        public func makeIterator() -> WorkIterator {
            self
        }
    }
}
#endif

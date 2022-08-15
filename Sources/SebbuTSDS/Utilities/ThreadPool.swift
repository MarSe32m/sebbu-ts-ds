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
import CSebbuTSDS

#if true
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
#else
import Atomics
@usableFromInline
final class Queue {
    @usableFromInline
    let workQueue: MPSCQueue<Work>
    
    @usableFromInline
    let processing: ManagedAtomic<Bool>
    
    init(cacheSize: Int = 4096) {
        self.workQueue = MPSCQueue(cacheSize: 4096)
        self.processing = ManagedAtomic(false)
    }
    
    @inlinable
    @inline(__always)
    func dequeue() -> Work? {
        for _ in 0..<32 {
            if !processing.exchange(true, ordering: .acquiring) {
                defer { processing.store(false, ordering: .releasing) }
                return workQueue.dequeue()
            }
            _pause()
        }
        return nil
    }
    
    @inlinable
    @inline(__always)
    func enqueue(_ work: Work) {
        workQueue.enqueue(work)
    }
}

public final class ThreadPool {
    
    @usableFromInline
    internal let queues: [Queue]
    
    @usableFromInline
    internal let timedWorkQueue: MPSCQueue<TimedWork>
    
    public let numberOfThreads: Int
    
    @usableFromInline
    internal var workers: [Worker] = []
    
    @usableFromInline
    internal var timedWork: Heap<TimedWork> = Heap()
    
    @usableFromInline
    internal let workerIndex: ManagedAtomic<Int> = ManagedAtomic(0)
    
    @usableFromInline
    internal let handlingTimedWork: ManagedAtomic<Bool> = ManagedAtomic(false)
    
    private let started: ManagedAtomic<Bool> = ManagedAtomic(false)
    
    public init(cacheSize: Int = 1024, numberOfThreads: Int) {
        assert(numberOfThreads > 0)
        self.timedWorkQueue = MPSCQueue(cacheSize: cacheSize)
        self.queues = (0..<numberOfThreads).map { _ in Queue(cacheSize: cacheSize) }
        self.numberOfThreads = numberOfThreads
    }
    
    public func start() {
        if started.exchange(true, ordering: .relaxed) { return }
        for index in 0..<numberOfThreads {
            let worker = Worker(threadPool: self, index: index)
            Thread.detachNewThread {
                worker.run()
            }
            workers.append(worker)
        }
    }
    
    @inlinable
    public func run(operation: @escaping () -> ()) {
        assert(!workers.isEmpty)
        let work = Work(operation)
        let index = getNextIndex()
        queues[index % numberOfThreads].enqueue(work)
        workCount.wrappingIncrement(ordering: .acquiringAndReleasing)
        semaphore.signal()
    }
    
    @inlinable
    public final func run(after nanoseconds: UInt64, _ block: @escaping () -> ()) {
        let deadline = DispatchTime.now().uptimeNanoseconds + nanoseconds
        timedWorkQueue.enqueue(TimedWork(block, deadline))
        semaphore.signal()
    }

    @inlinable
    @discardableResult
    internal func handleTimedWork() -> Int {
        if handlingTimedWork.exchange(true, ordering: .acquiring) { return 0 }
        defer { handlingTimedWork.store(false, ordering: .releasing) }
        
        // Move the enqueued work into the priority queue
        for work in timedWorkQueue {
            timedWork.insert(TimedWork(work.work, work.deadline))
        }
        
        // Process the priority queue
        let currentTime = DispatchTime.now().uptimeNanoseconds
        while let workItem = timedWork.max() {
            if workItem.deadline > currentTime {
                return currentTime.distance(to: workItem.deadline)
            }
            let workItem = timedWork.removeMax()
            // Enqueue the work to a worker thread
            run(operation: workItem.work)
        }
        return 0
    }
    
    public func stop() {
        workers.forEach { $0.stop() }
        workers.removeAll()
        started.store(false, ordering: .releasing)
    }
    
    @inlinable
    internal final func getNextIndex() -> Int {
        let index = workerIndex.loadThenWrappingIncrement(ordering: .relaxed)
        if _slowPath(index < 0) {
            workerIndex.store(0, ordering: .relaxed)
            return 0
        }
        return index
    }
    
    @usableFromInline
    internal let queueIndex: ManagedAtomic<Int> = ManagedAtomic(0)
    
    @usableFromInline
    internal let workCount: ManagedAtomic<Int> = ManagedAtomic(0)
    
    @usableFromInline
    let semaphore = DispatchSemaphore(value: 0)
    
    @inlinable
    internal final func getQueueIndex() -> Int {
        let index = queueIndex.loadThenWrappingIncrement(ordering: .relaxed)
        if _slowPath(index < 0) {
            queueIndex.store(0, ordering: .relaxed)
            return 0
        }
        return index
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
final class Worker {
    
    @usableFromInline
    let running: ManagedAtomic<Bool> = ManagedAtomic(false)
    
    let threadPool: ThreadPool
    
    private let index: Int
    private let numberOfQueues: Int
    
    init(threadPool: ThreadPool, index: Int) {
        self.threadPool = threadPool
        self.numberOfQueues = threadPool.queues.count
        self.index = index
    }
    
    public func run() {
        running.store(true, ordering: .relaxed)
        while running.load(ordering: .relaxed) {
            // Algo 1
//            for _ in 0..<1_048_576 {
//                var didWork = false
//                for index in 0..<numberOfQueues {
//                    threadPool.handleTimedWork()
//                    while let work = threadPool.queues[index].dequeue() {
//                        work.work()
//                        didWork = true
//                    }
//                }
//                if !didWork { break }
//            }
            
            // Algo 2
            repeat {
                let queueIndex = threadPool.getQueueIndex()
                for i in 0..<numberOfQueues {
                    threadPool.handleTimedWork()
                    while let work = threadPool.queues[(queueIndex + i) % numberOfQueues].dequeue() {
                        threadPool.workCount.wrappingDecrement(ordering: .relaxed)
                        work.work()
                    }
                }
            } while threadPool.workCount.load(ordering: .relaxed) > 0
            
            // Algo 3
//            threadPool.handleTimedWork()
//            let queueIndex = threadPool.getQueueIndex()
//            while let work = threadPool.queues[queueIndex % numberOfQueues].dequeue() {
//                work.work()
//            }
            
            let sleepTime = threadPool.handleTimedWork()
            if _slowPath(sleepTime > 0) {
                _ = threadPool.semaphore.wait(timeout: .now() + .nanoseconds(sleepTime))
            } else {
                threadPool.semaphore.wait()
            }
        }
    }
    
    public func stop() {
        running.store(false, ordering: .relaxed)
        threadPool.semaphore.signal()
    }
    
    deinit {
        stop()
    }
}

#endif

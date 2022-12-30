//
//  ThreadPool.swift
//  
//
//  Created by Sebastian Toivonen on 15.1.2022.
//

//TODO: Create your own threads etc.
import Foundation
import Dispatch
import HeapModule
import CSebbuTSDS

#if canImport(Atomics)
import Atomics

@usableFromInline
final class Queue {
    // We wrap the work in a struct to avoid allocations on every enqueue.
    // Workaround for: https://bugs.swift.org/browse/SR-15872
    // The ThreadPool tests run much faster (~25 seconds -> ~15.4 seconds)
    //@usableFromInline
    //typealias Work = () -> ()
    @usableFromInline
    let workQueue: MPSCQueue<Work>
    
    @usableFromInline
    let processing: ManagedAtomic<Bool>
    
    init(cacheSize: Int = 4096) {
        self.workQueue = MPSCQueue(cacheSize: cacheSize)
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
    //@inline(__always)
    func enqueue(_ work: Work) {
        workQueue.enqueue(work)
    }
}

public final class ThreadPool {
    public static let shared: ThreadPool = ThreadPool._createShared()
    
    @usableFromInline
    internal var isShared: Bool = false
    
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
    
    @usableFromInline
    internal let queueIndex: ManagedAtomic<Int> = ManagedAtomic(0)
    
    @usableFromInline
    internal let workCount: ManagedAtomic<Int> = ManagedAtomic(0)
    
    @usableFromInline
    internal let semaphore = DispatchSemaphore(value: 0)
    
    @usableFromInline
    internal let started: ManagedAtomic<Bool> = ManagedAtomic(false)
    
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
            let thread = Thread {
                worker.run()
            }
            thread.name = "SebbuTSDS-Worker-Thread-\(index)"
            thread.start()
            workers.append(worker)
        }
    }
    
    @inlinable
    public func run(operation: @escaping () -> ()) {
        precondition(started.load(ordering: .relaxed), "The ThreadPool wasn't started before blocks were submitted")
        assert(!workers.isEmpty)
        let index = getNextIndex()
        let queue = queues[index % numberOfThreads]
        let work = Work(operation)
        queue.enqueue(work)
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
        // End users cannot manually stop the shared ThreadPool
        if isShared { return }
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
internal final class Work {
    @usableFromInline
    var work: () -> ()
    
    @inlinable
    init(_ work: @escaping () -> ()) {
        self.work = work
    }
}

@usableFromInline
internal final class TimedWork: Comparable {
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
            repeat {
                let queueIndex = threadPool.getQueueIndex()
                for i in 0..<numberOfQueues {
                    let queue = threadPool.queues[(queueIndex + i) % numberOfQueues]
                    while let work = queue.dequeue() {
                        threadPool.workCount.wrappingDecrement(ordering: .relaxed)
                        work.work()
                        threadPool.handleTimedWork()
                    }
                }
            } while threadPool.workCount.load(ordering: .relaxed) > 0
            
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

internal extension ThreadPool {
    static func _createShared() -> ThreadPool {
        //TODO: Get the number of cores somehow. Copy NIOs implementation?
        return ThreadPool(cacheSize: 1024, numberOfThreads: 1)
    }
    
    func _startShared() {
        if started.exchange(true, ordering: .relaxed) { return }
        for index in 0..<numberOfThreads {
            let worker = Worker(threadPool: self, index: index)
            let thread = Thread {
                worker.run()
            }
            thread.name = "SebbuTSDS-Shared-Worker-Thread-\(index)"
            thread.start()
            workers.append(worker)
        }
    }
}

private let isSharedThreadPoolSetup: ManagedAtomic<Bool> = ManagedAtomic(false)

@_cdecl("setup_shared_threadpool")
public func __setup_shared_threadpool() {
    if isSharedThreadPoolSetup.exchange(true, ordering: .sequentiallyConsistent) { return }
    ThreadPool.shared._startShared()
}
#else
@_cdecl("setup_shared_threadpool")
public func __setup_shared_threadpool() {
    //If we have no thread pool implementation then we shouldn't set up anything :)
}
#endif



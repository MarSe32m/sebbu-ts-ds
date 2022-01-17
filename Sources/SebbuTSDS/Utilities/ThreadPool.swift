//
//  ThreadPool.swift
//  
//
//  Created by Sebastian Toivonen on 15.1.2022.
//

//TODO: Create your own threads etc.
import Foundation
import Dispatch

#if canImport(Atomics)
import Atomics

public final class ThreadPool {
    // There is a big problem in using this setup.
    // There is a possibility that the heaviest computations are
    // enqueued to a specific thread, while the other threads
    // run short computations and when done, have to wait for
    // more work...
    @usableFromInline
    internal let workerIndex = UnsafeAtomic<Int>.create(0)
    
    @usableFromInline
    internal var workers: [Worker] = []
    
    public let numberOfThreads: Int
    
    public init(numberOfThreads: Int, workerThreadCacheSize: Int = 4096) {
        self.numberOfThreads = numberOfThreads
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
        var index = workerIndex.loadThenWrappingIncrement(ordering: .relaxed)
        if _slowPath(index < 0) {
            workerIndex.store(0, ordering: .relaxed)
            index = workerIndex.wrappingIncrementThenLoad(ordering: .relaxed)
        }
        workers[index % numberOfThreads].submit(block)
    }
    
    @inlinable
    public final func stop() {
        workers.forEach { $0.stop() }
    }
    
    deinit {
        workerIndex.destroy()
    }
}

@usableFromInline
internal final class Worker {
    @usableFromInline
    typealias Work = () -> ()
    
    public let workQueue: MPSCQueue<Work>
    public let stealableWorkQueue: MPMCBoundedQueue<Work>
    
    public let semaphore: DispatchSemaphore = .init(value: 0)
    public let running: UnsafeAtomic<Bool> = .create(false)
    
    public let workCount: UnsafeAtomic<Int> = .create(0)
    
    init(queueCacheSize: Int) {
        workQueue = MPSCQueue(cacheSize: queueCacheSize)
        stealableWorkQueue = MPMCBoundedQueue(size: queueCacheSize)
    }
    
    @inline(__always)
    public final func submit(_ work: @escaping () -> ()) {
        workCount.wrappingIncrement(ordering: .relaxed)
        if !stealableWorkQueue.enqueue(work) {
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
        running.store(true, ordering: .relaxed)
        let maxIterations = 1000
        while running.load(ordering: .relaxed) {
            var iterations = 0
            var workLeft = 0
            while iterations < maxIterations {
                if let work = stealableWorkQueue.dequeue() {
                    workLeft = workCount.wrappingDecrementThenLoad(ordering: .relaxed)
                    work()
                    iterations = 0
                }
                if let work = workQueue.dequeue() {
                    workLeft = workCount.wrappingDecrementThenLoad(ordering: .relaxed)
                    work()
                    iterations = 0
                }
                if workLeft > 0 {
                    while let work = workQueue.dequeue() {
                        if !stealableWorkQueue.enqueue(work) {
                            workLeft = workCount.wrappingDecrementThenLoad(ordering: .relaxed)
                            work()
                            break
                        }
                    }
                }
                iterations += 1
            }
            
            // Steal other workers work
            for worker in threadPool.workers {
                while let work = worker.steal() {
                    work()
                }
            }
            semaphore.wait()
        }
    }
    
    @inlinable
    public final func steal() -> Work? {
        if let work = stealableWorkQueue.dequeue() {
            workCount.wrappingDecrement(ordering: .relaxed)
            return work
        }
        return nil
    }
    
    @inlinable
    public final func stop() {
        running.store(false, ordering: .relaxed)
        semaphore.signal()
    }
    
    deinit {
        stealableWorkQueue.dequeueAll { work in
            work()
        }
        workQueue.dequeueAll { work in
            work()
        }
        running.destroy()
        workCount.destroy()
    }
}
#endif

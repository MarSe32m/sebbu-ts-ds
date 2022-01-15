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
    private let workerIndex = UnsafeAtomic<Int>.create(0)
    
    private var workers: [WorkerThread] = []
    
    public let numberOfThreads: Int
    
    public init(numberOfThreads: Int, workerThreadCacheSize: Int = 2048) {
        self.numberOfThreads = numberOfThreads
        for _ in 0..<numberOfThreads {
            workers.append(WorkerThread(queueCacheSize: workerThreadCacheSize))
        }
    }
    
    public final func start() {
        workers.forEach {$0.run()}
    }
    
    public final func run(_ block: @escaping () -> ()) {
        var index = workerIndex.loadThenWrappingIncrement(ordering: .relaxed)
        if _slowPath(index < 0) {
            workerIndex.store(Int.random(in: 0...numberOfThreads), ordering: .relaxed)
            index = workerIndex.loadThenWrappingIncrement(ordering: .relaxed)
        }
        workers[index % numberOfThreads].submit(block)
    }
    
    public final func stop() {
        workers.forEach { $0.stop() }
    }
    
    deinit {
        workerIndex.destroy()
    }
}

@usableFromInline
internal final class WorkerThread {
    typealias Work = () -> ()
    
    public let workQueue: MPSCQueue<Work>
    public let semaphore: DispatchSemaphore = .init(value: 0)
    public let running: UnsafeAtomic<Bool> = .create(true)
    
    init(queueCacheSize: Int) {
        workQueue = MPSCQueue(cacheSize: queueCacheSize)
    }
    
    public final func submit(_ work: @escaping () -> ()) {
        workQueue.enqueue(work)
        semaphore.signal()
    }
    
    public final func run() {
        Thread.detachNewThread {
            let maxIterations = 1000
            while self.running.load(ordering: .relaxed) {
                var iterations = 0
                while iterations < maxIterations {
                    while let work = self.workQueue.dequeue() {
                        work()
                        iterations = 0
                    }
                    iterations += 1
                }
                self.semaphore.wait()
            }
        }
    }
    
    public final func stop() {
        running.store(false, ordering: .relaxed)
        semaphore.signal()
    }
    
    deinit {
        running.destroy()
    }
}
#endif

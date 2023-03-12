---
title: Cpp线程池实现
date: 2023-03-12 21:52:04
categories:
- Cpp
tags:
- 线程池
- 并发
- Cpp
---

## 整体设计

![线程池整体设计](/images/Cpp/Cpp线程池实现/ThreadPool.png)

线程池由两部分组成 存放线程的容器(ThreadPool) 和 一个任务队列(Tasks queue)。

容器中的线程都做相同的事情：
- 从任务队列中获取一个任务。
- 执行这个任务。

这些线程会一直重复这两个动作。

例如, 图中 id 为 1，4 的线程已经获得了一个任务，接下来它们要执行这个任务, 然后继续从任务队列中获取任务...

id 为 2, 3, 5 的线程正在从任务队列获得一个任务...

- 会有多个线程访问任务队列，因此任务队列必须要支持并发。
- 每个线程会一直运行直到线程池关闭，从任务队列获取一个任务，执行，不断重复这个过程，如果不能获取一个任务(任务队列中可能没有任务了)，就要阻塞在获取任务这一步，直到获取了任务或线程池关闭。

## 支持并发的队列

```cpp
template <typename T> class SafeQueue {
private:
  std::queue<T> que_;
  std::shared_mutex mutex_;

public:
  void push(T &t);
  T pop();
  size_t size(); 
};
```

使用读写锁对 `std::queue` 做了封装。

### push

```cpp
template<typename T>
void SafeQueue<T>::push(T &t) {
    std::unique_lock lock(mutex_);
    que_.emplace(t);
}
```

### pop

```cpp
template<typename T>
T SafeQueue<T>::pop() {
    std::unique_lock lock(mutex_);
    T ret = que_.front();
    que_.pop();
    return ret;
}
```

### size

```cpp
template<typename T>
size_t SafeQueue<T>::size() {
    std::shared_lock lock(mutex_);
    return que_.size();
}
```

## 线程容器

线程从任务队列获取任务后执行的过程的模型是生产者-消费者。

因此需要一个条件变量 `std::condition_variable`。

```cpp
class ThreadPool {
private:
  class ThreadWorker {
  private:
    ThreadPool *pool_;
    size_t thread_id_;

  public:
    ThreadWorker(ThreadPool *pool, size_t thread_id_)
        : pool_(pool), thread_id_(thread_id_) {}
    void operator()();
  };

  size_t threads_;
  bool shutdown_;
  SafeQueue<std::function<void()>> tasks_;
  std::vector<std::thread> works_;
  std::condition_variable condition_;
  std::mutex mutex_;

public:
  ThreadPool(size_t threads = 2) { init(threads); };
  ThreadPool(const ThreadPool &other) = delete;
  ThreadPool(ThreadPool &&other) = delete;
  ThreadPool &operator=(const ThreadPool &other) = delete;
  ThreadPool &operator=(ThreadPool &&other) = delete;
  ~ThreadPool() { shutdown(); };

  void init(size_t threads);
  void shutdown();
  template <typename F, typename... Arg>
  auto submit(F &&f, Arg &&...args) -> std::future<decltype(f(args...))>;
};
```
### ThreadWorker

使用一个仿函数来模拟一直在运行的线程。

在这里实现了生产者-消费者模型中消费者取产品的过程。

```cpp
void ThreadPool::ThreadWorker::operator()() {
  std::function<void()> func;
  for (;;) {
    {
      std::unique_lock lock(pool_->mutex_);
      pool_->condition_.wait(lock, [this] {
        return pool_->shutdown_ || pool_->tasks_.size() > 0;
      });
      if (pool_->shutdown_ && pool_->tasks_.size() == 0) {
        return;
      }
      func = std::move(pool_->tasks_.pop());
    }
    func();
  }
}
```

### 初始化

在构造函数中调用了 `init` 来提升易用性。

初始化时就把需要使用到的线程数量都启动起来。

```cpp
void ThreadPool::init(size_t threads) {
  threads_ = threads;
  shutdown_ = false;
  while (tasks_.size() != 0) {
    tasks_.pop();
  }
  {
    std::vector<std::thread> tmp_works{};
    works_.swap(tmp_works);
  }
  works_.reserve(threads_);
  works_.resize(threads_);
  for (size_t i = 0; i < threads_; ++i) {
    works_[i] = std::thread(ThreadWorker(this, i));
  }
}
```

### 关闭线程池

关闭线程池时，要等待线程做完事（队列中的任务被全部完成, 在 ThreadWorker 中作判断）。

在析构函数中调用了 `shutdown()` , 利用 RAII 来实现自动关闭。

```cpp
void ThreadPool::shutdown() {
  if (shutdown_) {
    return;
  }
  shutdown_ = true;
  condition_.notify_all();
  for (size_t i = 0; i < threads_; ++i) {
    if (works_[i].joinable()) {
      works_[i].join();
    }
  }
  threads_ = 0;
}
```

### 提交任务

任务是一个函数，可以是任意的返回类型，任意的参数。

使用可变参数模板来实现，支持函数，仿函数，Lambda, 以及任意多的参数。

有的任务在被执行过后会有返回值，需要使用 `std::future<>` 来获得这个值, 任务的返回值类型是多种多样的，所以使用 `decltype()` 来推导返回值的类型。

任务的多样性，没有办法直接确定一个类型来表示它们，对任务进行封装，使所有的任务都是 `void()` 类型。

任务进入队列后，要唤醒一个线程(告诉在阻塞的线程，队列中有了新的任务)。

```cpp
template <typename F, typename... Arg>
auto ThreadPool::submit(F &&f, Arg &&...args) -> std::future<decltype(f(args...))> {
  // forward 完美转发
  std::function<decltype(f(args...))()> func =
      std::bind(std::forward<F>(f), std::forward<Arg>(args)...);

  auto task_ptr =
      std::make_shared<std::packaged_task<decltype(f(args...))()>>(func);

  std::function<void()> wrap_task = [task_ptr] { (*task_ptr)(); };

  tasks_.push(wrap_task);

  condition_.notify_one();

  return task_ptr->get_future();
}
```

## 参考

[C++ 并发编程 (从C++11到C++17)](https://paul.pub/cpp-concurrency/)

[C++的右值引用、移动和值类别系统，你所需要的一切](https://zclll.com/index.php/cpp/value_category.html)

[基于C++11实现的线程池](https://zhuanlan.zhihu.com/p/367309864)

[99行线程池](https://github.com/progschj/ThreadPool)

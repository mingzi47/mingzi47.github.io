---
title: RAII 与 智能指针
date: 2023-02-17T23:45:14+08:00
categories:
- Cpp
tags:
- RAII
- Cpp
- 智能指针
---

在使用指针时，我们有时会忘记 `delete/free` 而导致内存泄漏，或者在复杂的逻辑中将指针重复释放等。

在现代 C++ 中，我们有了很好的方法来解决这些问题。

## RAII

    RAII，全称资源获取即初始化（Resource Acquisition Is Initialization)

将指针封装在一个类中，在类的构造函数中为指针分配资源，在类的析构函数中为释放掉资源。

类在离开它的生命周期后会自动调用析构函数，利用这一点，我们可以不用在担心忘记释放掉资源。

```cpp
class A {
  public:
    A() {
      std::cout << "A()\n";
    }
    ~A() {
      std::cout << "~A()\n";
    }
};

int main() {
  std::cout << "{\n";
  {
    A a{};
  }
  std::cout << "}\n";
  return 0;
}
```

运行结果如下
```
{
A()
~A()
}
```

通过这段代码可以清晰的看到类的构造与析构过程。

RAII 机制让我们更轻松的使用指针。

如果我们把指针封装在一个类中，我们需要注意它的拷贝构造与拷贝赋值函数。如果我们把的拷贝仅是拷贝一个指针，
那么就会导致有多个对象在离开其作用域时释放指针，这是会造成悬垂引用或重复释放。

当然，我们可以借助 RAII 机制来封装一个可以拷贝指针的并且保证安全的指针（`std::shared_ptr`）。

RAII 就是广义上的智能指针。

## 智能指针

我们可以使用 RAII 来帮助我们封装一个更易用且安全的指针。标准库中已经为我们实现了`std::unique_ptr`, `std::shared_ptr`, `std::weak_ptr`。

这些指针也是线程安全的。

### `unique_ptr`

这是一个不可复制的指针。它的拷贝构造函数与拷贝赋值函数都被删除掉了。

```cpp
class unique_ptr {
    ...
  public:
    unique_ptr(unique_ptr &other) = delete
    unique_ptr &operator=(unique_ptr &other) = delete

    unique_ptr(unique_ptr &&other) noexcept;
    unique_ptr &operator=(unique_ptr &&other) noexcept;
    ...
}
```
但是我们实现了它的移动构造与移动赋值函数。

```cpp
unique_ptr<int[]> a = std::make_unique<int[]>(10);
auto cp = a; // 报错, 拷贝构造函数已经被删除。
```

```cpp
  unique_ptr<int[]> a = std::make_unique<int[]>(10);
  a[1] = a[2] = a[3] = 100;
  for (int i = 1; i <= 3; i++) {
    cout << a[i] << " \n"[i==3];    // 正确
  }
  auto cp = std::move(a);
  for (int i = 1; i <= 3; i++) {
    cout << a[i] << " \n"[i==3];    // 报错 段错误
  }
```

`unique_ptr` 确保了我们只会存在一个对象拥有这个数组的指针的所有权，也只有一个对象可以释放这个指针。

`unique_ptr` 几乎是零开销的，因此我们可以在保证安全的同时实现高性能。

### `shared_ptr` 与 `weak_ptr`


`shared_ptr` 是可以被复制的，通过使用计数的方式来确定现在有多少个`shared_ptr`拥有这个指针的所有权。

当计数为 0 时才会释放这个指针，这样就避免了重复释放已及提早释放造成的悬垂指针问题。

**但这里还存在一个严重的问题**：

```cpp
class B;
class A {
  public:
    shared_ptr<B> ptr{};
    ~A() {cout << "~A()\n";}
};
class B {
  public:
    shared_ptr<A> ptr{};
    ~B() {cout << "~B()\n";}
};

int main() {
  shared_ptr<A> a(new A());
  shared_ptr<B> b(new B());
  a->ptr = b;
  b->ptr = a;
  return 0;
}
```

运行之后我们没有得到任何结果，`a` 和 `b` 并没有被释放。

A 的内部有指向 B , B 的内部又指向了 A， 对于 A 需要在 B 析构后才能析构， 对于 B 需要在 A 析构后才能析构，这时谁都无法析构，出现了**循环引用的问题**。

为了解决这个问题，我们引入了 `weak_ptr` 它可以与 `shared_ptr` 指向同一个资源，但是不会增加`shared_ptr` 的计数，并且也不会释放资源。

```cpp
class B;
class A {
  public:
    weak_ptr<B> ptr{};
    ~A() {cout << "~A()\n";}
};
class B {
  public:
    shared_ptr<A> ptr{};
    ~B() {cout << "~B()\n";}
};

int main() {
  shared_ptr<A> a(new A());
  shared_ptr<B> b(new B());
  a->ptr = b;
  b->ptr = a;
  return 0;
}
```
我们将 A 中的 `shared_ptr` 换成 `weak_ptr` ，此时两个对象都可以正确释放。

```
~B()
~A()
```
在这段代码中，a 的计数为 2，b 的计数为 1，可以使用 `shared_ptr::use_count()` 方法来查看计数，

`shared_ptr` 会造成些许性能损失，但保障了安全。

如果可以使用智能指针的话，还是尽量使用智能指针。

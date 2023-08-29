---
title: "基于 C++ 的命令行参数解析"
date: 2023-08-29T23:45:14+08:00
categories:
  - Cpp
tags:
  - Cpp
  - Cpp20
  - Cpp模版
index_img: /images/Cpp/基于Cpp的命令行的参数解析/0.png
---

# 基于 C++ 的命令行参数解析

```bash
test --port 50051 --path /
```

```cpp
cmdline::parse(
  argc, argv,
  cmdline::option("--port", true,
    [](std::string value) { global::port = std::stod(value); }),
  cmdline::option("--path", true,
    [](std::string value) { global::path = value; }),
)
```

这里只是做了封装，值的处理还需传入回调函数来处理。

可以处理 `option value` or `option` 这样的命令行参数，对于多个参数 `option value0 value1 value2`, 可以使用 `option "value0, value1 value2"` 然后在回调函数中处理。

C 库中也有这样的函数 [`getopt`](https://man7.org/linux/man-pages/man3/getopt.3.html), `getopt_long`

## 思路

### C/C++ 中怎么得到命令行参数

```cpp
int main(int argc, char **argv)
```

`argc` 是参数个数，`argv` 是一个字符串数组, 参数被空格分割。

```bash
test --port 50051 --path /
```

```cpp
argc : 5
argv : ["test", "--port", "50051", "--path", "/"]
```

`argv` 的第一个是运行的二进制文件的文件名, 后面是参数按空格分割。

从上面的例子可以发现，解析命令行参数只需要遍历参数数组，匹配对应的 `option`, 如果由 `value` 的话，对应的 `value` 在 `option` 的下一个。

### 封装命令行参数选项

对一个选项，它有一个名字，也可能有一个 `value`，对于这个选项在代码中的作用每个选项都可以不同，不同项目的也不同，因此传入一个回调函数来处理这件事更方便。

```cpp
struct option {
  const std::string opt_name;
  // 判断是否有 `value`
  const bool flag;
  std::function<void(std::string)> callback;
  option(const std::string &&opt_name, bool flag, std::function<void(std::string) &&callback)
    : opt_name(std::move(opt_name)),
      flag(flag),
      callback(std::move(callback)) {}
};
```

### 解析命令行参数

定义一个解析函数，首先需要 `argc`, `argv` 这两个参数，然后是 `option`, `option` 在各个项目里也可能是各不相同的，因此使用变长参数传入。

```cpp
void parse(int argc, char** argv, option opts, ....);
```

在匹配 `argv` 和 `opts` 时，因为 `opt` 的参数是不确定的，那就不知到要写多少个 `if` 来判断了。

如果能遍历可变参数的话就能解决这个问题了，可以传入一个数组指针 :

```cpp
for (int i = 1; i < argc; ++i) {
  for (int j = 0; j < len; ++j) {
    if (argv[i] == opts[j]) {
      ...
    }
  }
}
```

在 C++11 后引入了 **模版形参包** 可以接受任意数量的形参，而且有多种方式遍历参数，函数定义可以改为：

```cpp
template <typename ... Args>
void parse(int argc, char** argv, Args ... opts);
```

这里使用 **初始化列表和逗号表达式** 的方式来展开形参包 :

```cpp
int arr[] = {(parse_opt(i, argc, argv, opts), 0) ...};
```

C++17 之后可以直接使用逗号表达式来解决 ：

```cpp
((parse_opt(i, argc, argv, opts)), ...);
```

把匹配的过程写到了 `parse_opt` 中。

## 完整代码

`cmdline.h` :

```cpp
#include <format>
#include <functional>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <type_traits>

namespace cmdline {
struct option {
  const std::string opt_name;
  const bool flag; // true , has value
  std::function<void(std::string)> callback;
  template <typename T>
    requires std::constructible_from<std::function<void(std::string)>, T>
  constexpr option(const std::string &&opt_name, bool flag, T &&callback)
      : opt_name(std::move(opt_name)), flag(flag),
        callback(std::forward<T>(callback)){};
};

namespace details {
inline int parse_opt(int &index, int argc, char **argv, option &opt) {
  if (argv[index] == opt.opt_name) {
    if (not opt.flag) {
      opt.callback("");
      return 1;
    }
    if (index + 1 >= argc) {
      std::cerr << std::format("missing value to option {}\n", opt.opt_name);
      exit(-1);
    }
    opt.callback(argv[++index]);
    return 1;
  }
  return 0;
}
} // namespace details

template <typename T>
concept Opt = std::is_same_v<T, option>;

template <Opt... Opts> void parse(int argc, char **argv, Opts &&...opts) {
  for (int i = 1; i < argc; ++i) {
    int size = 0;
    int arr[] = {(++size, details::parse_opt(i, argc, argv, opts))...};
    if (std::accumulate(arr, arr + size, 0) == 0) {
      std::cerr << std::format("invalid option : {}\n", argv[i]);
      exit(-1);
    }
  }
}
} // namespace cmdline
```

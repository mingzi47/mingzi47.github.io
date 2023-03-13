---
title: "【计算机网络】Stanford CS144 Lab0 学习记录"
date: 2023-02-06T23:45:14+08:00
draft: true
tags : [ 
"CS144","Lab"                                   
]
categories : [
"计算机网络"                              
]
keywords : [                                
]
---
# 计算机网络

CS144 官方镜像 : [https://cs144.github.io/](https://cs144.github.io/)

[kangyupl](https://www.cnblogs.com/kangyupl/)备份的镜像 : [https://kangyupl.gitee.io/cs144.github.io/](https://kangyupl.gitee.io/cs144.github.io/)

## 实验准备

--- 

- Ubuntu 18.04.6 LTS x86_64 ([实验提供](https://stanford.edu/class/cs144/vm_howto/vm-howto-image.html))
- gcc8 或 clang6 (实验机提供的gcc是7.5, 没有达到实验文档要求) 

## Writing webget

---

要求使用 [`TCPSocket`](https://kangyupl.gitee.io/cs144.github.io/doc/lab0/class_t_c_p_socket.html) 和 [`Address`](https://kangyupl.gitee.io/cs144.github.io/doc/lab0/class_address.html) 来抓取网页内容。

TCP 套接字编程，实验已经使用 C++ 封装好了 `TCPSocket` 。

建立 `TCPSocket` , 并向目标主机的 `80` 号端口建立 TCP 连接。

发送 HTTP 请求报文。

HTTP 报文格式

```
GET /somedir/page.html HTTP/1.1\r\n
Host: www.someschool.edu\r\n
Connection: close\r\n
User-agent: Mozilla/5.0\r\n
Accept-language: fr\r\n
\r\n
```

发送完报文，使用 `shutdown(SHUT_WR)` 表示请求发送完了。

之后使用 `read()` 读取目标主机返回的报文即可。

```cpp
TCPSocket sock{};
sock.connect(Address{host, "http"});
sock.write("GET " + path + " HTTP/1.1\r\nHost: " + host + "\r\n\r\n");
sock.shutdown(SHUT_WR);
while (!sock.eof()) {
    cout << sock.read();
}
sock.close();
```

## An in-memory reliable byte stream

---

在内存中实现一个可靠的字节流对象，可以按照写的顺序读出数据。这个字节流是可以边写边读的。字节流读的操作会把数据从数据结构头部位置开始 `pop` 数据，写的操作会从数据结构的尾部 `push` 数据，因此我们考虑使用 `std::deque` 来实现。

为什么不使用 `std::queue` ?

读的操作分为了两步，第一步是从读取长度为 `len` 的字节流，第二步是将这长度为 `len` 的字节流从数据结构中删除。

这两个操作分为了两个函数。对于第一个函数，我们需要一个 `iterator` 来选取要取出的字节范围，而 `std::queue` 没有提供一个 `iterator` 接口。

当然，也可以使用 `std::list` 来实现这个数据结构。

### `byte_stream.hh`

```cpp
class ByteStream {
  private:
    std::deque<char> _buffer{};
    size_t _capacity = 0;
    size_t _write_cnt = 0;
    size_t _pop_cnt = 0;
    bool _stream_end = false;
    bool _error = false; 
    ...
```

### `byte_stream.cc`

构造函数

```cpp
ByteStream::ByteStream(const size_t capacity) : _capacity{capacity} {}
```

写的操作，因为我们的 `_buffer` 是有容量限制的，因此要判断要写入的是否超过了容量。

```cpp
size_t ByteStream::write(const string &data) {
    const size_t res = std::min(data.size(), _capacity - _buffer.size());
    _write_cnt += res;
    for (size_t i = 0; i < res; i++) {
        _buffer.push_back(data[i]);
    }
    return res;
}
```

读的操作，先 `peek_output` 再 `pop_output`。

```cpp
string ByteStream::peek_output(const size_t len) const {
    const size_t peek_len = std::min(len, _buffer.size());
    return std::string{}.assign(_buffer.begin(), _buffer.begin() + peek_len);
}
```

```cpp
void ByteStream::pop_output(const size_t len) {
    const size_t pop_len = std::min(len, _buffer.size());
    _pop_cnt += pop_len;
    for (size_t i = 0; i < pop_len; i++) {
        _buffer.pop_front();
    }
    return;
}
```

```cpp
// 输入结束，由使用者调用
void ByteStream::end_input() { _stream_end = true; }
// `true` 表示 输入结束
bool ByteStream::input_ended() const { return _stream_end; }
// buffer 现在有多少字节
size_t ByteStream::buffer_size() const { return _buffer.size(); }
// `true` 表示 buffer 是空的
bool ByteStream::buffer_empty() const { return _buffer.empty(); }
// ‘true’ 表示 读 完了数据
bool ByteStream::eof() const { return buffer_empty() && input_ended(); }
// 写入了多少字节，写入时累积
size_t ByteStream::bytes_written() const { return _write_cnt; }
// 弹出 buffer 的数据大小
size_t ByteStream::bytes_read() const { return _pop_cnt; }
// 目前空余的容量大小
size_t ByteStream::remaining_capacity() const { return _capacity - _buffer.size(); }
```

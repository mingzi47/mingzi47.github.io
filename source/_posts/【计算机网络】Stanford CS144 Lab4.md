---
title: "【计算机网络】Stanford CS144 Lab4 学习记录"
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
## 整体设计

![实验整体设计](/images/计算机网络/CS144/Lab4/实验整体设计.png)

## TCP FSM


### **接收数据**：
- 如果接收到了带有 `RST` 标志的段，就要立即进行 `unclean_shutdown`
- 如果接收到的段没有 `RST` 标志，将有 `TCPReceiver` 来处理这个段的 `SYN`, `payload`, `FIN` 和 `seqno` 。
- 若果这个段的 `seqno` 是无效的，或者 `TCPReceiver` 接收这个段失败时，要发送一个空的段给对方

### **发送数据**：
- `TCPSender` 将段发送到自己的队列时，`TCPConnection` 就要从 `TCPSender` 中取出来放到自己的队列中，在这个过程中如果 `TCPReceiver` 的 `ackno` 为有效值的话，就要给这些段加上 `ACK` 标记，自己的`ackno` 以及 `window size`。
- `TCPConnection` 通过 `tick` 函数获得时间，我们要将时间交给 `TCPSender` 的 `tick` 函数，让它来进行重传操作。
- 重传的次数超过 `TCPConfig::MAX_RETX_ATTMPTS` 的话就要发送一个 `RST` 的段。
- 如果 `TCPConnection` 的 `active` 为真，这时 `TCPConnection` 析构了，就要立即发送一个 `RST` 段。

### **`unclean_shutdown`**：

- 收到 `RST` 标志的段，就是 `unclear_shutdown`.

### **`clean_shutdown`**：

完成 4 次挥手。

- 先收到 `FIN` 的一方，在最后发送完不需要进行等待。

- 先发送 `FIN` 的一方，最后发送 `ACK` 后需要等待一定时间。

- 先收到 `FIN` 的一方，在收到对方对自己 发送的 `FIN` 的确认 `ACK` 后，就立刻关闭了，不在发送其他数据。

- 先发送 `FIN` 的一方通过等待 10 $\times$ 初始超时时间限制 时间来确认对方收到了自己的 `ACK` , 在这段时间里没有重传就结束。 

感觉代码有些难写，多次测试不能完全保证每次测试都通过。


### **TCP 有限状态机**

![TCP FSM](/images/计算机网络/CS144/Lab4/TCP-FSM.png)

### **Receiver**

![receiver](/images/计算机网络/CS144/Lab4/receiver.png)


### **Sender**

![sender](/images/计算机网络/CS144/Lab4/sender.png)

## 性能优化

使用 `gprof` 工具分析性能。


![优化前](/images/计算机网络/CS144/Lab4/性能分析.png)

可以看到 `ByteStream::write` , `ByteStream::peek_output` 和 `ByteStream::pop_output` 占用了快 90% 的时间，这主要是方法内部实现使用的深拷贝。

实验在 `util` 提供了 `Buffer` , `BufferList` 和 `BufferListView` 这样的类。

`Buffer` 的 `remove_prefix` 方法是常数级别的删除前 `n` 个字符。`Buffer`存放的是智能指针，及 `size_t` 类型的标记来表示字符的开始位置，删除前 `n` 个字符只需要变动这个标记即可，智能指针指向的内存会随着 `Buffer` 的析构而释放，在获得性能的同时保持安全。

使用 `BufferList` 重写 `ByteStream` 后的性能分析。 

![优化后](/images/计算机网络/CS144/Lab4/性能优化.png)

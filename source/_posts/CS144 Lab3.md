---
title: "CS144 Lab3 : TCPSender"
date: 2023-01-16T23:45:14+08:00
tags:
- "CS144"
- "Lab"                                   
categories:
- "计算机网络"                              
index_img: /images/计算机网络/CS144/Lab3/定时器启动时机.png
---

实现 TCP 协议中的发送器 `TCPSender` 。

TCP 通过累积确认的方式来标记哪些段不需要跟踪了，发送方收到了一个 `ackno` ，表示接收方已经接收了 `ackno` 之前的所有数据。可以使用 `queue` 来跟踪没被确认的，一旦确认了就出队，同时也方便重传数据。

累积确认类似与 GBN（go back N）协议。在接收方 GBN 机制选择将待确认的全部丢弃了，在这次实验中 (Lab2), 选择了缓存这些待确认的，这类似与 SR（Selective Repeat）协议。

## **定时器机制**

- 一段报文被发送时，定时器没有开启就开启，开启了就什么都不做。
- 定时器超时，这是就要重传还没有被确认的序号最小的段，同时，超时时间限制要扩大两倍，定时器重新计时。
- 收到一个合法的 `ackno` 时（严格大于已经被确认的最大的序号），定时器的超时时间限制回到初始值，并且不再跟踪已经确认的段，如果还有跟踪的段，开启定时器。

![定时器启动时机](/images/计算机网络/CS144/Lab3/定时器启动时机.png)

**如果一个段的一部分被确认了，这个段仍然被认为是没有被确认的**，事实上，TCP的实现上可以认为它是被确认的。作为实验，这里简化了操作。

需要注意的是，第一次握手时发送的段只包含 `SYN` 不包含其他数据。 

在 Lab3 中 我们有一个发送空段的函数 `send_empty_segment` 可以用来探测接收方容量窗口大小，但是在 Lab2 中，并没处理接收一个空段会怎样。

### `tcp_receiver.cc`

```cpp
bool TCPReceiver::segment_received(const TCPSegment &seg) {
	// ....
    const uint64_t abs_seqno = unwrap(seg.header().seqno, _isn.value(), _pos);
    const uint64_t index = abs_seqno + (issyn ? 1 : 0);

    // 在 Lab3 之后，了解到可能发送一个空的 TCPSegment 用来侦测
    const bool received_empty_segment = abs_seqno == _pos && seg.length_in_sequence_space() == 0;
    if (received_empty_segment) return true;
	// ....
}
```

### `tcp_sender.hh`

```cpp
class TCPSender {
  private:
    // ....
    uint64_t _recv_ackno{0};

    bool _syn_flag{false};
    bool _fin_flag{false};

    uint64_t _windows_size{0};
    std::queue<TCPSegment> _segments_outstanding{};

    uint64_t _timer{0};
    uint64_t _timeout;
    bool _time_running{false};

    uint64_t _byte_in_flight{0};
    uint64_t _consecutive_retransmissions{0};
    // ....
```

### `tcp_sender.cc`

```cpp
TCPSender::TCPSender(const size_t capacity, const uint16_t retx_timeout, const std::optional<WrappingInt32> fixed_isn)
    : _isn(fixed_isn.value_or(WrappingInt32{random_device()()}))
    , _initial_retransmission_timeout{retx_timeout}
    , _stream(capacity)
    , _timeout{retx_timeout} {}

uint64_t TCPSender::bytes_in_flight() const { return _byte_in_flight; }

void TCPSender::fill_window() {
    if (!_syn_flag) {
        TCPSegment seg{};
        seg.header().syn = true;
        send_segment(seg);
        _syn_flag = true;
        return;
    }

    const size_t win_size = _windows_size ? _windows_size : 1;
    size_t remain_win{};
    while ((remain_win = win_size - _next_seqno + _recv_ackno) > 0 && !_fin_flag) {
        TCPSegment seg{};
        const uint16_t length = std::min(TCPConfig::MAX_PAYLOAD_SIZE, remain_win);
        std::string data = _stream.read(length);
        seg.payload() = Buffer{std::move(data)};

        const bool eof = _stream.eof() && seg.length_in_sequence_space() < win_size;
        if (eof) {
            seg.header().fin = true;
            _fin_flag = true;
        }

        const bool empty_segment = seg.length_in_sequence_space() == 0;
        if (empty_segment) return;
        send_segment(seg);
    }
}

bool TCPSender::ack_received(const WrappingInt32 ackno, const uint16_t window_size) {
    const uint64_t abs_seqno = unwrap(ackno, _isn, _recv_ackno);

    if (abs_seqno > _next_seqno) return false;
    _windows_size = window_size;

    if (abs_seqno <= _recv_ackno) return true;
    _recv_ackno = abs_seqno;

    _timeout = _initial_retransmission_timeout;
    _consecutive_retransmissions = 0;

    while (!_segments_outstanding.empty()) {
        TCPSegment& seg = _segments_outstanding.front();
        const bool ac_segments = unwrap(seg.header().seqno, _isn, _recv_ackno) 
            + seg.length_in_sequence_space() <= abs_seqno;
        if (ac_segments) {
            _byte_in_flight -= seg.length_in_sequence_space();
            _segments_outstanding.pop();
        } else break;
    }

    fill_window();
    // 事件 ： 如果当前有未被确认的报文段，开始定时器
    if (!_segments_outstanding.empty()) {
        _time_running = true;
        _timer = 0;
    }
    return true;
}

void TCPSender::tick(const size_t ms_since_last_tick) {
    _timer += ms_since_last_tick; // ms_since_last_tick 过去了多长时间

    const bool timeout_resend = _timer >= _timeout && !_segments_outstanding.empty();

    // 事件：定时器超时
    if (timeout_resend) {
        _segments_out.push(_segments_outstanding.front());
        _consecutive_retransmissions++;
        _timeout *= 2;
        _time_running = true;
        _timer = 0;
    }

    if (_segments_outstanding.empty()) {
        _time_running = false;
    }
}

unsigned int TCPSender::consecutive_retransmissions() const { return _consecutive_retransmissions; }

void TCPSender::send_empty_segment() {
    TCPSegment res{};
    res.header().seqno = wrap(_next_seqno, _isn);
    _segments_out.push(res);
}

void TCPSender::send_segment(TCPSegment& seg) {
    seg.header().seqno = wrap(_next_seqno, _isn);
    _next_seqno += seg.length_in_sequence_space();
    _byte_in_flight += seg.length_in_sequence_space();
    _segments_out.push(seg);
    _segments_outstanding.push(seg);
    // 事件： 从上面的应用程序接收到数据，定时器没有启动
    if (!_time_running) {
        _time_running = true;
        _timer = 0;
    }
}
```

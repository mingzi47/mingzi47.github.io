---
title: "【计算机网络】Stanford CS144 Lab2 学习记录"
date: 2023-02-06T23:45:14+08:00
draft: true
tags : [ 
"CS144","Lab","计算机网络"                                   
]
categories : [
"CS144"                              
]
keywords : [                                
]
---
这次实验的目标为实现一个 TCP协议 的接收器。

## Sequence Numbers

| Sequence Numbers  | Absolute Sequence Numbers | Stream Indices        |
| ----------------- | ------------------------- | --------------------- |
| Start at the ISN  | Start at 0                | Start at 0            |
| Include SYN/FIN   | Include SYN/FIN           | Omit SYN/FIN          |
| 32 bits, wrapping | 64 bits, non-wrapping     | 64 bits, non-wrapping |
| "seqno"           | "absolute seqno"          | "stream index"        |

我们要实现的就是 "seqno" 与 "absolute seqno" 之间的互相转换。

"seqno" => "absolute seqno" 

"seqno" 向 "absolute seqno" 的转换可能并不唯一， 因此我们找到离 `checkpoint` 最近的那一个。

"seqno" 一定是在 $[max(checkpoint - (1 << 31), 0), checkpoint + (1 <<31)]$

```cpp
WrappingInt32 wrap(uint64_t n, WrappingInt32 isn) {
    const uint64_t max_seqno = uint64_t{1} << 32;
    if (n < max_seqno - isn.raw_value()) {
        return WrappingInt32{isn + n};
    }
    n -= (max_seqno - isn.raw_value());
    const uint32_t res = n % max_seqno;
    return WrappingInt32{res};
}

uint64_t unwrap(WrappingInt32 n, WrappingInt32 isn, uint64_t checkpoint) {
    // DUMMY_CODE(n, isn, checkpoint);
    const uint64_t max_seqno = uint64_t{1} << 32;
    const int32_t count = (checkpoint < max_seqno ? 0 : checkpoint / max_seqno);
    uint64_t res{0};
    if (n.raw_value() >= isn.raw_value()) {
        res = n.raw_value() - isn.raw_value();
    } else {
        res = max_seqno - isn.raw_value() + n.raw_value();
    }
    res += (max_seqno * count);
    if (res > checkpoint && res >= max_seqno) {
        if (res - checkpoint > max_seqno / 2) res -= max_seqno;
    } else if (res < checkpoint) {
        if (checkpoint - res > max_seqno / 2) res += max_seqno;
    }
    return res;
}
```

## Implementing the TCP receiver

需要注意：

- 在接收一个 SYN 前，任何数据段都会被拒绝

- 接收一个 SYN 后，不再接收含有 SYN 的 `TCPSegment`

- 接收一个 FIN 后，不再接收含有 FIN 的 `TCPSegment`

- `TCPSegment` 的数据与接收窗口没有交集就会被拒绝

- SYN 和 FIN 都会占用一个序号

`stream_reassembler.hh`

```cpp
class StreamReassembler {
  public:
    size_t head_index() const { return _head_index; }
    bool input_ended() const { return _output.input_ended(); }
    // ...
}
```

`tcp_receiver.hh`

```cpp
class TCPReceiver {
    //! Our data structure for re-assembling bytes.
    StreamReassembler _reassembler;

    //! The maximum number of bytes we'll store.
    size_t _capacity;

    uint64_t _pos{0};
    bool _fin{false};
    std::optional<WrappingInt32> _isn{std::nullopt};
    // ...
```

`tcp_receiver.cc`

```cpp
bool TCPReceiver::segment_received(const TCPSegment &seg) {
    const bool issyn = seg.header().syn;
    const bool isfin = seg.header().fin;
    const bool refuse = (_isn != nullopt && issyn) || (_fin && isfin) || (_isn == nullopt && !issyn);

    if (refuse) return false;
    if (issyn) {
        _isn = seg.header().seqno;
        _pos = 1;
    }

    if (isfin) _fin = true;

    const uint64_t abs_seqno = unwrap(seg.header().seqno, _isn.value(), _pos);
    const uint64_t index = abs_seqno + (issyn ? 1 : 0);

    const bool inbound = abs_seqno + seg.length_in_sequence_space() <= _pos || abs_seqno >= _pos + window_size();

    if (!issyn && !isfin && inbound) 
        return false;
    // SYN 不被算在 “Stream index” 中，因此index - 1。
    _reassembler.push_substring(seg.payload().copy(), index - 1, isfin); 
    _pos = _reassembler.head_pos() + 1;
    // FIN 会占一个序号
    if (_reassembler.input_ended()) {  
        _pos++;
    }

    return true;
}

optional<WrappingInt32> TCPReceiver::ackno() const {
    return _pos == 0 ? std::nullopt : optional<WrappingInt32>{wrap(_pos, _isn.value())};
}

size_t TCPReceiver::window_size() const { return _reassembler.stream_out().remaining_capacity(); }
```

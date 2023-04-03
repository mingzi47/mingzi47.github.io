---
title: "CS144 Lab1 : 流重组器"
date: 2023-01-08T23:45:14+08:00
tags:
- "CS144"
- "Lab"                                  
categories:
- "计算机网络"
---
## Putting substrings in sequence

实现一个流重组器。可以将带有索引的流碎片按照顺序重组。这些流碎片是可以重复的部分，但是不会有冲突的部分。这些流碎片将通过 Lab0 中 实现的 `ByteStream` 来将其有序的传输出去。

需要注意的是：

- eof 不一定是最后一个片段被传入的

- 如果该字节流前面的字节没有被写入 `ByteStream`, 该字节流不能被写入 `ByteStream`， 一旦可以写入，就要立即写入。

- 容量限制，不限制的话，流重组器会越来越大。

- 会存在为空的带 `EOF` 的字符串

最初，使用 `std::map<size_t, std::string>` 来实现， `key` 中存放的是 `index + data.size()`, 这样可以非常方便的使用 `lower_bound` 来确认一个新的片段要与 `map` 中的哪些段合并。写完测试也通过了(当时运气好)，但是第二遍测试就挂掉了，由于代码写的太乱，就用其他方法重写了。

把操作分为三部

- 剪切掉已经写入 `_output` 的部分。

- 与 `map` 中的其他片段合并。

- 写入 `_output`

关于片段合并，我使用一个结构体 `SubString` 来存储片段， 同时为这个结构体设置一个 `merge` 方法， 让它可以把其他的结构体合并到自己身上， 返回值为 ：

- 如果不能合并， 返回 `std::nullopt`

- 如果可以合并， 返回这两个片段中有多少字段重复的

通过 `lower_bound` 来找可以合并的片段即可。

`stream_reassembler.hh`

```cpp
struct SubString {
    std::string _data{};
    size_t _begin{0};
    size_t _size{0};

    SubString() = default;
    SubString(const std::string &data, const size_t begin, const size_t size)
      : _data{data}, _begin{begin}, _size{size} {}

    bool operator<(const SubString &rhs) const { return _begin < rhs._begin; }

    std::optional<size_t> merge(const SubString &other) {
        SubString lhs{}, rhs{};
        if (_begin > other._begin) {
            lhs = other;
            rhs = *this;
        } else {
            lhs = *this;
            rhs = other;
        }
        // can't merge
        if (lhs._begin + lhs._size < rhs._begin) return std::nullopt; 
        // \in
        if (lhs._begin + lhs._size >= rhs._begin + rhs._size) {
          *this = lhs;
          return rhs._size;
        }
        const size_t res = lhs._begin + lhs._size - rhs._begin;
        lhs._data += rhs._data.substr((lhs._begin + lhs._size) - rhs._begin);
        lhs._size = lhs._data.size();
        *this = lhs;
        return res;
    }
};

//! \brief A class that assembles a series of excerpts from a byte stream (possibly out of order,
//! possibly overlapping) into an in-order byte stream.
class StreamReassembler {
  private:
    // Your code here -- add private members as necessary.
    std::set<SubString> _buffer{};
    size_t _unassembled_bytes{0};
    size_t _head_pos{0};
    bool _is_eof{false};
    ByteStream _output;  //!< The reassembled in-order byte stream
    size_t _capacity;    //!< The maximum number of bytes

    SubString cut_substring(const std::string &data, const size_t index);
    void merge_substring(SubString &ssd);
    // ...
```

`stream_reassembler.cc`

```cpp
void StreamReassembler::push_substring(const string &data, const size_t index, const bool eof) {
    // DUMMY_CODE(data, index, eof);
    if (index >= _head_pos + _capacity) return;

    SubString ssd = cut_substring(data, index);
    merge_substring(ssd);

    while (_unassembled_bytes > 0 && _output.remaining_capacity() > 0) {
        auto iter = _buffer.begin();
        if (iter->_begin != _head_pos) break;
        const size_t push_len = _output.write(iter->_data);
        _unassembled_bytes -= push_len;
        _head_pos += push_len;
        if (iter->_size == push_len) {
            _buffer.erase(iter);
        } else {
            SubString unass{std::string{}.assign(iter->_data.begin() + _head_pos, iter->_data.end())
            ,_head_pos, iter->_size - push_len};
            _buffer.erase(iter);
            _buffer.insert(unass);
        }
    }
    if (index + data.length() <= _head_pos + _capacity && eof) {
        _is_eof |= eof;
    } 
    if (_unassembled_bytes == 0 && _is_eof) {
        _output.end_input();
    }
}

SubString StreamReassembler::cut_substring(const std::string &data, const size_t index) {
    // \in
    SubString res{};
    if (index + data.size() <= _head_pos) return res;
    // 
    else if (index < _head_pos) {
        const size_t len = _head_pos - index;
        res._begin = _head_pos;
        res._data.assign(data.begin() + len, data.end());
        res._size = res._data.size();
    } else {
        res._begin = index;
        res._data = data;
        res._size = data.size();
    }
    _unassembled_bytes += res._size;
    return res;
}

void StreamReassembler::merge_substring(SubString &ssd) {
    if (ssd._size == 0) return; 
    do {
        // next
        auto iter = _buffer.lower_bound(ssd);
        std::optional<size_t> res{};
        while (iter != _buffer.end() && (res = ssd.merge(*iter)) != std::nullopt) {
            _unassembled_bytes -= res.value();
            _buffer.erase(iter);
            iter = _buffer.lower_bound(ssd);
        }
        // pre
        if (iter == _buffer.begin()) break;
        iter--;

        while (iter != _buffer.end() && (res = ssd.merge(*iter)) != std::nullopt) {
            _unassembled_bytes -=  res.value();
            _buffer.erase(iter);
            iter = _buffer.lower_bound(ssd);
            if (iter == _buffer.begin()) break;
            iter--;
        }
    } while(false);
    _buffer.insert(ssd);
}

size_t StreamReassembler::unassembled_bytes() const { return _unassembled_bytes; }

bool StreamReassembler::empty() const { return _unassembled_bytes == 0; }
```

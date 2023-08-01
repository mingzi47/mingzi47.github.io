---
title: "gRPC 的安装与简单使用"
date: 2023-08-01T23:45:14+08:00
categories:
  - gRPC
tags:
  - gRPC
  - cpp
  - 网络编程
index_img: /images/gRPC/gRPC的安装与使用/0.png
---

# gRPC 的安装与使用

```bash
OS: Arch Linux on Windows 10 x86_64
Kernel: 5.15.90.1-microsoft-standard-WSL2
```

## 安装

[官网教程](https://grpc.io/docs/languages/cpp/quickstart/)

我选择安装在 `$HOME/.local` 这个目录中。

### 准备构建工具

首先需要安装 `cmake`, 版本不能低于 `3.13`， 可以使用包管理器安装。

接着就是构建 gRPC 的其他工具了 `build-essential`, `autoconf`, `libtool `, `pkg-config`

在 `Debian/Ubuntu` 中直接使用包管理安装即可，在 `Arch Linux` 中，`build_essential` 在仓库中的名字是 `base-devel`。

### 安装 gRPC

从 Github 上将 `grpc` 和它的子模块都克隆下来：

```bash
git clone --recurse-submodules -b v1.56.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc
```

接着就可以开始构建 `gRPC` 了， 构建 `gRPC` 的同时还会构建 `Protocol Buffers`。

```bash
$ cd grpc
$ mkdir -p cmake/build
$ pushd cmake/build
$ cmake -DgRPC_INSTALL=ON \
      -DgRPC_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=$HOME/.local \
      ../..
$ make -j 4
$ make install
$ popd
```

这样就安装好了， 安装目录在 `$HOME/.local` 下，有`bin`, `include`, `lib`, `share` 四个部分，把 `bin` 文件夹添加到环境变量里 :

```shell
export PATH=$HOME/bin:/usr/local/bin:$PATH
```

重启终端就能直接使用 `$HOME/.local/bin` 下的文件。

## 使用

使用 `cmake` 来构建一个简单的 gRPC Demo 来体验。

客户端向服务端发送包含了一个数字的请求，服务端返回一个数组，这个数组使用请求中的数字填充，大小也是请求中的数字。

### CMakeLists

```bash
.
├── client
│   └── client.cpp
├── CMakeLists.txt
├── proto
│   ├── CppProto
│   └── Messages.proto
├── README.md
└── server
    └── server.cpp
```

`Messages.proto` 生成的文件放到 `CppProto` 中

`CMakeLists.txt` 的编写还是非常复杂的，官方给的例子中也是一层套一层。

主要是 gRPC 相关的库

```cmake
cmake_minimum_required(VERSION 3.20.0)

project(grpc_test LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_C_STANDARD 11)
set(CMAKE_EXPORT_COMPILE_COMMANDS YES)

# 查找本地Protobuf模块的库信息，实际上CMake就是在找Protobuf-config.cmake文件
set(protobuf_MODULE_COMPATIBLE TRUE)
find_package(Protobuf CONFIG REQUIRED)
message(STATUS "Using protobuf ${Protobuf_VERSION}")

set(_PROTOBUF_LIBPROTOBUF protobuf::libprotobuf)
set(_REFLECTION gRPC::grpc++_reflection)
if(CMAKE_CROSSCOMPILING)
  find_program(_PROTOBUF_PROTOC protoc)
else()
  set(_PROTOBUF_PROTOC $<TARGET_FILE:protobuf::protoc>)
endif()

# 查找本地gRPC模块的库信息
find_package(gRPC CONFIG REQUIRED)
message(STATUS "Using gRPC ${gRPC_VERSION}")

set(_GRPC_GRPCPP gRPC::grpc++)
if(CMAKE_CROSSCOMPILING)
  find_program(_GRPC_CPP_PLUGIN_EXECUTABLE grpc_cpp_plugin)
else()
  set(_GRPC_CPP_PLUGIN_EXECUTABLE $<TARGET_FILE:gRPC::grpc_cpp_plugin>)
endif()


include_directories("./")
include_directories(${PROJECT_SOURCE_DIR}/proto/CppProto)

file(GLOB proto_srcs_hdrs ${PROJECT_SOURCE_DIR}/proto/CppProto/*.cc)

# 生成proto 文件并链接库
add_library(rg_grpc_proto ${proto_srcs_hdrs})
target_link_libraries(rg_grpc_proto
  ${_REFLECTION}
  ${_GRPC_GRPCPP}
  ${_PROTOBUF_LIBPROTOBUF})

# 生成二进制文件并链接库
file(GLOB server_src ${PROJECT_SOURCE_DIR}/server/*.cpp)
file(GLOB client_src ${PROJECT_SOURCE_DIR}/client/*.cpp)


add_executable(server ${server_src})
target_link_libraries(server
  rg_grpc_proto
  ${_REFLECTION}
  ${_GRPC_GRPCPP}
  ${_PROTOBUF_LIBPROTOBUF}
)

add_executable(client ${client_src})
target_link_libraries(client
  rg_grpc_proto
  ${_REFLECTION}
  ${_GRPC_GRPCPP}
  ${_PROTOBUF_LIBPROTOBUF})
```

### Protocol Buffers

`Messages.proto`

```proto
syntax = "proto3";

package Test;

service GetService {
  rpc GetVec(Request) returns (Reponse) {}
}

message Request {
  int32 num = 1;
}

message Reponse {
  repeated int32 vec = 1;
}
```

### server

`server.cpp`

```cpp
#include "Messages.grpc.pb.h"
#include <grpcpp/security/server_credentials.h>
#include <grpcpp/server_builder.h>
#include <grpcpp/server_context.h>
#include <grpcpp/support/status.h>
#include <iostream>
#include <memory>
#include <grpcpp/grpcpp.h>

class GetServiceImpl final : public Test::GetService::Service {
  auto GetVec(grpc::ServerContext *context, const Test::TestRequest *req, Test::TestReponse *rep) -> grpc::Status {
    int num = req->num();
    std::cout << "request value : " << req->num() << "\n";
    for (int i = 0; i< num; ++i) {
      rep->add_vec(num);
    }
    return grpc::Status::OK;
  }

};

auto RunServer() -> void {
  std::string server_address("0.0.0.0:50051");

  GetServiceImpl service;

  grpc::ServerBuilder builder;
  builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
  builder.RegisterService(&service);
  std::unique_ptr<grpc::Server> server(builder.BuildAndStart());

  std::cout << "Server listening on " << server_address << "\n";
  server->Wait();
}

int main() {
  RunServer();
}
```

### client

`client.cpp`

```cpp
#include "Messages.grpc.pb.h"
#include "Messages.pb.h"
#include <format>
#include <grpcpp/client_context.h>
#include <grpcpp/create_channel.h>
#include <grpcpp/impl/channel_interface.h>
#include <grpcpp/security/credentials.h>
#include <iostream>
#include <memory>

class GetServiceClient {
public:
  GetServiceClient(std::shared_ptr<grpc::ChannelInterface> channel) : stub_(Test::GetService::NewStub(channel)) {}

  auto GetVec(int num) {
    Test::TestRequest req;
    Test::TestReponse rep;
    req.set_num(num);
    grpc::ClientContext context;
    grpc::Status status = stub_->GetVec(&context, req, &rep);
    if (status.ok()) {
      std::cout << "reponse status : OK\nreponse value : ";
     for (auto v : rep.vec()) {
       std::cout << v << " ";
     }
      std::cout << "\n";
    } else {
      std::cout << std::format("reponse status : {} \n", status.error_message());
    }
  }

  private:
    std::unique_ptr<Test::GetService::Stub> stub_;
};

int main() {
  auto channel = grpc::CreateChannel("localhost:50051", grpc::InsecureChannelCredentials());
  GetServiceClient client(channel);
  while (true) {
    int num = 0;
    std::cin >> num;
    client.GetVec(num);
  }

}
```

### 测试

![两个客户端和一个服务端](/images/gRPC/gRPC的安装与使用/0.png)

---
title: "文档工具 Doxygen"
date: 2023-02-10T23:45:14+08:00
draft: true
tags : [                                    
    "工具", "Doxygen", "CMake"
]
categories : [                              
    "工具"
]
keywords : [                                
]
---

## Doxygen 

### 生成配置

使用 `doxygen -g` 生成默认配置 或者 使用 `doxygen -g <config_file>` 通过模板来生成配置。


### 运行

使用 `doxygen <config_file>` 来运行，也可以与构建工具 `CMake` 相结合使用。


### 语法

有多种方法可以将注释标记为文档, 具体可以查看[官方文档](https://doxygen.nl/manual/docblocks.html)

C++ 风格
```cpp
//! ...text...
```

or

```cpp
/// ...text...
```

常用指令：
|指令|解释|
|---|---|
|\file |档案的批注说明。|
|\author|作者的信息|
|\brief|用于class 或function的批注中，后面为class 或function的简易说明。|
|\param|格式为\param arg_name 参数说明主要用于函式说明中，后面接参数的名字，然后再接关于该参数的说明。|
|\return|后面接函数传回值的说明。用于function的批注中。说明该函数的传回值。|
|\retval|格式为\retval value 传回值说明.主要用于函式说明中，说明特定传回值的意义。所以后面要先接一个传回值。然后在放该传回值的说明。|

更多指令参考[官方文档](https://doxygen.nl/manual/commands.html)

## 在 CMake 中使用 Doxygen

### 文件结构

```shell
project
├── CMakeLists.txt
└── docs
    ├── Doxyfile.in
    └── doxyfile.cmake
```

### Doxyfile

使用 `doxygen -g` 命令可以在当前位置生成一份 `Doxyfile` 的默认配置。

[`ejson`](https://github.com/mingzi47/ejson) 中的 `Doxyfile.in` （使用了 `graphviz`）:
```cpp
# Doxyfile 1.9.6
# 编码
DOXYFILE_ENCODING      = UTF-8
# 项目名
PROJECT_NAME           = "ejson"
# 项目描述
PROJECT_BRIEF          = "A recursive descent-based JSON interpreter and generator implemented using C++17."
# 版本号
PROJECT_NUMBER         = 0.0.1
PROJECT_LOGO           = 
# 程序文档输入目录
INPUT                  = @PROJECT_SOURCE_DIR@
# 递归遍历当前子目录
RECURSIVE              = YES
# 排除的文档
EXCLUDE                = @PROJECT_SOURCE_DIR@/docs @PROJECT_SOURCE_DIR@/build @PROJECT_SOURCE_DIR@/test
# 文档输出目录
OUTPUT_DIRECTORY       = "@PROJECT_BINARY_DIR@/doc"
# 是否关注大小写名称，注意，如果开启了，那么所有的名称都将被小写。
CASE_SENSE_NAMES       = NO
# 按字母顺序排序, 否则按文件中的顺序
SORT_BRIEF_DOCS        = YES
# 构造函数和析构函数列在最前面。如果设置为 NO，则构造函数将显示在
# 由SORT_BRIEF_DOCS和SORT_MEMBER_DOCS定义的相应顺序。
# 注意：如果SORT_BRIEF_DOCS设置为 NO 此选项将忽略以进行排序简报
# 成员文档。
# 注意：如果SORT_MEMBER_DOCS设置为 NO 则忽略此选项进行排序
SORT_MEMBERS_CTORS_1ST = YES
# 将 SHOW_NAMESPACES 标记设置为 NO 以禁用命名空间的生成页面。
SHOW_NAMESPACES        = NO
# 如果 USE_MDFILE_AS_MAINPAGE 标记引用 markdown 文档的名称是输入的一部分，其内容将放置在主页上
USE_MDFILE_AS_MAINPAGE = @PROJECT_SOURCE_DIR@/README.md
# 在最后生成的文档中，把所有的源代码包含在其中
SOURCE_BROWSER         = YES
# 如果EXT_LINKS_IN_WINDOW选项设置为 YES，doxygen 将打开指向通过标签文档在单独窗口中导入的外部符号。
EXT_LINKS_IN_WINDOW    = YES
# INCLUDE_PATH 标签可用于指定一个或多个目录
INCLUDE_PATH           = @PROJECT_SOURCE_DIR@/ejsonlib
# 添加外部文档
# TAGFILES               = "@PROJECT_SOURCE_DIR@/etc/cppreference-doxygen-web.tag.xml=https://en.cppreference.com/w/"
# TAGFILES              += "@PROJECT_SOURCE_DIR@/etc/linux-man-doxygen-web.tag.xml=http://man7.org/linux/man-pages/"
# TAGFILES              += "@PROJECT_SOURCE_DIR@/etc/rfc-doxygen-web.tag.xml=https://tools.ietf.org/html/"
# 那些没有使用doxygen格式描述的文档（函数或类等）就不显示了 （YES 显示， 如果EXTRACT_ALL被启用，那么这个标志其实是被忽略的。）
HIDE_UNDOC_RELATIONS   = NO
# 当 INLINE_GROUPED_CLASSES 标记设置为 YES、类、结构和联合时,显示在包含它们的组中（例如使用 \ingroup）
INLINE_GROUPED_CLASSES = YES
INLINE_SIMPLE_STRUCTS  = YES
HTML_COLORSTYLE_HUE    = 204
HTML_COLORSTYLE_SAT    = 120
HTML_COLORSTYLE_GAMMA  = 60
# HTML_EXTRA_STYLESHEET  = "@PROJECT_SOURCE_DIR@/docs/style.css"
# 是否生成 LaTex 格式文档
GENERATE_LATEX         = NO
EXAMPLE_PATH           = "@PROJECT_SOURCE_DIR@/doctests"

# 在程序文档中允许以图例形式显示函数调用关系，前提是你已经安装了 graphviz 软件包
HAVE_DOT               = @DOXYGEN_DOT_FOUND@
CLASS_GRAPH            = YES
TEMPLATE_RELATIONS     = YES
DOT_IMAGE_FORMAT       = png
INTERACTIVE_SVG        = NO
COLLABORATION_GRAPH    = NO

# 提取信息，包含类的私有数据成员和静态成员
EXTRACT_ALL            = YES
EXTRACT_PRIVATE        = YES
EXTRACT_STATIC         = YES
EXTRACT_ANON_NSPACES   = YES

# do u liek eclips
GENERATE_ECLIPSEHELP   = NO
```
### doxygen.cmake

```cmake
find_package (Doxygen)
if (DOXYGEN_FOUND)
    if (Doxygen_dot_FOUND)
        set (DOXYGEN_DOT_FOUND YES)
    else (NOT Doxygen_dot_FOUND)
        set (DOXYGEN_DOT_FOUND NO)
    endif (Doxygen_dot_FOUND)
    configure_file ("${PROJECT_SOURCE_DIR}/docs/Doxyfile.in" "${PROJECT_BINARY_DIR}/Doxyfile" @ONLY)
    add_custom_target (doc "${DOXYGEN_EXECUTABLE}" "${PROJECT_BINARY_DIR}/Doxyfile"
                           WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
                           COMMENT "Generate docs using Doxygen" VERBATIM)
endif ()
```
在更目录的 `CMakeLists.txt` 中 使用 `include(docs/doxygen.cmake)` 来引入。

在 `build` 文件夹下使用

```shell
$ cmake ..
$ make doc
```

文档生成在 `build/doc` 目录下。
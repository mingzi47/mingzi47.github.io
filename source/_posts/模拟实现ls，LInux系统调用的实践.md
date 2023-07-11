---
title: "模拟实现简单ls，Linux系统调用的实践"
date: 2023-07-11T23:45:14+08:00
categories:
  - Linux
tags:
  - c
  - Linux系统调用
  - Linux工具
index_img: /images/Linux/模拟实现ls/0.png
---

# 模拟实现简单 ls，Linux 系统调用的实践

使用 **C 语言**实现了 ls -al 的命令

![模拟实现ls](/images/Linux/模拟实现ls/0.png)

## ls -al 显示了哪些信息

![ls -al 显示的信息](/images/Linux/模拟实现ls/1.png)

显示了当前文件夹下的所有文件(包括隐藏文件)

每个文件的一下信息都会被显示:

[文件类型及文件权限] [硬连接数] [文件所属用户名] [文件所属组] [文件大小] [最后修改时间] [文件名]

要实现 ls -al 只需要完成：

- 遍历目录下的每一个文件
- 获得文件的信息

## man 的使用

man 是 linux 中用来查看文档的命令。

如果要查看系统调用 `stat` 的文档，直接使用 `man stat` 查出来的是用户命令 `stat`, 而不是系统调用 `stat`

使用 `man 2 stat` 就可以正确的查找了

`man` 的文档也是有分类的，详细可以看 `man man`

```txt
The sections of the manual are:
  1.   General Commands Manual
  2.   System Calls Manual
  3.   Library Functions Manual
  4.   Kernel Interfaces Manual
  5.   File Formats Manual
  6.   Games Manual
  7.   Miscellaneous Information Manual
  8.   System Manager's Manual
  9.   Kernel Developer's Manual
```

## 获得文件信息

使用 `stat` 来获得文件的信息。

```c
#include <sys/stat.h>

int stat(const char *restrict pathname, struct stat *restrict statbuf);
```

[man 2 stat](https://man7.org/linux/man-pages/man2/lstat.2.html)

`pathname` 要查看信息的文件名

`statbuf` 保存文件的信息

返回值为 `0` 时成功， 失败时返回 `-1`

```c
#include <sys/stat.h>

struct stat {
  dev_t      st_dev;      /* ID of device containing file */
  ino_t      st_ino;      /* Inode number */
  mode_t     st_mode;     /* File type and mode */
  nlink_t    st_nlink;    /* Number of hard links */
  uid_t      st_uid;      /* User ID of owner */
  gid_t      st_gid;      /* Group ID of owner */
  dev_t      st_rdev;     /* Device ID (if special file) */
  off_t      st_size;     /* Total size, in bytes */
  blksize_t  st_blksize;  /* Block size for filesystem I/O */
  blkcnt_t   st_blocks;   /* Number of 512 B blocks allocated */

  /* Since POSIX.1-2008, this structure supports nanosecond
    precision for the following timestamp fields.
    For the details before POSIX.1-2008, see VERSIONS. */

  struct timespec  st_atim;  /* Time of last access */
  struct timespec  st_mtim;  /* Time of last modification */
  struct timespec  st_ctim;  /* Time of last status change */

#define st_atime  st_atim.tv_sec  /* Backward compatibility */
#define st_mtine  st_mtim.tv_sec
#define st_ctime  st_ctim.tv_sec
};
```

[man 3type stat](https://man7.org/linux/man-pages/man3/stat.3type.html)

`struct stat` 记录了很多信息, 需要的信息有 `st_mode`, `st_nlink`, `st_uid`, `st_gid`, `st_size`, `st_mtime`

`st_mode` 文件类型及文件权限
`st_nlink` 硬连接数
`st_uid` 所属用户的 ID
`st_gid` 所属组的 ID
`st_size` 文件大小
`st_mtime` 最后修改时间

### 文件类型及文件权限

[详细信息](https://man7.org/linux/man-pages/man7/inode.7.html)

使用 `st_mode & S_IFMT` 可以获得文件类型

```c
S_IFSOCK   0140000   socket
S_IFLNK    0120000   symbolic link
S_IFREG    0100000   regular file
S_IFBLK    0060000   block device
S_IFDIR    0040000   directory
S_IFCHR    0020000   character device
S_IFIFO    0010000   FIFO
```

如果这个文件是普通文件，`(st_mode & S_IFMT) == S_IFREG` 为 `true`

可以使用一个 `switch` 来比较我们就得到了 [文件类型及文件权限] 的第一个字符

获得文件权限需要使用:

```c
// 所属用户权限
S_IRUSR     00400   owner has read permission
S_IWUSR     00200   owner has write permission
S_IXUSR     00100   owner has execute permission
// 所属组权限
S_IRGRP     00040   group has read permission
S_IWGRP     00020   group has write permission
S_IXGRP     00010   group has execute permission
// 其他人权限
S_IROTH     00004   others have read permission
S_IWOTH     00002   others have write permission
S_IXOTH     00001   others have execute permission
```

如果这个文件所属用户拥有读的权利 l, `st_mode & S_IRUSR` 为 `true`

完整的[文件类型及文件权限]就得到了。

### 所属用户与所属组

所属用户名可以通过 `getpwuid()` 来获得。

```c
#include <pwd.h>

struct passwd *getpwuid(uid_t uid);

struct passwd {
	char	*pw_name;		/* user name */
	char	*pw_passwd;		/* encrypted password */

	__uid_t	pw_uid;			/* user uid */
	__gid_t	pw_gid;			/* user gid */

	char	*pw_gecos;		/* Real name */
	char	*pw_dir;		/* home directory */
	char	*pw_shell;		/* default shell */
};
```

所属组可以通过 `getgrgid()` 来获得。

```c
#include <grp.h>

struct group *getgrgid(gid_t);

struct group {
	char	*gr_name;		/* group name */
	char	*gr_passwd;		/* group password */
	gid_t	gr_gid;			/* group id */
	char	**gr_mem;		/* members list */
};
```

### 最后修改时间

`st_mtime` 可以通过 `ctime()` 来转变为字符串。

### 硬连接数与文件大小

`st_nlink` 是一个 `short int` , `st_size` 是一个 `long int`, 这两个都是一个数字类型，可以直接拿来用。

## 遍历目录

遍历目录的方法是使用 C 语言的库函数 `opendir`, `readdir`, `closedir`。

### `opendir`

```c
#include <sys/types.h>
#include <dirent.h>

DIR *opendir(const char* name);
```

> The opendir() function opens a directory stream corresponding to
> the directory name, and returns a pointer to the directory
> stream. The stream is positioned at the first entry in the
> directory.

[man 3 opendir](https://man7.org/linux/man-pages/man3/opendir.3.html)

`opendir()` 函数通过参数文件夹的名字返回一个 `DIR` 的文件夹流指针, 函数执行失败会返回一个 `NULL`。

> Filename entries can be read from a directory stream using
> [readdir(3)](https://man7.org/linux/man-pages/man3/readdir.3.html).

使用 `DIR *` 获取每一个文件需要使用 `readdir()`

### `readdir`

```c
#include <dirent.h>

struct dirent *readdir(DIR *dirp);
```

> The readdir() function returns a pointer to a dirent structure
> representing the next directory entry in the directory stream
> pointed to by dirp. It returns NULL on reaching the end of the
> directory stream or if an error occurred.

[man 3 readdir](https://man7.org/linux/man-pages/man3/readdir.3.html)

`readdir()` 函数会返回一个 `struct dirent` 的指针，这个指针指向文件夹流的下一个文件, 失败返回一个 `NULL`。

```c
DIR * dir_s = opendir(".");
for(struct dirent * file_e = readdir(dir_s);
    file_e != NULL;
    file_e = readdir(dir_s)
    ) {
  ....
}

```

这样就能遍历一个目录了。

```c
struct dirent {
  ino_t          d_ino;       /* 文件的 Inode 号 */
  off_t          d_off;       /* 目录开头到这个文件的偏移量*/
  unsigned short d_reclen;    /* d_name 的长度 */
  unsigned char  d_type;      /* 文件类型 */
  char           d_name[256]; /* 文件名 */
};
```

### `closedir`

打开的文件夹流是要关闭的，使用 `closedir` 来做这件事。

```c
#include <sys/types.h>
#include <dirent.h>

int closedir(DIR *dirp);
```

> The closedir() function closes the directory stream associated
> with dirp. A successful call to closedir() also closes the
> underlying file descriptor associated with dirp. The directory
> stream descriptor dirp is not available after this call.

[man 3 closedir](https://man7.org/linux/man-pages/man3/closedir.3.html)

`closedir()` 成功时返回 `0`， 失败返回 `-1`

## 完整代码

```c
#include <dirent.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

void file_info(const char *pathname);

int main() {
  DIR *cdir = opendir(".");
  for (struct dirent *dir = readdir(cdir); dir != NULL; dir = readdir(cdir))
    file_info(dir->d_name);
  closedir(cdir);
  return 0;
}

void file_info(const char *pathname) {
  struct stat stbuf;
  if (stat(pathname, &stbuf)) {
    perror(pathname);
    exit(-1);
  }

  char perms[11] = {'\0'};

  // 文件类型
  switch (stbuf.st_mode & S_IFMT) {
  case S_IFSOCK:
    perms[0] = 's';
    break;
  case S_IFLNK:
    perms[0] = 'l';
    break;
  case S_IFDIR:
    perms[0] = 'd';
    break;
  case S_IFREG:
    perms[0] = '-';
    break;
  case S_IFBLK:
    perms[0] = 'b';
    break;
  case S_IFCHR:
    perms[0] = 'c';
    break;
  case S_IFIFO:
    perms[0] = 'p';
    break;
  default:
    perms[0] = '?';
  }

  // 访问权限
  // 文件所有者
  perms[1] = (stbuf.st_mode & S_IRUSR) ? 'r' : '-';
  perms[2] = (stbuf.st_mode & S_IWUSR) ? 'w' : '-';
  perms[3] = (stbuf.st_mode & S_IXUSR) ? 'x' : '-';
  // 文件所在组
  perms[4] = (stbuf.st_mode & S_IRGRP) ? 'r' : '-';
  perms[5] = (stbuf.st_mode & S_IWGRP) ? 'w' : '-';
  perms[6] = (stbuf.st_mode & S_IXGRP) ? 'x' : '-';
  // 其他人
  perms[7] = (stbuf.st_mode & S_IROTH) ? 'r' : '-';
  perms[8] = (stbuf.st_mode & S_IWOTH) ? 'w' : '-';
  perms[9] = (stbuf.st_mode & S_IXOTH) ? 'x' : '-';

  // 硬连接数
  int nlink = stbuf.st_nlink;

  // 用户名与组名
  char *uname = getpwuid(stbuf.st_uid)->pw_name;
  char *gname = getgrgid(stbuf.st_gid)->gr_name;

  // 文件大小
  long int fsize = stbuf.st_size;

  // 最后修改时间
  char *ttime = ctime(&stbuf.st_mtime);
  char mtime[512] = {0};

  strncpy(mtime, ttime, strlen(ttime) - 1);

  char buf[1024];
  sprintf(buf, "%s %5d %s %s %5ld %s %s", perms, nlink, uname, gname, fsize,
          mtime, pathname);
  printf("%s\n", buf);
}
```

## 其他

[man page](https://man7.org/linux/man-pages/)

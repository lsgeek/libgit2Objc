# libgit2Objc

libgit2 的 Objective-C 封装 SDK，附带可运行 Demo，已制作成 CocoaPods 组件。

底层使用 [libgit2](https://github.com/libgit2/libgit2) **v1.8.4** 预编译静态库（XCFramework 形式，HTTPS 基于 SecureTransport），支持：

| 平台 | 架构 | 部署目标 |
|------|------|----------|
| iOS 真机 | arm64 | iOS 15.0+ |
| iOS 模拟器 | arm64 / x86_64 | iOS 15.0+ |
| macOS | arm64 / x86_64 | macOS 12.0+ |

## 目录结构

```
├── libgit2Objc.podspec         # CocoaPods 组件描述文件
├── libgit2Objc/
│   └── Classes/                # SDK 源码
│       ├── LGRepository.h/.m   # 仓库：初始化/打开/克隆/提交/分支/检出/状态/历史
│       ├── LGCommit.h/.m       # 提交对象
│       ├── LGReference.h/.m    # 引用（分支/标签）
│       ├── LGTree.h/.m         # 树对象（目录快照）
│       ├── LGIndex.h/.m        # 暂存区
│       ├── LGSignature.h/.m    # 提交签名（name/email/date）
│       ├── LGStatusEntry.h/.m  # 工作区状态条目
│       ├── LGError.h/.m        # NSError 错误封装
│       └── Internal/           # 内部头文件（不对外公开）
├── External/libgit2/           # libgit2 v1.8.4 源码（构建产物在 build/ 下，已 gitignore）
├── Scripts/build_libgit2.sh    # libgit2 全平台构建脚本
├── Demo/                       # macOS 命令行 Demo（build.sh 一键编译运行）
└── Demo-iOS/                   # iOS App Demo（Podfile + 工程生成脚本）
```

## 快速开始

### 1. 作为 CocoaPods 组件使用

Podfile 中声明（本地路径方式）：

```ruby
pod 'libgit2Objc', :path => '/path/to/libgit2Objc'
```

发布到私有/公有 Specs 仓库后，即可按名字引用：

```ruby
pod 'libgit2Objc', '~> 0.1.0'
```

首次 `pod install` 时，若 `External/libgit2/build/` 下没有预编译产物，
`prepare_command` 会自动调用 `Scripts/build_libgit2.sh` 现场编译（需要 cmake）。

验证组件：

```bash
pod lib lint libgit2Objc.podspec --allow-warnings
```

### 2. 运行 macOS 命令行 Demo

```bash
./Demo/build.sh
```

演示内容：初始化仓库 → 配置用户 → 两次提交 → 创建/切换 feature 分支 → 查看状态/历史/分支 → 本地克隆 → 短 SHA 查找提交。

### 3. 运行 iOS Demo App

```bash
cd Demo-iOS
GEM_HOME=/opt/homebrew/Cellar/cocoapods/$(pod --version)/libexec \
  /opt/homebrew/opt/ruby/bin/ruby gen_project.rb   # 生成工程（如已生成可跳过）
pod install
open DemoApp.xcworkspace
```

App 内有三个按钮，依次演示：建仓库+提交、状态+历史、克隆。

## SDK 使用示例

```objc
#import <libgit2Objc/libgit2Objc.h>

[LGRepository initializeLibgit2];   // 应用启动时调用一次

// 初始化 / 打开 / 克隆
LGRepository *repo = [LGRepository initializeAtPath:path bare:NO error:&error];
LGRepository *repo = [LGRepository repositoryAtPath:path error:&error];
LGRepository *repo = [LGRepository cloneFromURL:@"https://github.com/user/repo.git"
                                         toPath:path error:&error];

// 配置与签名
[repo setConfigString:@"you" forKey:@"user.name" error:nil];
LGSignature *sig = [LGSignature signatureWithName:@"you" email:@"you@example.com" error:nil];

// 暂存 + 提交
[repo.index addFileWithPath:@"README.md" error:nil];
LGCommit *commit = [repo commitWithMessage:@"Initial commit"
                                    author:sig committer:sig error:nil];

// 分支
LGReference *branch = [repo createBranchWithName:@"feature"
                                      fromCommit:commit force:NO error:nil];
[repo checkoutReference:branch error:nil];

// 查询
NSArray<LGCommit *> *history = [repo commitsWithMaxCount:20 error:nil];
NSArray<LGStatusEntry *> *status = [repo statusWithError:nil];
NSString *branchName = repo.currentBranchName;
```

## 重新编译 libgit2

```bash
rm -rf External/libgit2/build
./Scripts/build_libgit2.sh
```

产物输出到 `External/libgit2/build/`：

- `lib/libgit2.xcframework` — macOS / iOS 真机 / iOS 模拟器三个切片
- `include/` — git2 头文件

## 许可证

- 本项目：MIT（见 LICENSE）
- libgit2：GPLv2 with Linking Exception（见 External/libgit2/COPYING），静态链接不受 GPL 传染性影响

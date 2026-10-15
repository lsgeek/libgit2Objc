#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LGIndex, LGCommit, LGReference, LGSignature, LGStatusEntry, LGRemote, LGRemoteCredentials;

/// git 仓库
@interface LGRepository : NSObject

/// 全局初始化 libgit2（线程安全，应用启动时调用一次即可）
+ (void)initializeLibgit2;

/// 打开已有仓库
+ (nullable instancetype)repositoryAtPath:(NSString *)path error:(NSError **)error;

/// 在指定路径初始化新仓库
+ (nullable instancetype)initializeAtPath:(NSString *)path
                                     bare:(BOOL)bare
                                    error:(NSError **)error;

/// 克隆仓库（支持 https://、ssh://、git@host:path 与本地路径；公开仓库/本地路径可传 nil）
+ (nullable instancetype)cloneFromURL:(NSString *)url
                               toPath:(NSString *)path
                                error:(NSError **)error;

/// 克隆仓库并携带认证配置（SSH 私钥仓库或私有 HTTPS 仓库使用）
+ (nullable instancetype)cloneFromURL:(NSString *)url
                               toPath:(NSString *)path
                          credentials:(nullable LGRemoteCredentials *)credentials
                                error:(NSError **)error;

/// .git 目录路径（bare 仓库为仓库本身）
@property (nonatomic, readonly) NSString *repositoryPath;
/// 工作目录路径（bare 仓库为 nil）
@property (nonatomic, nullable, readonly) NSString *workDirectoryPath;
/// 当前分支短名，如 "main"
@property (nonatomic, nullable, readonly) NSString *currentBranchName;

#pragma mark - 配置

- (nullable NSString *)configStringForKey:(NSString *)key error:(NSError **)error;
- (BOOL)setConfigString:(NSString *)value forKey:(NSString *)key error:(NSError **)error;

#pragma mark - 暂存与提交

@property (nonatomic, readonly) LGIndex *index;

/// 将当前暂存区内容提交到 HEAD 所在分支
- (nullable LGCommit *)commitWithMessage:(NSString *)message
                                  author:(LGSignature *)author
                               committer:(LGSignature *)committer
                                   error:(NSError **)error;

#pragma mark - 查询

/// HEAD 引用
- (nullable LGReference *)headReferenceWithError:(NSError **)error;
/// HEAD 指向的提交
- (nullable LGCommit *)headCommitWithError:(NSError **)error;
/// 指定 SHA 的提交（支持完整或短 SHA）
- (nullable LGCommit *)commitWithOID:(NSString *)oid error:(NSError **)error;
/// 从 HEAD 开始按时间倒序遍历提交（0 表示不限制数量）
- (nullable NSArray<LGCommit *> *)commitsWithMaxCount:(NSUInteger)maxCount error:(NSError **)error;
/// 所有本地与远程引用
- (nullable NSArray<LGReference *> *)allReferencesWithError:(NSError **)error;
/// 所有本地分支名
- (nullable NSArray<NSString *> *)localBranchNamesWithError:(NSError **)error;
/// 工作区与暂存区状态
- (nullable NSArray<LGStatusEntry *> *)statusWithError:(NSError **)error;
/// 远程仓库名列表
- (nullable NSArray<NSString *> *)remoteNamesWithError:(NSError **)error;

#pragma mark - 分支与检出

/// 在指定提交上创建分支
- (nullable LGReference *)createBranchWithName:(NSString *)name
                                    fromCommit:(LGCommit *)commit
                                         force:(BOOL)force
                                         error:(NSError **)error;

/// 检出分支（更新工作区与 HEAD）
- (BOOL)checkoutReference:(LGReference *)reference error:(NSError **)error;

/// 检出分支（按短名，如 "main"）
- (BOOL)checkoutBranchWithName:(NSString *)name error:(NSError **)error;

#pragma mark - 远程仓库

/// 创建远程（如 origin）并写入配置
- (nullable LGRemote *)createRemoteWithName:(NSString *)name
                                        url:(NSString *)url
                                      error:(NSError **)error;

/// 按名获取远程（如 "origin"）
- (nullable LGRemote *)remoteWithName:(NSString *)name error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

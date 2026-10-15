#import <Foundation/Foundation.h>
#import <git2.h>
#import "LGRemoteCredentials.h"

NS_ASSUME_NONNULL_BEGIN

@class LGTransferProgress;
typedef void (^LGRemoteProgressBlock)(LGTransferProgress *progress);

/// 一次远程操作的回调上下文：认证信息 + 传输进度回调
/// （供 LGRemote 与 LGRepository 的 clone 共用）
@interface LGRemoteAuthContext : NSObject

- (instancetype)initWithCredentials:(nullable LGRemoteCredentials *)credentials;

/// 快速构造：认证字段来自任意暴露了同名 KVC 键的对象（如 LGRemote）
- (instancetype)initWithCredentialSource:(id)source;

@property (nonatomic, copy, nullable) LGRemoteProgressBlock progressBlock;

@end

/// libgit2 认证回调：按服务器允许的凭证类型依次尝试
///  1. SSH 密钥文件（SSHPrivateKeyPath 已设置时）
///  2. ssh-agent（useSSHAgent = YES 时）
///  3. HTTPS 用户名密码
int LGRemoteAuthCallback(git_credential **out,
                         const char *url,
                         const char *usernameFromURL,
                         unsigned int allowedTypes,
                         void *payload);

/// fetch 传输进度回调（libgit2 工作线程触发，转发到主线程）
int LGRemoteFetchProgressCallback(const git_indexer_progress *stats, void *payload);

/// push 传输进度回调（libgit2 工作线程触发，转发到主线程）
int LGRemotePushProgressCallback(unsigned int current,
                                 unsigned int total,
                                 size_t bytes,
                                 void *payload);

NS_ASSUME_NONNULL_END

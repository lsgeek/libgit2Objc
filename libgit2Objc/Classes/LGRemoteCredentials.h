#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 远程认证配置（HTTPS 用户名密码 / SSH 密钥），用于 clone 时预配置
/// 也可通过 LGRemote 的同名属性在 fetch / push / pull 前设置
@interface LGRemoteCredentials : NSObject <NSCopying>

/// HTTPS 用户名
@property (nonatomic, copy, nullable) NSString *username;
/// HTTPS 密码或 Token
@property (nonatomic, copy, nullable) NSString *password;

/// SSH 登录用户名（默认取 URL 中的用户名，如 git@github.com 的 git）
@property (nonatomic, copy, nullable) NSString *SSHUsername;
/// SSH 私钥路径（设置后优先使用密钥文件认证）
@property (nonatomic, copy, nullable) NSString *SSHPrivateKeyPath;
/// SSH 公钥路径（默认私钥路径 + ".pub"）
@property (nonatomic, copy, nullable) NSString *SSHPublicKeyPath;
/// 私钥口令（可选）
@property (nonatomic, copy, nullable) NSString *SSHPassphrase;
/// 是否优先使用 ssh-agent（仅 macOS 有意义）
@property (nonatomic) BOOL useSSHAgent;

@end

NS_ASSUME_NONNULL_END

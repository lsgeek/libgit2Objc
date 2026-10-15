#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// SSH 密钥对（OpenSSH 格式，可被 libssh2 / OpenSSH 直接使用）
@interface LGSSHKeyPair : NSObject

/// 密钥类型标识，如 "ssh-ed25519"、"ssh-rsa"
@property (nonatomic, readonly) NSString *keyType;
/// 注释（ authorized_keys 行尾，默认 "libgit2objc"）
@property (nonatomic, readonly) NSString *comment;

/// 公钥整行（authorized_keys 格式）：
///   ssh-ed25519 AAAAC3NzaC... libgit2objc
@property (nonatomic, readonly) NSString *publicKey;

/// 私钥文本（OpenSSH 格式，含 BEGIN/END 头尾），可写入文件后供 LGRemoteCredentials.SSHPrivateKeyPath 使用
@property (nonatomic, readonly) NSString *privateKey;

/// SHA256 指纹（与 ssh-keygen -lf 输出一致的哈希部分），如 "SHA256:abc123..."
@property (nonatomic, readonly) NSString *SHA256Fingerprint;

/// 私钥写入文件（权限 0600）
- (BOOL)writePrivateKeyToFile:(NSString *)path error:(NSError **)error;

/// 公钥写入文件（权限 0644）
- (BOOL)writePublicKeyToFile:(NSString *)path error:(NSError **)error;

@end


/// App 内 SSH 密钥生成器（基于内嵌 OpenSSL）
@interface LGSSHKeyGenerator : NSObject

/// 生成 ed25519 密钥对（推荐，体积小签名快）
+ (nullable LGSSHKeyPair *)generateEd25519KeyPairWithComment:(nullable NSString *)comment
                                                       error:(NSError **)error;

/// 生成 RSA 密钥对（keySize 支持 2048 / 3072 / 4096）
+ (nullable LGSSHKeyPair *)generateRSAKeyPairWithKeySize:(NSUInteger)keySize
                                                 comment:(nullable NSString *)comment
                                                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// git 引用（分支 / 标签 / HEAD 等）
@interface LGReference : NSObject <NSCopying>

/// 完整引用名，如 "refs/heads/main"、"refs/tags/v1.0"
@property (nonatomic, readonly) NSString *name;
/// 短名，如 "main"、"v1.0"
@property (nonatomic, readonly) NSString *shorthand;
@property (nonatomic, readonly, getter=isBranch) BOOL branch;
@property (nonatomic, readonly, getter=isRemote) BOOL remote;
@property (nonatomic, readonly, getter=isTag) BOOL tag;
/// 指向的提交 SHA
@property (nonatomic, readonly) NSString *targetOID;

@end

NS_ASSUME_NONNULL_END

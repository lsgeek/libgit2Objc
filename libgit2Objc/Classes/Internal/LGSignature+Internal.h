#import "LGSignature.h"
#import <git2.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGSignature ()

/// 底层 git_signature（仅在提交等同步调用期间有效）
@property (nonatomic, readonly) const git_signature *gitSignature;

@end

NS_ASSUME_NONNULL_END

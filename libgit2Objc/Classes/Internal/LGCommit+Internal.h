#import "LGCommit.h"
#import <git2.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGCommit ()

/// 包装一个已存在的 git_commit（retain）
- (instancetype)initWithGitCommit:(git_commit *)commit NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) git_commit *gitCommit;

@end

NS_ASSUME_NONNULL_END

#import "LGIndex.h"
#import <git2.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGIndex ()

- (instancetype)initWithGitIndex:(git_index *)index NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) git_index *gitIndex;

@end

NS_ASSUME_NONNULL_END

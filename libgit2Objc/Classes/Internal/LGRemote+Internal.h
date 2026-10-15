#import "LGRemote.h"
#import <git2.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGRemote ()

- (instancetype)initWithGitRemote:(git_remote *)remote
                       repository:(git_repository *)repository NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) git_remote *gitRemote;
@property (nonatomic, readonly) git_repository *gitRepository;

@end

NS_ASSUME_NONNULL_END

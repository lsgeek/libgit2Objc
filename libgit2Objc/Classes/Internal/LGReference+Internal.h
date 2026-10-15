#import "LGReference.h"
#import <git2.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGReference ()

- (instancetype)initWithGitReference:(git_reference *)reference NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) git_reference *gitReference;

@end

NS_ASSUME_NONNULL_END

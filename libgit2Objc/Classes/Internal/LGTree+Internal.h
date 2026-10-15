#import "LGTree.h"
#import <git2.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGTreeEntry ()

- (instancetype)initWithGitTreeEntry:(const git_tree_entry *)entry NS_DESIGNATED_INITIALIZER;

@end

@interface LGTree ()

- (instancetype)initWithGitTree:(git_tree *)tree NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) git_tree *gitTree;

@end

NS_ASSUME_NONNULL_END

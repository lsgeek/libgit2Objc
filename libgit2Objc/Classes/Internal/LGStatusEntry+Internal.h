#import "LGStatusEntry.h"
#import <git2.h>

NS_ASSUME_NONNULL_BEGIN

@interface LGStatusEntry ()

- (instancetype)initWithGitStatusEntry:(const git_status_entry *)entry NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END

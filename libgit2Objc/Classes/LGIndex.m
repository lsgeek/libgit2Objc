#import "LGIndex.h"
#import "LGIndex+Internal.h"
#import "LGError.h"

@implementation LGIndex

- (instancetype)initWithGitIndex:(git_index *)index {
    self = [super init];
    if (self) {
        _gitIndex = index;
    }
    return self;
}

- (void)dealloc {
    git_index_free(_gitIndex);
}

- (NSUInteger)entryCount {
    return git_index_entrycount(_gitIndex);
}

- (BOOL)addFileWithPath:(NSString *)path error:(NSError **)error {
    int status = git_index_add_bypath(_gitIndex, path.UTF8String);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }
    return YES;
}

- (BOOL)removeFileWithPath:(NSString *)path error:(NSError **)error {
    int status = git_index_remove_bypath(_gitIndex, path.UTF8String);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }
    return YES;
}

- (BOOL)writeWithError:(NSError **)error {
    int status = git_index_write(_gitIndex);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }
    return YES;
}

@end

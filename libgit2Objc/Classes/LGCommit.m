#import "LGCommit.h"
#import "LGCommit+Internal.h"
#import "LGSignature.h"
#import "LGTree.h"
#import "LGTree+Internal.h"
#import "LGError.h"

@implementation LGCommit

- (instancetype)initWithGitCommit:(git_commit *)commit {
    self = [super init];
    if (self) {
        _gitCommit = commit;
    }
    return self;
}

- (void)dealloc {
    git_commit_free(_gitCommit);
}

- (NSString *)OID {
    char hex[GIT_OID_HEXSZ + 1] = {0};
    git_oid_tostr(hex, sizeof(hex), git_commit_id(_gitCommit));
    return [NSString stringWithUTF8String:hex];
}

- (NSString *)shortOID {
    char hex[GIT_OID_SHA1_SIZE + 1] = {0};
    git_oid_tostr(hex, sizeof(hex), git_commit_id(_gitCommit));
    return [NSString stringWithUTF8String:hex];
}

- (NSString *)message {
    const char *msg = git_commit_message(_gitCommit);
    return msg ? [NSString stringWithUTF8String:msg] : @"";
}

- (NSString *)summary {
    return [NSString stringWithUTF8String:git_commit_summary(_gitCommit)];
}

- (LGSignature *)author {
    return [[LGSignature alloc] initWithName:@(git_commit_author(_gitCommit)->name)
                                       email:@(git_commit_author(_gitCommit)->email)
                                        date:[NSDate dateWithTimeIntervalSince1970:git_commit_author(_gitCommit)->when.time]
                                       error:NULL];
}

- (LGSignature *)committer {
    return [[LGSignature alloc] initWithName:@(git_commit_committer(_gitCommit)->name)
                                       email:@(git_commit_committer(_gitCommit)->email)
                                        date:[NSDate dateWithTimeIntervalSince1970:git_commit_committer(_gitCommit)->when.time]
                                       error:NULL];
}

- (NSDate *)date {
    return [NSDate dateWithTimeIntervalSince1970:git_commit_committer(_gitCommit)->when.time];
}

- (NSArray<NSString *> *)parentOIDs {
    NSMutableArray<NSString *> *oids = [NSMutableArray array];
    NSUInteger count = git_commit_parentcount(_gitCommit);
    for (NSUInteger i = 0; i < count; i++) {
        char hex[GIT_OID_HEXSZ + 1] = {0};
        git_oid_tostr(hex, sizeof(hex), git_commit_parent_id(_gitCommit, (unsigned)i));
        [oids addObject:[NSString stringWithUTF8String:hex]];
    }
    return oids.copy;
}

- (NSUInteger)parentCount {
    return git_commit_parentcount(_gitCommit);
}

- (nullable LGTree *)treeWithError:(NSError **)error {
    git_tree *tree = NULL;
    int status = git_commit_tree(&tree, _gitCommit);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[LGTree alloc] initWithGitTree:tree];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@ %@>", NSStringFromClass(self.class), self.shortOID, self.summary];
}

@end

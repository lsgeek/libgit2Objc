#import "LGStatusEntry.h"
#import "LGStatusEntry+Internal.h"

@implementation LGStatusEntry {
    NSString *_path;
    git_status_t _status;
}

- (instancetype)initWithGitStatusEntry:(const git_status_entry *)entry {
    self = [super init];
    if (self) {
        const char *headPath = entry->head_to_index ? entry->head_to_index->new_file.path
                                                    : (entry->index_to_workdir ? entry->index_to_workdir->new_file.path : NULL);
        _path = headPath ? [NSString stringWithUTF8String:headPath] : @"";
        _status = entry->status;
    }
    return self;
}

- (NSString *)path {
    return _path;
}

- (NSString *)indexStatus {
    if (_status & GIT_STATUS_INDEX_NEW) return @"A";
    if (_status & GIT_STATUS_INDEX_MODIFIED) return @"M";
    if (_status & GIT_STATUS_INDEX_DELETED) return @"D";
    if (_status & GIT_STATUS_INDEX_RENAMED) return @"R";
    if (_status & GIT_STATUS_INDEX_TYPECHANGE) return @"T";
    return @" ";
}

- (NSString *)workdirStatus {
    if (_status & GIT_STATUS_WT_NEW) return @"A";
    if (_status & GIT_STATUS_WT_MODIFIED) return @"M";
    if (_status & GIT_STATUS_WT_DELETED) return @"D";
    if (_status & GIT_STATUS_WT_RENAMED) return @"R";
    if (_status & GIT_STATUS_WT_TYPECHANGE) return @"T";
    return @" ";
}

- (BOOL)isUntracked {
    return (_status & GIT_STATUS_WT_NEW) && !(_status & GIT_STATUS_INDEX_NEW);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@%@ %@>", NSStringFromClass(self.class),
            self.path, self.indexStatus, self.workdirStatus];
}

@end

#import "LGTree.h"
#import "LGTree+Internal.h"

#pragma mark - LGTreeEntry

@implementation LGTreeEntry {
    NSString *_name;
    NSString *_oid;
    NSUInteger _filemode;
}

- (instancetype)initWithGitTreeEntry:(const git_tree_entry *)entry {
    self = [super init];
    if (self) {
        _name = [NSString stringWithUTF8String:git_tree_entry_name(entry)];
        char hex[GIT_OID_HEXSZ + 1] = {0};
        git_oid_tostr(hex, sizeof(hex), git_tree_entry_id(entry));
        _oid = [NSString stringWithUTF8String:hex];
        _filemode = git_tree_entry_filemode(entry);
    }
    return self;
}

- (BOOL)isDirectory {
    return _filemode == GIT_FILEMODE_TREE;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@ %@>", NSStringFromClass(self.class),
            self.isDirectory ? @"tree" : @"blob", self.name];
}

@end

#pragma mark - LGTree

@implementation LGTree

- (instancetype)initWithGitTree:(git_tree *)tree {
    self = [super init];
    if (self) {
        _gitTree = tree;
    }
    return self;
}

- (void)dealloc {
    git_tree_free(_gitTree);
}

- (NSArray<LGTreeEntry *> *)entries {
    size_t count = git_tree_entrycount(_gitTree);
    NSMutableArray<LGTreeEntry *> *result = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; i++) {
        [result addObject:[[LGTreeEntry alloc] initWithGitTreeEntry:git_tree_entry_byindex(_gitTree, i)]];
    }
    return result.copy;
}

- (NSArray<NSString *> *)allFilePaths {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    [self collectPaths:paths prefix:@""];
    return paths.copy;
}

- (void)collectPaths:(NSMutableArray<NSString *> *)paths prefix:(NSString *)prefix {
    for (LGTreeEntry *entry in self.entries) {
        NSString *path = prefix.length > 0 ? [prefix stringByAppendingPathComponent:entry.name] : entry.name;
        if (entry.isDirectory) {
            // 子目录需要递归，这里通过 tree oid 查找子树
            git_tree *subtree = NULL;
            git_oid oid;
            git_oid_fromstr(&oid, entry.OID.UTF8String);
            if (git_tree_lookup(&subtree, git_tree_owner(_gitTree), &oid) == GIT_OK) {
                LGTree *sub = [[LGTree alloc] initWithGitTree:subtree];
                [sub collectPaths:paths prefix:path];
            }
        } else {
            [paths addObject:path];
        }
    }
}

@end

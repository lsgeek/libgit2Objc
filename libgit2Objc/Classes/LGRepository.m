#import "LGRepository.h"
#import "LGIndex.h"
#import "LGIndex+Internal.h"
#import "LGCommit.h"
#import "LGCommit+Internal.h"
#import "LGReference.h"
#import "LGReference+Internal.h"
#import "LGSignature.h"
#import "LGSignature+Internal.h"
#import "LGStatusEntry.h"
#import "LGStatusEntry+Internal.h"
#import "LGRemote.h"
#import "LGRemote+Internal.h"
#import "LGError.h"
#import <git2.h>

@implementation LGRepository {
    git_repository *_repository;
}

+ (void)initializeLibgit2 {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        git_libgit2_init();
    });
}

- (nullable instancetype)initWithGitRepository:(git_repository *)repository {
    self = [super init];
    if (self) {
        _repository = repository;
    }
    return self;
}

- (void)dealloc {
    git_repository_free(_repository);
}

+ (nullable instancetype)repositoryAtPath:(NSString *)path error:(NSError **)error {
    [self initializeLibgit2];
    git_repository *repo = NULL;
    int status = git_repository_open(&repo, path.UTF8String);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[self alloc] initWithGitRepository:repo];
}

+ (nullable instancetype)initializeAtPath:(NSString *)path
                                     bare:(BOOL)bare
                                    error:(NSError **)error {
    [self initializeLibgit2];
    git_repository *repo = NULL;
    int status = git_repository_init(&repo, path.UTF8String, bare ? 1 : 0);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[self alloc] initWithGitRepository:repo];
}

+ (nullable instancetype)cloneFromURL:(NSString *)url
                               toPath:(NSString *)path
                                error:(NSError **)error {
    [self initializeLibgit2];
    git_clone_options options = GIT_CLONE_OPTIONS_INIT;
    git_repository *repo = NULL;
    int status = git_clone(&repo, url.UTF8String, path.UTF8String, &options);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[self alloc] initWithGitRepository:repo];
}

- (NSString *)repositoryPath {
    return [NSString stringWithUTF8String:git_repository_path(_repository)];
}

- (nullable NSString *)workDirectoryPath {
    const char *path = git_repository_workdir(_repository);
    return path ? [NSString stringWithUTF8String:path] : nil;
}

- (nullable NSString *)currentBranchName {
    git_reference *head = NULL;
    if (git_repository_head(&head, _repository) != GIT_OK) return nil;
    const char *branch = git_reference_shorthand(head);
    NSString *name = branch ? [NSString stringWithUTF8String:branch] : nil;
    git_reference_free(head);
    return name;
}

#pragma mark - 配置

- (nullable NSString *)configStringForKey:(NSString *)key error:(NSError **)error {
    git_config *config = NULL;
    int status = git_repository_config(&config, _repository);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    git_buf buf = GIT_BUF_INIT;
    status = git_config_get_string_buf(&buf, config, key.UTF8String);
    git_config_free(config);
    if (status != GIT_OK) {
        git_buf_dispose(&buf);
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    NSString *value = [NSString stringWithUTF8String:buf.ptr];
    git_buf_dispose(&buf);
    return value;
}

- (BOOL)setConfigString:(NSString *)value forKey:(NSString *)key error:(NSError **)error {
    git_config *config = NULL;
    int status = git_repository_config(&config, _repository);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }
    status = git_config_set_string(config, key.UTF8String, value.UTF8String);
    git_config_free(config);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }
    return YES;
}

#pragma mark - 暂存与提交

- (LGIndex *)index {
    git_index *index = NULL;
    if (git_repository_index(&index, _repository) != GIT_OK) return nil;
    return [[LGIndex alloc] initWithGitIndex:index];
}

- (nullable LGCommit *)commitWithMessage:(NSString *)message
                                  author:(LGSignature *)author
                               committer:(LGSignature *)committer
                                   error:(NSError **)error {
    // 1. 写暂存区
    LGIndex *index = self.index;
    if (![index writeWithError:error]) return nil;

    // 2. 由暂存区生成 tree
    git_oid treeOID;
    int status = git_index_write_tree(&treeOID, index.gitIndex);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    git_tree *tree = NULL;
    status = git_tree_lookup(&tree, _repository, &treeOID);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }

    // 3. 组装父提交
    git_commit *parents[1] = {NULL};
    size_t parentCount = 0;
    git_reference *head = NULL;
    if (git_repository_head(&head, _repository) == GIT_OK) {
        const git_oid *headOID = git_reference_target(head);
        if (headOID && git_commit_lookup(&parents[0], _repository, headOID) == GIT_OK) {
            parentCount = 1;
        }
        git_reference_free(head);
    }

    // 4. 创建提交
    git_oid commitOID;
    status = git_commit_create(&commitOID,
                               _repository,
                               "HEAD",
                               author.gitSignature,
                               committer.gitSignature,
                               NULL,
                               message.UTF8String,
                               tree,
                               parentCount,
                               (const git_commit **)parents);
    git_tree_free(tree);
    if (parents[0]) git_commit_free(parents[0]);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }

    git_commit *commit = NULL;
    if (git_commit_lookup(&commit, _repository, &commitOID) != GIT_OK) return nil;
    return [[LGCommit alloc] initWithGitCommit:commit];
}

#pragma mark - 查询

- (nullable LGReference *)headReferenceWithError:(NSError **)error {
    git_reference *head = NULL;
    int status = git_repository_head(&head, _repository);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[LGReference alloc] initWithGitReference:head];
}

- (nullable LGCommit *)headCommitWithError:(NSError **)error {
    git_reference *head = NULL;
    int status = git_repository_head(&head, _repository);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    const git_oid *oid = git_reference_target(head);
    git_commit *commit = NULL;
    status = oid ? git_commit_lookup(&commit, _repository, oid) : GIT_EINVALIDSPEC;
    git_reference_free(head);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[LGCommit alloc] initWithGitCommit:commit];
}

- (nullable LGCommit *)commitWithOID:(NSString *)oid error:(NSError **)error {
    git_oid fullOID;
    int status = git_oid_fromstr(&fullOID, oid.UTF8String);
    if (status != GIT_OK) {
        // 短 SHA：先按前缀解析，再在 ODB 中定位完整对象
        git_oid prefixOID;
        if (git_oid_fromstrp(&prefixOID, oid.UTF8String) != GIT_OK) {
            if (error) *error = [NSError lg_errorWithGitCode:status];
            return nil;
        }
        git_odb *odb = NULL;
        if (git_repository_odb(&odb, _repository) != GIT_OK) {
            if (error) *error = [NSError lg_errorWithGitCode:status];
            return nil;
        }
        git_odb_object *odbObject = NULL;
        status = git_odb_read_prefix(&odbObject, odb, &prefixOID, oid.length);
        git_odb_free(odb);
        if (status != GIT_OK) {
            if (error) *error = [NSError lg_errorWithGitCode:status];
            return nil;
        }
        git_oid_cpy(&fullOID, git_odb_object_id(odbObject));
        git_odb_object_free(odbObject);
    }
    git_commit *commit = NULL;
    status = git_commit_lookup(&commit, _repository, &fullOID);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[LGCommit alloc] initWithGitCommit:commit];
}

- (nullable NSArray<LGCommit *> *)commitsWithMaxCount:(NSUInteger)maxCount error:(NSError **)error {
    git_commit *head = NULL;
    {
        git_reference *headRef = NULL;
        int status = git_repository_head(&headRef, _repository);
        if (status == GIT_OK) {
            const git_oid *oid = git_reference_target(headRef);
            status = oid ? git_commit_lookup(&head, _repository, oid) : GIT_EINVALIDSPEC;
            git_reference_free(headRef);
        }
        if (status != GIT_OK) {
            if (error) *error = [NSError lg_errorWithGitCode:status];
            return nil;
        }
    }

    git_revwalk *walker = NULL;
    int status = git_revwalk_new(&walker, _repository);
    if (status != GIT_OK) {
        git_commit_free(head);
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    git_revwalk_sorting(walker, GIT_SORT_TIME);
    git_revwalk_push(walker, git_commit_id(head));
    git_commit_free(head);

    NSMutableArray<LGCommit *> *commits = [NSMutableArray array];
    git_oid oid;
    while (git_revwalk_next(&oid, walker) == GIT_OK) {
        git_commit *raw = NULL;
        if (git_commit_lookup(&raw, _repository, &oid) == GIT_OK) {
            [commits addObject:[[LGCommit alloc] initWithGitCommit:raw]];
        }
        if (maxCount > 0 && commits.count >= maxCount) break;
    }
    git_revwalk_free(walker);
    return commits.copy;
}

- (nullable NSArray<LGReference *> *)allReferencesWithError:(NSError **)error {
    git_strarray refs = {0};
    int status = git_reference_list(&refs, _repository);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    NSMutableArray<LGReference *> *result = [NSMutableArray arrayWithCapacity:refs.count];
    for (size_t i = 0; i < refs.count; i++) {
        git_reference *ref = NULL;
        if (git_reference_lookup(&ref, _repository, refs.strings[i]) == GIT_OK) {
            [result addObject:[[LGReference alloc] initWithGitReference:ref]];
        }
    }
    git_strarray_free(&refs);
    return result.copy;
}

- (nullable NSArray<NSString *> *)localBranchNamesWithError:(NSError **)error {
    git_branch_iterator *iterator = NULL;
    int status = git_branch_iterator_new(&iterator, _repository, GIT_BRANCH_LOCAL);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    git_reference *ref = NULL;
    git_branch_t type;
    while (git_branch_next(&ref, &type, iterator) == GIT_OK) {
        [names addObject:[NSString stringWithUTF8String:git_reference_shorthand(ref)]];
        git_reference_free(ref);
        ref = NULL;
    }
    git_branch_iterator_free(iterator);
    return names.copy;
}

- (nullable NSArray<LGStatusEntry *> *)statusWithError:(NSError **)error {
    git_status_list *list = NULL;
    git_status_options options = GIT_STATUS_OPTIONS_INIT;
    options.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR;
    options.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED | GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX;
    int status = git_status_list_new(&list, _repository, &options);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }

    size_t count = git_status_list_entrycount(list);
    NSMutableArray<LGStatusEntry *> *entries = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; i++) {
        const git_status_entry *entry = git_status_byindex(list, i);
        [entries addObject:[[LGStatusEntry alloc] initWithGitStatusEntry:entry]];
    }
    git_status_list_free(list);
    return entries.copy;
}

- (nullable NSArray<NSString *> *)remoteNamesWithError:(NSError **)error {
    git_strarray names = {0};
    int status = git_remote_list(&names, _repository);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithCapacity:names.count];
    for (size_t i = 0; i < names.count; i++) {
        [result addObject:[NSString stringWithUTF8String:names.strings[i]]];
    }
    git_strarray_free(&names);
    return result.copy;
}

#pragma mark - 分支与检出

- (nullable LGReference *)createBranchWithName:(NSString *)name
                                    fromCommit:(LGCommit *)commit
                                         force:(BOOL)force
                                         error:(NSError **)error {
    git_reference *branch = NULL;
    int status = git_branch_create(&branch,
                                   _repository,
                                   name.UTF8String,
                                   commit.gitCommit,
                                   force ? 1 : 0);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[LGReference alloc] initWithGitReference:branch];
}

- (BOOL)checkoutReference:(LGReference *)reference error:(NSError **)error {
    // 检出：先更新工作区，再移动 HEAD
    git_checkout_options options = GIT_CHECKOUT_OPTIONS_INIT;
    options.checkout_strategy = GIT_CHECKOUT_FORCE;

    // 解析引用目标对象为 commit
    git_object *target = NULL;
    const git_oid *oid = git_reference_target(reference.gitReference);
    int status;
    if (oid) {
        status = git_object_lookup(&target, _repository, oid, GIT_OBJECT_COMMIT);
    } else {
        status = git_revparse_single(&target, _repository, reference.name.UTF8String);
    }
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }

    status = git_checkout_tree(_repository, target, &options);
    git_object_free(target);
    if (status == GIT_OK) {
        if (reference.isBranch || reference.isRemote) {
            status = git_repository_set_head(_repository, reference.name.UTF8String);
        } else {
            status = git_repository_set_head_detached(_repository,
                                                      git_reference_target(reference.gitReference));
        }
    }

    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }
    return YES;
}

- (BOOL)checkoutBranchWithName:(NSString *)name error:(NSError **)error {
    git_reference *branch = NULL;
    int status = git_branch_lookup(&branch, _repository, name.UTF8String, GIT_BRANCH_LOCAL);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return NO;
    }
    LGReference *reference = [[LGReference alloc] initWithGitReference:branch];
    return [self checkoutReference:reference error:error];
}

#pragma mark - 远程仓库

- (nullable LGRemote *)createRemoteWithName:(NSString *)name
                                        url:(NSString *)url
                                      error:(NSError **)error {
    git_remote *remote = NULL;
    int status = git_remote_create(&remote, _repository, name.UTF8String, url.UTF8String);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[LGRemote alloc] initWithGitRemote:remote repository:_repository];
}

- (nullable LGRemote *)remoteWithName:(NSString *)name error:(NSError **)error {
    git_remote *remote = NULL;
    int status = git_remote_lookup(&remote, _repository, name.UTF8String);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return [[LGRemote alloc] initWithGitRemote:remote repository:_repository];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass(self.class), self.workDirectoryPath ?: self.repositoryPath];
}

@end

#import "LGRemote.h"
#import "LGRemote+Internal.h"
#import "LGTransferProgress.h"
#import "LGTransferProgress+Internal.h"
#import "LGError.h"

/// 回调上下文：承载一次操作的认证信息与进度回调（同步接口传入 LGRemote 本身）
@interface LGRemoteCallbacksContext : NSObject
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, copy, nullable) NSString *password;
@property (nonatomic, copy, nullable) LGRemoteProgressBlock progressBlock;
@end

@implementation LGRemoteCallbacksContext
@end

/// 认证回调：payload 为 LGRemote 或 LGRemoteCallbacksContext（均通过 KVC 取 username/password）
static int LGAuthCallback(git_credential **out,
                          const char *url,
                          const char *usernameFromURL,
                          unsigned int allowedTypes,
                          void *payload) {
    id context = (__bridge id)payload;
    NSString *username = [context valueForKey:@"username"];
    NSString *password = [context valueForKey:@"password"];
    if (username.length > 0) {
        const char *user = usernameFromURL ? usernameFromURL : username.UTF8String;
        return git_credential_userpass_plaintext_new(out, user, password.UTF8String ?: "");
    }
    return GIT_PASSTHROUGH;
}

/// fetch 进度回调（libgit2 工作线程触发，转发到主线程）
static int LGFetchProgressCallback(const git_indexer_progress *stats, void *payload) {
    LGRemoteCallbacksContext *context = (__bridge LGRemoteCallbacksContext *)payload;
    if (context.progressBlock) {
        LGTransferProgress *progress = [[LGTransferProgress alloc]
            initWithTotalObjects:stats->total_objects
            transferredObjects:stats->received_objects
            indexedObjects:stats->indexed_objects
            transferredBytes:stats->received_bytes
            isPush:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            context.progressBlock(progress);
        });
    }
    return 0;
}

/// push 进度回调（libgit2 工作线程触发，转发到主线程）
static int LGPushProgressCallback(unsigned int current,
                                  unsigned int total,
                                  size_t bytes,
                                  void *payload) {
    LGRemoteCallbacksContext *context = (__bridge LGRemoteCallbacksContext *)payload;
    if (context.progressBlock) {
        LGTransferProgress *progress = [[LGTransferProgress alloc]
            initWithTotalObjects:total
            transferredObjects:current
            indexedObjects:0
            transferredBytes:bytes
            isPush:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            context.progressBlock(progress);
        });
    }
    return 0;
}

@implementation LGRemote

- (instancetype)initWithGitRemote:(git_remote *)remote
                       repository:(git_repository *)repository {
    self = [super init];
    if (self) {
        _gitRemote = remote;
        _gitRepository = repository;
    }
    return self;
}

- (void)dealloc {
    git_remote_free(_gitRemote);
}

- (NSString *)name {
    return [NSString stringWithUTF8String:git_remote_name(_gitRemote)];
}

- (NSString *)URLString {
    const char *url = git_remote_url(_gitRemote);
    return url ? [NSString stringWithUTF8String:url] : @"";
}

#pragma mark - 基础

/// 当前分支短名（HEAD detached 时返回 nil）
- (nullable NSString *)currentBranchName {
    git_reference *head = NULL;
    if (git_repository_head(&head, _gitRepository) != GIT_OK) return nil;
    const char *name = git_reference_shorthand(head);
    BOOL isBranch = git_reference_is_branch(head) == 1;
    NSString *result = (name && isBranch) ? [NSString stringWithUTF8String:name] : nil;
    git_reference_free(head);
    return result;
}

#pragma mark - 核心实现（同步/异步共用）

/// 同步上下文的凭证取自 LGRemote 当前配置
- (LGRemoteCallbacksContext *)syncContext {
    LGRemoteCallbacksContext *context = [[LGRemoteCallbacksContext alloc] init];
    context.username = self.username;
    context.password = self.password;
    return context;
}

/// 核心 fetch，返回 git 状态码
- (int)performFetchWithContext:(LGRemoteCallbacksContext *)context error:(NSError **)error {
    git_fetch_options options = GIT_FETCH_OPTIONS_INIT;
    options.callbacks.credentials = LGAuthCallback;
    options.callbacks.transfer_progress = LGFetchProgressCallback;
    options.callbacks.payload = (__bridge void *)context;
    int status = git_remote_fetch(_gitRemote, NULL, &options, NULL);
    if (status != GIT_OK && error) *error = [NSError lg_errorWithGitCode:status];
    return status;
}

/// 核心 push，返回 git 状态码
- (int)performPushCurrentBranchWithContext:(LGRemoteCallbacksContext *)context error:(NSError **)error {
    NSString *branch = [self currentBranchName];
    if (!branch) {
        if (error) *error = [NSError errorWithDomain:LGGitErrorDomain
                                                code:GIT_EINVALIDSPEC
                                            userInfo:@{NSLocalizedDescriptionKey: @"HEAD 处于分离状态，无法确定要推送的分支"}];
        return GIT_EINVALIDSPEC;
    }

    NSString *spec = [NSString stringWithFormat:@"refs/heads/%@:refs/heads/%@", branch, branch];
    const char *refspecs[] = { spec.UTF8String };
    git_strarray specs = { (char **)refspecs, 1 };

    git_push_options options = GIT_PUSH_OPTIONS_INIT;
    options.callbacks.credentials = LGAuthCallback;
    options.callbacks.push_transfer_progress = LGPushProgressCallback;
    options.callbacks.payload = (__bridge void *)context;
    int status = git_remote_push(_gitRemote, &specs, &options);
    if (status != GIT_OK && error) *error = [NSError lg_errorWithGitCode:status];
    return status;
}

/// 核心 pull（fetch + 合并），返回 git 状态码
- (int)performPullWithContext:(LGRemoteCallbacksContext *)context error:(NSError **)error {
    // 1. fetch
    int status = [self performFetchWithContext:context error:error];
    if (status != GIT_OK) return status;

    // 2. 解析 FETCH_HEAD
    git_object *fetchHead = NULL;
    status = git_revparse_single(&fetchHead, _gitRepository, "FETCH_HEAD");
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }
    git_annotated_commit *theirCommit = NULL;
    status = git_annotated_commit_lookup(&theirCommit, _gitRepository, git_object_id(fetchHead));
    git_object_free(fetchHead);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }

    // 3. 合并分析
    git_merge_analysis_t analysis;
    git_merge_preference_t preference;
    status = git_merge_analysis(&analysis, &preference, _gitRepository, &theirCommit, 1);
    if (status != GIT_OK) {
        git_annotated_commit_free(theirCommit);
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }

    if (analysis & GIT_MERGE_ANALYSIS_UP_TO_DATE) {
        git_annotated_commit_free(theirCommit);
        return GIT_OK;
    }

    if (analysis & GIT_MERGE_ANALYSIS_FASTFORWARD) {
        // fast-forward：移动当前分支引用并更新工作区
        status = [self fastForwardToCommit:theirCommit error:error];
        git_annotated_commit_free(theirCommit);
        return status;
    }

    // 4. 真实合并
    status = [self mergeCommit:theirCommit error:error];
    git_annotated_commit_free(theirCommit);
    return status;
}

#pragma mark - 同步接口

- (BOOL)fetchWithError:(NSError **)error {
    return [self performFetchWithContext:[self syncContext] error:error] == GIT_OK;
}

- (BOOL)pushCurrentBranchWithError:(NSError **)error {
    return [self performPushCurrentBranchWithContext:[self syncContext] error:error] == GIT_OK;
}

- (BOOL)pullWithError:(NSError **)error {
    return [self performPullWithContext:[self syncContext] error:error] == GIT_OK;
}

#pragma mark - 异步接口

/// 异步执行模板：后台队列跑核心实现，进度与完成回调在主线程
- (void)performOperation:(int (^)(LGRemoteCallbacksContext *context, NSError **error))operation
                progress:(nullable LGRemoteProgressBlock)progress
              completion:(LGRemoteCompletionBlock)completion {
    LGRemoteCallbacksContext *context = [[LGRemoteCallbacksContext alloc] init];
    context.username = self.username;
    context.password = self.password;
    context.progressBlock = progress;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // block 内强引用 self，保证操作期间 remote 不被释放
        NSError *error = nil;
        int status = operation(context, &error);
        BOOL success = status == GIT_OK;
        if (!success && !error) error = [NSError lg_errorWithGitCode:status];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    });
}

- (void)fetchWithProgress:(LGRemoteProgressBlock)progress
               completion:(LGRemoteCompletionBlock)completion {
    [self performOperation:^int(LGRemoteCallbacksContext *context, NSError **error) {
        return [self performFetchWithContext:context error:error];
    } progress:progress completion:completion];
}

- (void)pushCurrentBranchWithProgress:(LGRemoteProgressBlock)progress
                           completion:(LGRemoteCompletionBlock)completion {
    [self performOperation:^int(LGRemoteCallbacksContext *context, NSError **error) {
        return [self performPushCurrentBranchWithContext:context error:error];
    } progress:progress completion:completion];
}

- (void)pullWithProgress:(LGRemoteProgressBlock)progress
              completion:(LGRemoteCompletionBlock)completion {
    [self performOperation:^int(LGRemoteCallbacksContext *context, NSError **error) {
        return [self performPullWithContext:context error:error];
    } progress:progress completion:completion];
}

#pragma mark - 合并实现

/// fast-forward 到指定提交，返回 git 状态码
- (int)fastForwardToCommit:(git_annotated_commit *)theirCommit error:(NSError **)error {
    git_object *target = NULL;
    int status = git_object_lookup(&target, _gitRepository, git_annotated_commit_id(theirCommit), GIT_OBJECT_COMMIT);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }

    git_checkout_options checkoutOpts = GIT_CHECKOUT_OPTIONS_INIT;
    checkoutOpts.checkout_strategy = GIT_CHECKOUT_FORCE;
    status = git_checkout_tree(_gitRepository, target, &checkoutOpts);
    git_object_free(target);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }

    git_reference *head = NULL;
    status = git_repository_head(&head, _gitRepository);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }
    git_reference *newHead = NULL;
    status = git_reference_set_target(&newHead, head, git_annotated_commit_id(theirCommit), "pull: fast-forward");
    git_reference_free(newHead);
    git_reference_free(head);
    if (status != GIT_OK && error) *error = [NSError lg_errorWithGitCode:status];
    return status;
}

/// 自动合并：无冲突则创建 merge commit，有冲突则报错并保留冲突现场
- (int)mergeCommit:(git_annotated_commit *)theirCommit error:(NSError **)error {
    git_merge_options mergeOpts = GIT_MERGE_OPTIONS_INIT;
    git_checkout_options checkoutOpts = GIT_CHECKOUT_OPTIONS_INIT;
    checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE;

    int status = git_merge(_gitRepository, &theirCommit, 1, &mergeOpts, &checkoutOpts);
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }

    // 检查冲突（保留 MERGE_HEAD 现场，不 cleanup）
    git_index *index = NULL;
    status = git_repository_index(&index, _gitRepository);
    if (status != GIT_OK) {
        git_repository_state_cleanup(_gitRepository);
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }
    if (git_index_has_conflicts(index)) {
        git_index_free(index);
        if (error) *error = [NSError errorWithDomain:LGGitErrorDomain
                                                code:GIT_EMERGECONFLICT
                                            userInfo:@{NSLocalizedDescriptionKey: @"合并存在冲突，请解决后手动提交"}];
        return GIT_EMERGECONFLICT;
    }

    // 由合并后的暂存区生成 tree
    git_oid treeOID;
    status = git_index_write_tree(&treeOID, index);
    git_index_free(index);
    if (status != GIT_OK) {
        git_repository_state_cleanup(_gitRepository);
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return status;
    }

    git_tree *tree = NULL;
    git_signature *sig = NULL;
    git_commit *parentHead = NULL;
    git_commit *parentTheir = NULL;

    do {
        status = git_tree_lookup(&tree, _gitRepository, &treeOID);
        if (status != GIT_OK) break;

        // 双亲提交：HEAD + FETCH_HEAD
        git_reference *head = NULL;
        if (git_repository_head(&head, _gitRepository) == GIT_OK) {
            git_commit_lookup(&parentHead, _gitRepository, git_reference_target(head));
            git_reference_free(head);
        }
        git_commit_lookup(&parentTheir, _gitRepository, git_annotated_commit_id(theirCommit));

        // 提交身份取仓库配置
        status = git_signature_default(&sig, _gitRepository);
        if (status != GIT_OK || !sig) {
            if (error) *error = [NSError errorWithDomain:LGGitErrorDomain
                                                    code:status
                                                userInfo:@{NSLocalizedDescriptionKey: @"合并提交需要配置 user.name 和 user.email"}];
            break;
        }

        NSString *message = [NSString stringWithFormat:@"Merge branch '%@' of %@", self.name, self.URLString];
        const git_commit *parents[2] = {parentHead, parentTheir};
        git_oid mergeOID;
        status = git_commit_create(&mergeOID, _gitRepository, "HEAD", sig, sig, NULL,
                                   message.UTF8String, tree, 2, parents);
    } while (0);

    if (sig) git_signature_free(sig);
    if (tree) git_tree_free(tree);
    if (parentHead) git_commit_free(parentHead);
    if (parentTheir) git_commit_free(parentTheir);

    git_repository_state_cleanup(_gitRepository);
    if (status != GIT_OK && error) *error = [NSError lg_errorWithGitCode:status];
    return status;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@ %@>", NSStringFromClass(self.class), self.name, self.URLString];
}

@end

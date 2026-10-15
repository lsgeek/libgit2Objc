#import <Foundation/Foundation.h>
#import "libgit2Objc.h"

#define LGAssert(condition, desc...) do { \
    if (!(condition)) { \
        NSLog(@"❌ [失败] %@", ##desc); \
        exit(1); \
    } \
} while (0)

static void writeFile(NSString *path, NSString *content) {
    LGAssert([content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil],
             [NSString stringWithFormat:@"写入文件失败: %@", path]);
}

static void section(NSString *title) {
    printf("\n========== %s ==========\n", title.UTF8String);
    fflush(stdout); // 与 NSLog（stderr）交错输出时保持顺序
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [LGRepository initializeLibgit2];

        NSString *baseDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"libgit2ObjcDemo"];
        [[NSFileManager defaultManager] removeItemAtPath:baseDir error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:baseDir withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *repoPath = [baseDir stringByAppendingPathComponent:@"demo-repo"];
        NSError *error = nil;

        // ---------- 1. 初始化仓库 ----------
        section(@"初始化仓库");
        LGRepository *repo = [LGRepository initializeAtPath:repoPath bare:NO error:&error];
        LGAssert(repo, [NSString stringWithFormat:@"初始化仓库失败: %@", error]);
        NSLog(@"仓库路径: %@", repo.repositoryPath);
        NSLog(@"工作目录: %@", repo.workDirectoryPath);

        // ---------- 2. 配置用户信息 ----------
        section(@"配置用户信息");
        LGAssert([repo setConfigString:@"libgit2Objc Demo" forKey:@"user.name" error:&error], error.description);
        LGAssert([repo setConfigString:@"demo@example.com" forKey:@"user.email" error:&error], error.description);
        NSLog(@"user.name = %@", [repo configStringForKey:@"user.name" error:nil]);

        LGSignature *sig = [LGSignature signatureWithName:@"libgit2Objc Demo"
                                                    email:@"demo@example.com"
                                                    error:&error];
        LGAssert(sig, error.description);

        // ---------- 3. 第一次提交 ----------
        section(@"创建并提交 README.md");
        writeFile([repoPath stringByAppendingPathComponent:@"README.md"],
                  @"# libgit2Objc Demo\n\n第一个提交。\n");
        LGAssert([repo.index addFileWithPath:@"README.md" error:&error], error.description);
        LGCommit *commit1 = [repo commitWithMessage:@"Initial commit" author:sig committer:sig error:&error];
        LGAssert(commit1, error.description);
        NSLog(@"提交1: %@ %@", commit1.shortOID, commit1.summary);

        // libgit2 默认初始分支为 master，以实际分支名为准
        NSString *mainBranch = repo.currentBranchName;
        NSLog(@"主分支名: %@", mainBranch);

        // ---------- 4. 第二次提交 ----------
        section(@"修改文件并第二次提交");
        writeFile([repoPath stringByAppendingPathComponent:@"hello.txt"], @"Hello, libgit2Objc!\n");
        LGAssert([repo.index addFileWithPath:@"hello.txt" error:&error], error.description);
        LGCommit *commit2 = [repo commitWithMessage:@"Add hello.txt" author:sig committer:sig error:&error];
        LGAssert(commit2, error.description);
        NSLog(@"提交2: %@ %@ (父提交: %@)", commit2.shortOID, commit2.summary, commit2.parentOIDs.firstObject);

        // ---------- 5. 创建并切换分支 ----------
        section(@"创建 feature 分支并提交");
        LGReference *feature = [repo createBranchWithName:@"feature" fromCommit:commit2 force:NO error:&error];
        LGAssert(feature, error.description);
        LGAssert([repo checkoutReference:feature error:&error], error.description);
        NSLog(@"当前分支: %@", repo.currentBranchName);

        writeFile([repoPath stringByAppendingPathComponent:@"feature.m"], @"// feature 分支的代码\n");
        LGAssert([repo.index addFileWithPath:@"feature.m" error:&error], error.description);
        LGCommit *commit3 = [repo commitWithMessage:@"Add feature.m" author:sig committer:sig error:&error];
        LGAssert(commit3, error.description);
        NSLog(@"提交3: %@ %@", commit3.shortOID, commit3.summary);

        // ---------- 6. 切回 main，查看状态 ----------
        section(@"切回 main 并查看工作区状态");
        LGAssert([repo checkoutBranchWithName:mainBranch error:&error], error.description);
        NSLog(@"当前分支: %@", repo.currentBranchName);
        for (LGStatusEntry *entry in [repo statusWithError:nil]) {
            NSLog(@"状态: %@ -> 索引[%@] 工作区[%@]", entry.path, entry.indexStatus, entry.workdirStatus);
        }

        // ---------- 7. 查看提交历史与分支 ----------
        section([NSString stringWithFormat:@"提交历史（%@ 分支）", mainBranch]);
        for (LGCommit *c in [repo commitsWithMaxCount:0 error:nil]) {
            NSLog(@"%@  %@  <%@>  %@", c.shortOID, c.summary, c.author.email,
                  [NSDateFormatter localizedStringFromDate:c.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle]);
        }
        section(@"本地分支列表");
        for (NSString *name in [repo localBranchNamesWithError:nil]) {
            NSLog(@"分支: %@", name);
        }
        section(@"HEAD 树内容");
        LGTree *tree = [[repo headCommitWithError:nil] treeWithError:nil];
        for (NSString *path in tree.allFilePaths) {
            NSLog(@"文件: %@", path);
        }

        // ---------- 8. 本地克隆 ----------
        section(@"克隆仓库");
        NSString *clonePath = [baseDir stringByAppendingPathComponent:@"demo-repo-clone"];
        LGRepository *clone = [LGRepository cloneFromURL:repoPath toPath:clonePath error:&error];
        LGAssert(clone, error.description);
        NSLog(@"克隆到: %@", clone.workDirectoryPath);
        NSLog(@"克隆仓库当前分支: %@", clone.currentBranchName);
        NSLog(@"克隆仓库远程: %@", [clone remoteNamesWithError:nil]);
        NSString *clonedReadme = [NSString stringWithContentsOfFile:[clonePath stringByAppendingPathComponent:@"README.md"]
                                                           encoding:NSUTF8StringEncoding error:nil];
        LGAssert([clonedReadme containsString:@"libgit2Objc Demo"], @"克隆内容校验失败");
        NSLog(@"克隆内容校验通过 ✅");

        // ---------- 9. 远程 push / pull ----------
        section(@"远程 push / pull");
        // 9.1 创建一个 bare 仓库作为远程
        NSString *barePath = [baseDir stringByAppendingPathComponent:@"demo-remote.git"];
        LGRepository *bare = [LGRepository initializeAtPath:barePath bare:YES error:&error];
        LGAssert(bare, error.description);
        NSLog(@"bare 远程仓库: %@", bare.repositoryPath);

        // 9.2 原仓库添加 origin 并 push 当前分支
        LGRemote *origin = [repo createRemoteWithName:@"origin" url:barePath error:&error];
        LGAssert(origin, error.description);
        LGAssert([origin pushCurrentBranchWithError:&error], error.description);
        NSLog(@"push 完成: master -> %@", origin.name);

        // 9.3 从 bare 仓库克隆第二份，提交新文件后 push
        NSString *clone2Path = [baseDir stringByAppendingPathComponent:@"demo-repo-clone2"];
        LGRepository *clone2 = [LGRepository cloneFromURL:barePath toPath:clone2Path error:&error];
        LGAssert(clone2, error.description);
        [clone2 setConfigString:@"Clone2 User" forKey:@"user.name" error:nil];
        [clone2 setConfigString:@"clone2@example.com" forKey:@"user.email" error:nil];
        LGSignature *sig2 = [LGSignature signatureWithName:@"Clone2 User"
                                                     email:@"clone2@example.com"
                                                     error:&error];
        LGAssert(sig2, error.description);
        writeFile([clone2Path stringByAppendingPathComponent:@"from-clone2.txt"], @"来自 clone2 的提交\n");
        LGAssert([clone2.index addFileWithPath:@"from-clone2.txt" error:&error], error.description);
        LGCommit *c4 = [clone2 commitWithMessage:@"Add from-clone2.txt" author:sig2 committer:sig2 error:&error];
        LGAssert(c4, error.description);
        LGRemote *origin2 = [clone2 remoteWithName:@"origin" error:&error];
        LGAssert(origin2, error.description);
        LGAssert([origin2 pushCurrentBranchWithError:&error], error.description);
        NSLog(@"clone2 提交并 push: %@ %@", c4.shortOID, c4.summary);

        // 9.4 原仓库 pull，应 fast-forward 到 clone2 的提交
        LGRemote *origin3 = [repo remoteWithName:@"origin" error:&error];
        LGAssert(origin3, error.description);
        LGAssert([origin3 pullWithError:&error], error.description);
        NSString *pulled = [NSString stringWithContentsOfFile:[repoPath stringByAppendingPathComponent:@"from-clone2.txt"]
                                                     encoding:NSUTF8StringEncoding error:nil];
        LGAssert([pulled containsString:@"clone2"], @"pull 后未找到 clone2 的文件");
        NSLog(@"pull 完成 (fast-forward)，当前 HEAD: %@", [repo headCommitWithError:nil].shortOID);
        NSLog(@"工作区校验通过 ✅");

        // ---------- 10. 用短 SHA 查找提交 ----------
        section(@"按短 SHA 查找提交");
        LGCommit *found = [clone commitWithOID:commit2.shortOID error:&error];
        LGAssert(found, error.description);
        NSLog(@"找到提交: %@ %@", found.OID, found.summary);

        printf("\n🎉 Demo 全部执行成功！\n");
        printf("临时目录: %s\n", baseDir.UTF8String);
    }
    return 0;
}

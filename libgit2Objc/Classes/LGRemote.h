#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 远程仓库（origin 等），提供 fetch / push / pull
@interface LGRemote : NSObject

/// 远程名，如 "origin"
@property (nonatomic, readonly) NSString *name;
/// 远程地址（https:// 或本地路径）
@property (nonatomic, readonly) NSString *URLString;

/// HTTPS 认证用户名（可选；不设置则使用系统 git 凭证行为，本地路径/免密场景无需设置）
@property (nonatomic, copy, nullable) NSString *username;
/// HTTPS 认证密码或 Token（可选）
@property (nonatomic, copy, nullable) NSString *password;

/// 拉取远程更新到远程跟踪分支（origin/main 等），不改变工作区
- (BOOL)fetchWithError:(NSError **)error;

/// 推送当前分支到远程同名分支（refs/heads/X:refs/heads/X）
- (BOOL)pushCurrentBranchWithError:(NSError **)error;

/// 拉取并合并远程当前分支的更新（fetch + fast-forward / 自动合并提交）
/// 合并冲突时返回错误，工作区保留冲突状态以便手动处理
- (BOOL)pullWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

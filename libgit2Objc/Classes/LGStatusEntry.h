#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 工作区 / 暂存区状态条目
@interface LGStatusEntry : NSObject

/// 相对仓库工作目录的文件路径
@property (nonatomic, readonly) NSString *path;
/// 暂存区状态字符：A=新增 M=修改 D=删除 R=重命名 T=类型变更，无变更为空格
@property (nonatomic, readonly) NSString *indexStatus;
/// 工作区状态字符：A/M/D/R/T，无变更为空格
@property (nonatomic, readonly) NSString *workdirStatus;
/// 是否为未跟踪文件（相当于 git status 中的 "??"）
@property (nonatomic, readonly, getter=isUntracked) BOOL untracked;

@end

NS_ASSUME_NONNULL_END

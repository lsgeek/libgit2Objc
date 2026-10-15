#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// git 暂存区（index）
@interface LGIndex : NSObject

/// 暂存区中的条目数
@property (nonatomic, readonly) NSUInteger entryCount;

/// 将工作区文件加入暂存区（相对仓库工作目录的路径）
- (BOOL)addFileWithPath:(NSString *)path error:(NSError **)error;

/// 从暂存区移除文件
- (BOOL)removeFileWithPath:(NSString *)path error:(NSError **)error;

/// 将暂存区写回磁盘
- (BOOL)writeWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

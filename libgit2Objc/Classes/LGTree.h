#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 树中的一个条目（文件 / 子目录 / 子模块）
@interface LGTreeEntry : NSObject

@property (nonatomic, readonly) NSString *name;
/// blob / tree / commit 对应的 SHA
@property (nonatomic, readonly) NSString *OID;
/// 文件属性，如 33188 (100644)
@property (nonatomic, readonly) NSUInteger filemode;
@property (nonatomic, readonly, getter=isDirectory) BOOL directory;

@end

/// git tree 对象（目录快照）
@interface LGTree : NSObject

/// 树中所有顶层条目
@property (nonatomic, readonly) NSArray<LGTreeEntry *> *entries;

/// 递归地以 "path/to/file" 形式列出所有 blob 路径
@property (nonatomic, readonly) NSArray<NSString *> *allFilePaths;

@end

NS_ASSUME_NONNULL_END

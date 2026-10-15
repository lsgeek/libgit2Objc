#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 远程传输进度（fetch / push 通用）
@interface LGTransferProgress : NSObject

/// 总对象数
@property (nonatomic, readonly) NSUInteger totalObjects;
/// 已传输对象数（fetch 为已接收，push 为已推送）
@property (nonatomic, readonly) NSUInteger transferredObjects;
/// 已建立索引的对象数（仅 fetch 有意义）
@property (nonatomic, readonly) NSUInteger indexedObjects;
/// 已传输字节数
@property (nonatomic, readonly) NSUInteger transferredBytes;
/// 是否为推送
@property (nonatomic, readonly, getter=isPush) BOOL push;

/// 便捷描述，如 "12/30 对象，45 KB"
@property (nonatomic, readonly) NSString *localizedDescription;

@end

NS_ASSUME_NONNULL_END

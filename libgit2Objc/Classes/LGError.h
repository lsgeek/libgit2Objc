#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// libgit2 错误域，error.code 为 git_error_code 值
extern NSErrorDomain const LGGitErrorDomain;

@interface NSError (LGGitError)

/// 将最近一次 libgit2 调用失败转换为 NSError
/// @param gitCode libgit2 返回的负值错误码
+ (NSError *)lg_errorWithGitCode:(int)gitCode;

@end

NS_ASSUME_NONNULL_END

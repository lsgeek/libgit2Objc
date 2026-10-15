#import "LGError.h"
#import <git2.h>

NSErrorDomain const LGGitErrorDomain = @"com.libgit2objc.error";

@implementation NSError (LGGitError)

+ (NSError *)lg_errorWithGitCode:(int)gitCode {
    const git_error *error = git_error_last();
    NSString *message = error && error->message
        ? [NSString stringWithUTF8String:error->message]
        : [NSString stringWithFormat:@"libgit2 error %d", gitCode];
    return [NSError errorWithDomain:LGGitErrorDomain
                               code:gitCode
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end

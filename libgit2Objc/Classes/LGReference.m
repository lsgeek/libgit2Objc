#import "LGReference.h"
#import "LGReference+Internal.h"

@implementation LGReference

- (instancetype)initWithGitReference:(git_reference *)reference {
    self = [super init];
    if (self) {
        _gitReference = reference;
    }
    return self;
}

- (void)dealloc {
    git_reference_free(_gitReference);
}

- (id)copyWithZone:(NSZone *)zone {
    git_reference *copy = NULL;
    git_reference_dup(&copy, _gitReference);
    return [[[self class] alloc] initWithGitReference:copy];
}

- (NSString *)name {
    return [NSString stringWithUTF8String:git_reference_name(_gitReference)];
}

- (NSString *)shorthand {
    return [NSString stringWithUTF8String:git_reference_shorthand(_gitReference)];
}

- (BOOL)isBranch {
    return git_reference_is_branch(_gitReference) == 1;
}

- (BOOL)isRemote {
    return git_reference_is_remote(_gitReference) == 1;
}

- (BOOL)isTag {
    return git_reference_is_tag(_gitReference) == 1;
}

- (NSString *)targetOID {
    const git_oid *oid = git_reference_target(_gitReference);
    if (!oid) return @"";
    char hex[GIT_OID_HEXSZ + 1] = {0};
    git_oid_tostr(hex, sizeof(hex), oid);
    return [NSString stringWithUTF8String:hex];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@ -> %@>", NSStringFromClass(self.class), self.name, self.targetOID];
}

@end

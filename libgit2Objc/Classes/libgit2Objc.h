#import <Foundation/Foundation.h>

//! libgit2Objc 版本号
FOUNDATION_EXPORT double libgit2ObjcVersionNumber;
//! libgit2Objc 版本字符串
FOUNDATION_EXPORT const unsigned char libgit2ObjcVersionString[];

// 核心
#import "LGRepository.h"
#import "LGCommit.h"
#import "LGReference.h"
#import "LGTree.h"
#import "LGIndex.h"
#import "LGSignature.h"
#import "LGStatusEntry.h"
#import "LGRemote.h"
#import "LGRemoteCredentials.h"
#import "LGTransferProgress.h"
#import "LGError.h"

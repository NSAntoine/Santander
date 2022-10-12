//
//  CUICatalog.h
//  Santander
//
//  Created by Serena on 16/09/2022
//
	

#ifndef CUICatalog_h
#define CUICatalog_h
#import <Foundation/Foundation.h>

#include "CUINamedLookup.h"
#include "CUIStructuredThemeStore.h"

#define SWIFT_THROWING __attribute__((__swift_error__(nonnull_error)))

NS_ASSUME_NONNULL_BEGIN
@interface CUICatalog : NSObject
- (void)enumerateNamedLookupsUsingBlock:(void (^)(CUINamedLookup *namedAsset))block;
- (CUIStructuredThemeStore *)_themeStore;
- (id)initWithURL:(NSURL *)url error:(NSError **)error SWIFT_THROWING;
@end

NS_ASSUME_NONNULL_END
#endif /* CUICatalog_h */

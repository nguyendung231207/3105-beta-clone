//
// MCMRetainedLease.h
// Ported from 3105 to PROXYDECK (App)
//
// Interface for MobileContainerManager lease retention used in bad_query sandbox bypass
// (iOS 26.0 - iOS 27 beta 1..4).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCMRetainedLease : NSObject

@property (nonatomic, copy) NSString *rootPath;
@property (nonatomic, assign) BOOL activated;

+ (nullable instancetype)leaseForClass:(uint64_t)containerClass
                            identifier:(NSString *)identifier
                                 group:(nullable NSString *)group
                                 error:(NSError * _Nullable *)error;

- (BOOL)activate:(NSError * _Nullable *)error;
- (void)dealloc;

@end

#ifdef __cplusplus
extern "C" {
#endif

BOOL MCMBridgeAvailable(void);
NSArray<NSString *> *MCMEnumerateIdentifiersForClass(uint64_t containerClass);
NSString *MCMSafeIdentifier(NSString *identifier);
BOOL MCMActivateContainerPath(NSString *path);
BOOL MCMActivateContainer(uint64_t containerClass, NSString *identifier);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

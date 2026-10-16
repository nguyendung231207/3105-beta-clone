//
// PairingGlue.h & PairingSession.h
// Ported from 3105 to PROXYDECK (App)
//
// Driver for RPPairing host on iOS 27+:
// Advertises Bonjour service, receives device-initiated pairing requests from Settings app,
// displays PIN to user, and writes the resulting .plist/.mobiledevicepairing record.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PairingSession : NSObject

@property (nonatomic, assign) void *handle;
@property (nonatomic, readonly) BOOL isCancelled;

- (instancetype)init;
- (void)cancel;
- (void)markFinished;
- (void)freeHandle;

@end

@interface PairingGlue : NSObject

/**
 * Runs the RPPairing host server locally.
 *
 * @param name       Advertised name (e.g., @"PROXYDECK" or @"3105")
 * @param model      Device model string (e.g., @"Mac17,7")
 * @param outputPath Destination path to save pairing file (e.g., Documents/airlift_pairing.plist)
 * @param readyBlock Called when Bonjour NetService is bound and ready to advertise
 * @param pinBlock   Called when Apple's RemotePairing daemon generates the 6-digit PIN to show the user
 * @param completion Called when pairing succeeds or fails
 */
+ (PairingSession *)startPairingWithName:(NSString *)name
                                   model:(NSString *)model
                              outputPath:(NSString *)outputPath
                              readyBlock:(void (^)(NSString *serviceID, uint16_t port, NSDictionary *txtRecord))readyBlock
                                pinBlock:(void (^)(NSString *pin))pinBlock
                              completion:(void (^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END

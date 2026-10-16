//
// PairingGlue.m
// Ported from 3105 & AirCard-iOS to PROXYDECK (App)
//

#import <UIKit/UIKit.h>
#import "objc_headers/PairingGlue.h"
#import "objc_headers/AirLift_C_API.h"
#import "objc_headers/airlift.h"
#import <CFNetwork/CFNetwork.h>

@implementation PairingSession {
    BOOL _cancelled;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _handle = NULL;
        _cancelled = NO;
    }
    return self;
}

- (BOOL)isCancelled {
    return _cancelled;
}

- (void)cancel {
    _cancelled = YES;
    if (_handle) {
        [self freeHandle];
    }
}

- (void)markFinished {
    _cancelled = NO;
}

- (void)freeHandle {
    _handle = NULL;
}

- (void)dealloc {
    [self freeHandle];
}

@end

typedef struct {
    void (^readyBlock)(NSString *serviceID, uint16_t port, NSDictionary *txtRecord);
    void (^pinBlock)(NSString *pin);
    __unsafe_unretained PairingSession *session;
} PairingCallbackContext;

static void pairable_host_ready_cb(void *ctx,
                                   const char *service_id,
                                   uint16_t port,
                                   const char *const *txt_keys,
                                   const char *const *txt_vals,
                                   size_t txt_count) {
    PairingCallbackContext *pctx = (PairingCallbackContext *)ctx;
    if (!pctx || !pctx->readyBlock) return;
    
    NSString *sid = service_id ? [NSString stringWithUTF8String:service_id] : @"";
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (size_t i = 0; i < txt_count; i++) {
        if (txt_keys && txt_vals && txt_keys[i] && txt_vals[i]) {
            NSString *k = [NSString stringWithUTF8String:txt_keys[i]];
            NSString *v = [NSString stringWithUTF8String:txt_vals[i]];
            dict[k] = v;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (pctx->readyBlock) {
            pctx->readyBlock(sid, port, dict);
        }
    });
}

static void pairable_host_pin_cb(const char *pin, void *ctx) {
    PairingCallbackContext *pctx = (PairingCallbackContext *)ctx;
    if (!pctx || !pctx->pinBlock) return;
    
    NSString *pinStr = pin ? [NSString stringWithUTF8String:pin] : @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        if (pctx->pinBlock) {
            pctx->pinBlock(pinStr);
        }
    });
}

@implementation PairingGlue

+ (PairingSession *)startPairingWithName:(NSString *)name
                                   model:(NSString *)model
                              outputPath:(NSString *)outputPath
                              readyBlock:(void (^)(NSString *serviceID, uint16_t port, NSDictionary *txtRecord))readyBlock
                                pinBlock:(void (^)(NSString *pin))pinBlock
                              completion:(void (^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    PairingSession *session = [[PairingSession alloc] init];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (session.isCancelled) return;
        
        PairingCallbackContext *pctx = (PairingCallbackContext *)malloc(sizeof(PairingCallbackContext));
        pctx->readyBlock = [readyBlock copy];
        pctx->pinBlock = [pinBlock copy];
        pctx->session = session;
        
        NSString *savedAltIRK = [[NSUserDefaults standardUserDefaults] stringForKey:@"aircardPairingHostAltIRK"] ?: @"";
        const char *altIrkC = savedAltIRK.length > 0 ? [savedAltIRK UTF8String] : "";
        const char *nameC = (name && name.length > 0) ? [name UTF8String] : "PROXYDECK";
        const char *modelC = (model && model.length > 0) ? [model UTF8String] : "Mac17,7";
        const char *outC = (outputPath && outputPath.length > 0) ? [outputPath UTF8String] : "airlift_pairing.plist";
        
        ALPairResult result;
        memset(&result, 0, sizeof(result));
        
        int32_t rc = al_pairing_run_host("0.0.0.0",
                                         0,
                                         nameC,
                                         modelC,
                                         outC,
                                         altIrkC,
                                         pairable_host_ready_cb,
                                         pairable_host_pin_cb,
                                         pctx,
                                         &result);
        
        if (rc == 0) {
            if (result.host_alt_irk_hex && strlen(result.host_alt_irk_hex) > 0) {
                NSString *issuedIRK = [NSString stringWithUTF8String:result.host_alt_irk_hex];
                [[NSUserDefaults standardUserDefaults] setObject:issuedIRK forKey:@"aircardPairingHostAltIRK"];
            }
            [session markFinished];
            
            BOOL fileValid = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
                NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:nil];
                if ([attrs fileSize] > 0) {
                    fileValid = YES;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (fileValid) {
                    if (completion) completion(YES, outputPath, nil);
                } else {
                    NSError *err = [NSError errorWithDomain:@"AirLiftPairing" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"File pairing tạo ra rỗng"}];
                    if (completion) completion(NO, nil, err);
                }
            });
        } else {
            NSString *errMsg = result.error ? [NSString stringWithUTF8String:result.error] : @"Ghép đôi thất bại";
            NSError *err = [NSError errorWithDomain:@"AirLiftPairing" code:rc userInfo:@{NSLocalizedDescriptionKey: errMsg}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, nil, err);
            });
        }
        
        al_pairing_result_free(&result);
        free(pctx);
    });
    
    return session;
}

@end

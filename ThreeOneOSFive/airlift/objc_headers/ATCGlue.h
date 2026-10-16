//
// ATCGlue.h
// Ported from 3105 (YangJiiii / 3105 Offline v2) to PROXYDECK (App)
//
// Objective-C Bridge interfacing with internal Apple AirTraffic services (ATC, AFC, streaming_zip, RSD)
// via the AirLift exploit engine over a local loopback tunnel (LocalDevVPN 10.7.0.1 or 127.0.0.1).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT int ALGetGrappaToken(
    uint32_t in_version,
    uint32_t in_device_type,
    uint32_t in_protocol_version,
    uint8_t * _Nullable out_buf,
    size_t max_len,
    size_t * _Nullable out_len,
    char * _Nullable err_buf,
    size_t err_len
);

@interface ATCGlue : NSObject

#pragma mark - AirLift Logging Setup
+ (void)setupAirLiftLogging;

#pragma mark - Wallet Log Scanner (AirCard-iOS Integration)
+ (BOOL)startWalletLogScanWithDeviceIP:(NSString *)deviceIP
                           pairingPath:(NSString *)pairingPath
                           lineHandler:(void (^)(NSString *logLine))lineHandler
                            completion:(void (^)(BOOL success, NSError * _Nullable error))completion
                                 error:(NSError * _Nullable *)error;

+ (void)stopWalletLogScan;

#pragma mark - Diagnostic & Connection Probing
+ (BOOL)runFileWriteTestWithDeviceIP:(NSString *)deviceIP
                         pairingPath:(NSString *)pairingPath
                               error:(NSError * _Nullable *)error;

+ (nullable NSDictionary *)probeServicesWithDeviceIP:(NSString *)deviceIP
                                         pairingPath:(NSString *)pairingPath
                                             atcPort:(uint16_t)atcPort
                                              atcSSL:(BOOL)atcSSL
                                             zipPort:(uint16_t)zipPort
                                              zipSSL:(BOOL)zipSSL
                                               error:(NSError * _Nullable *)error;

+ (BOOL)verifyPairingRecordWithDeviceIP:(NSString *)deviceIP
                            pairingPath:(NSString *)pairingPath
                                  error:(NSError * _Nullable *)error;

+ (nullable NSArray<NSString *> *)listServicesWithDeviceIP:(NSString *)deviceIP
                                               pairingPath:(NSString *)pairingPath
                                                     error:(NSError * _Nullable *)error;

+ (BOOL)probeATCShimWithDeviceIP:(NSString *)deviceIP
                     pairingPath:(NSString *)pairingPath
                           error:(NSError * _Nullable *)error;

+ (BOOL)probeZipShimWithDeviceIP:(NSString *)deviceIP
                     pairingPath:(NSString *)pairingPath
                           error:(NSError * _Nullable *)error;

+ (BOOL)probeRemoveOwnDiagnosticFileWithDeviceIP:(NSString *)deviceIP
                                    pairingPath:(NSString *)pairingPath
                                   absolutePath:(NSString *)absolutePath
                                   expectedData:(NSData *)expectedData
                                          error:(NSError * _Nullable *)error;

#pragma mark - Arbitrary File Operations (Outside Sandbox)
+ (BOOL)writeFileWithDeviceIP:(NSString *)deviceIP
                  pairingPath:(NSString *)pairingPath
                   remotePath:(NSString *)remotePath
                         data:(NSData *)data
                        error:(NSError * _Nullable *)error;

+ (BOOL)writeFileArbitraryWithDeviceIP:(NSString *)deviceIP
                           pairingPath:(NSString *)pairingPath
                       targetDirectory:(NSString *)targetDirectory
                              fileName:(NSString *)fileName
                                  data:(NSData *)data
                                 error:(NSError * _Nullable *)error;

+ (BOOL)createFileArbitraryWithDeviceIP:(NSString *)deviceIP
                            pairingPath:(NSString *)pairingPath
                        targetDirectory:(NSString *)targetDirectory
                               fileName:(NSString *)fileName
                                   data:(NSData *)data
                                  error:(NSError * _Nullable *)error;

+ (BOOL)createFilesArbitraryWithDeviceIP:(NSString *)deviceIP
                             pairingPath:(NSString *)pairingPath
                       targetDirectories:(NSArray<NSString *> *)targetDirectories
                               fileNames:(NSArray<NSString *> *)fileNames
                                    data:(NSArray<NSData *> *)data
                                   error:(NSError * _Nullable *)error;

+ (BOOL)writeFilesArbitraryWithDeviceIP:(NSString *)deviceIP
                            pairingPath:(NSString *)pairingPath
                      targetDirectories:(NSArray<NSString *> *)targetDirectories
                              fileNames:(NSArray<NSString *> *)fileNames
                                   data:(NSArray<NSData *> *)data
                                  error:(NSError * _Nullable *)error;

+ (nullable NSData *)readFileArbitraryWithDeviceIP:(NSString *)deviceIP
                                       pairingPath:(NSString *)pairingPath
                                      absolutePath:(NSString *)absolutePath
                                      maximumBytes:(NSUInteger)maximumBytes
                                             error:(NSError * _Nullable *)error;

+ (nullable NSDictionary<NSString *, NSData *> *)readFilesArbitraryWithDeviceIP:(NSString *)deviceIP
                                                                    pairingPath:(NSString *)pairingPath
                                                                  absolutePaths:(NSArray<NSString *> *)absolutePaths
                                                                   maximumBytes:(NSUInteger)maximumBytes
                                                                   allowMissing:(BOOL)allowMissing
                                                                          error:(NSError * _Nullable *)error;

+ (BOOL)removeFileArbitraryWithDeviceIP:(NSString *)deviceIP
                            pairingPath:(NSString *)pairingPath
                           absolutePath:(NSString *)absolutePath
                           expectedData:(nullable NSData *)expectedData
                                  error:(NSError * _Nullable *)error;

+ (BOOL)ensureDirectoryArbitraryWithDeviceIP:(NSString *)deviceIP
                                 pairingPath:(NSString *)pairingPath
                             parentDirectory:(NSString *)parentDirectory
                               directoryName:(NSString *)directoryName
                                     created:(BOOL *)created
                                       error:(NSError * _Nullable *)error;

+ (BOOL)removeEmptyDirectoryArbitraryWithDeviceIP:(NSString *)deviceIP
                                      pairingPath:(NSString *)pairingPath
                                     absolutePath:(NSString *)absolutePath
                                            error:(NSError * _Nullable *)error;

+ (nullable NSArray<NSString *> *)listDirectoryArbitraryWithDeviceIP:(NSString *)deviceIP
                                                         pairingPath:(NSString *)pairingPath
                                                        absolutePath:(NSString *)absolutePath
                                                               error:(NSError * _Nullable *)error;

+ (BOOL)injectDirectoryWithDeviceIP:(NSString *)deviceIP
                        pairingPath:(NSString *)pairingPath
                    sourceDirectory:(NSString *)sourceDirectory
                    targetDirectory:(NSString *)targetDirectory
                      directoryName:(NSString *)directoryName
                              error:(NSError * _Nullable *)error;

#pragma mark - App Container & Installation Proxy Access
+ (nullable NSArray<NSDictionary *> *)installedApplicationsWithDeviceIP:(NSString *)deviceIP
                                                             pairingPath:(NSString *)pairingPath
                                                                   error:(NSError * _Nullable *)error;

+ (nullable NSDictionary *)applicationWithBundleID:(NSString *)bundleID
                                          deviceIP:(NSString *)deviceIP
                                       pairingPath:(NSString *)pairingPath
                                             error:(NSError * _Nullable *)error;

+ (nullable NSData *)readContainerFileWithDeviceIP:(NSString *)deviceIP
                                       pairingPath:(NSString *)pairingPath
                                            domain:(NSString *)domain
                                        identifier:(NSString *)identifier
                                      relativePath:(NSString *)relativePath
                                             error:(NSError * _Nullable *)error;

+ (nullable NSArray<NSString *> *)listContainerDirectoryWithDeviceIP:(NSString *)deviceIP
                                                         pairingPath:(NSString *)pairingPath
                                                              domain:(NSString *)domain
                                                          identifier:(NSString *)identifier
                                                        relativePath:(NSString *)relativePath
                                                               error:(NSError * _Nullable *)error;

+ (nullable NSArray<NSDictionary *> *)listContainerDirectoryEntriesWithDeviceIP:(NSString *)deviceIP
                                                                     pairingPath:(NSString *)pairingPath
                                                                          domain:(NSString *)domain
                                                                      identifier:(NSString *)identifier
                                                                    relativePath:(NSString *)relativePath
                                                                           error:(NSError * _Nullable *)error;

+ (BOOL)cleanBooksStagingWithDeviceIP:(NSString *)deviceIP
                         pairingPath:(NSString *)pairingPath
                               error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END

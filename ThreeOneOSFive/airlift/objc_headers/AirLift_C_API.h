//
// AirLift_C_API.h
// Ported from 3105 to PROXYDECK (App)
//
// Low-level C APIs for AirTraffic / RSD / AFC communication
//

#ifndef AIRLIFT_C_API_H
#define AIRLIFT_C_API_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Logging
void AirLiftLog(const char *format, ...);
void AirLiftResetTransportLog(void);
const char *AirLiftTransportLogPath(void);
const char *AirLiftFFIErrorString(int32_t code);

// Tunnel & Connection
int32_t AirLiftOpenTunnel(const char *ip_address, const char *pairing_file, void **tunnel_out);
int32_t AirLiftOpenTunnelRetrying(const char *ip_address, const char *pairing_file, int max_retries, void **tunnel_out);
void AirLiftTunnelDestroy(void *tunnel);
uint16_t AirLiftRSDServicePort(void *tunnel, const char *service_name, int *is_ssl);

// AFC (Apple File Conduit)
int32_t AirLiftOpenAFC(void *tunnel, void **afc_client_out);
void AirLiftAFCDestroy(void *afc_client);
int32_t AirLiftAFCRead(void *afc_client, const char *path, uint8_t **buf_out, size_t *len_out);
int32_t AirLiftAFCWrite(void *afc_client, const char *path, const uint8_t *data, size_t len);
int32_t AirLiftAFCRemoveIfPresent(void *afc_client, const char *path);
int32_t AirLiftAFCRemoveFileIfPresent(void *afc_client, const char *path);
int32_t AirLiftAFCEnsureDir(void *afc_client, const char *dir_path);
int32_t AirLiftAFCExists(void *afc_client, const char *path);
uint64_t AirLiftAFCFileSize(void *afc_client, const char *path);
char **AirLiftAFCDirectoryAtPath(void *afc_client, const char *path, size_t *count_out);

// AirTraffic (ATC) Message & Sync Engine
int32_t AirLiftATCBegin(void *tunnel, void **atc_session_out);
int32_t AirLiftSendATCMessage(void *atc_session, const void *plist_dict);
int32_t AirLiftReadATCMessage(void *atc_session, void **plist_dict_out);
int32_t AirLiftATCSyncToManifest(void *atc_session, const char *manifest_path);
int32_t AirLiftOpenZipStream(void *tunnel, uint16_t port, int is_ssl, void **zip_stream_out);
int32_t AirLiftPushArchive(void *zip_stream, const char *archive_path);

// File Injections & Books Staging Exploit
int32_t AirLiftPrepareBooksStaging(void *afc_client);
int32_t AirLiftBuildBooks(void *afc_client, const char *target_dir);
int32_t AirLiftBuildProbeArchive(const char *dest_zip, const char *target_subpath);
int32_t AirLiftBuildKeepArchive(const char *dest_zip);
int32_t AirLiftBuildEmptyDirectoryArchive(const char *dest_zip);
int32_t AirLiftWriteOneFile(void *tunnel, const char *pairing_path, const char *target_dir, const char *filename, const uint8_t *data, size_t len);
int32_t AirLiftWriteFilesArbitrary(void *tunnel, const char *pairing_path, const char **target_dirs, const char **filenames, const uint8_t **datas, const size_t *lens, size_t count);

// Grappa Token Generation
int32_t AirLiftGrappaBlob(uint8_t **out_blob, size_t *out_len);

// Wallet Live Scanner
void AirLiftWalletLogScanActive(int active);
void AirLiftWalletLogScanStopRequested(int stop);

#ifdef __cplusplus
}
#endif

#endif // AIRLIFT_C_API_H

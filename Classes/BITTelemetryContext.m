#import <Foundation/Foundation.h>
#import "BITTelemetryContext.h"

#if HOCKEYSDK_FEATURE_TELEMETRY

#import "BITTelemetryManagerPrivate.h"
#import "BITHockeyHelper.h"
#import "BITReachability.h"
#import "BITOrderedDictionary.h"
#import "BITPersistence.h"
#import "BITPersistencePrivate.h"

NSString *const kBITUserMetaData = @"BITUserMetaData";

static char *const BITContextOperationsQueue = "net.hockeyapp.telemetryContextQueue";

@implementation BITTelemetryContext

@synthesize appIdentifier = _appIdentifier;
@synthesize persistence = _persistence;

#pragma mark - Initialisation

-(instancetype)init {
  
  if(self = [super init]) {
    _operationsQueue = dispatch_queue_create(BITContextOperationsQueue, DISPATCH_QUEUE_CONCURRENT);
  }
  return self;
}
      
- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier persistence:(BITPersistence *)persistence {
  
  if ((self = [self init])) {
    _persistence = persistence;
    _appIdentifier = appIdentifier;
    BITDevice *deviceContext = [BITDevice new];
    deviceContext.model = bit_devicePlatform();
    deviceContext.type = bit_deviceType();
    deviceContext.osVersion = bit_osVersionBuild();
    deviceContext.os = bit_osName();
    deviceContext.deviceId = bit_appAnonID(NO);
    deviceContext.locale = bit_deviceLocale();
    deviceContext.language = bit_deviceLanguage();
    deviceContext.screenResolution = bit_screenSize();
    deviceContext.oemName = @"Apple";
    
    BITInternal *internalContext = [BITInternal new];
    internalContext.sdkVersion = bit_sdkVersion();
    
    BITApplication *applicationContext = [BITApplication new];
    applicationContext.version = bit_appVersion();
    
    BITOperation *operationContext = [BITOperation new];
    
    BITUser *userContext = [self loadUser];
    if (!userContext) {
      userContext = [self newUser];
      [self saveUser:userContext];
    }
    
    BITLocation *locationContext = [BITLocation new];
    BITSession *sessionContext = [BITSession new];
    
    _application = applicationContext;
    _device = deviceContext;
    _location = locationContext;
    _user = userContext;
    _internal = internalContext;
    _operation = operationContext;
    _session = sessionContext;

    [self configureNetworkStatusTracking];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - User

- (BITUser *)newUser {
  return ({
    BITUser *user = [BITUser new];
    user.userId = bit_appAnonID(NO);
    user;
  });
}

- (void)saveUser:(BITUser *)user{
  NSDictionary *userMetaData = @{kBITUserMetaData : user};
  [self.persistence persistMetaData:userMetaData];
}

- (BITUser *)loadUser{
  NSDictionary *metaData =[self.persistence metaData];
  BITUser *user = [metaData objectForKey:kBITUserMetaData];
  return user;
}

#pragma mark - Network

- (void)configureNetworkStatusTracking {
  [[BITReachability sharedInstance] startNetworkStatusTracking];
  _device.network = [[BITReachability sharedInstance] descriptionForActiveReachabilityType];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(updateNetworkType:) name:kBITReachabilityTypeChangedNotification object:nil];
}

- (void)updateNetworkType:(NSNotification *)notification {
    [self setNetworkType:[notification userInfo][kBITReachabilityUserInfoName]];
}

#pragma mark - Getter/Setter properties

- (NSString *)appIdentifier {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _appIdentifier;
  });
  return tmp;
}

- (void)setAppIdentifier:(NSString *)appIdentifier {
  NSString* tmp = [appIdentifier copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _appIdentifier = tmp;
  });
}

- (NSString *)screenResolution {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.screenResolution;
  });
  return tmp;
}

- (void)setScreenResolution:(NSString *)screenResolution {
  NSString* tmp = [screenResolution copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.screenResolution = tmp;
  });
}

- (NSString *)appVersion {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _application.version;
  });
  return tmp;
}

- (void)setAppVersion:(NSString *)appVersion {
  NSString* tmp = [appVersion copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _application.version = tmp;
  });
}

- (NSString *)userId {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _user.userId;
  });
  return tmp;
}

- (void)setUserId:(NSString *)userId {
  NSString* tmp = [userId copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _user.userId = tmp;
  });
}

- (NSString *)userAcquisitionDate {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _user.accountAcquisitionDate;
  });
  return tmp;
}

- (void)setUserAcquisitionDate:(NSString *)userAcqusitionDate {
  NSString* tmp = [userAcqusitionDate copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _user.accountAcquisitionDate = tmp;
  });
}

- (NSString *)accountId {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _user.accountId;
  });
  return tmp;
}

- (void)setAccountId:(NSString *)accountId {
  NSString* tmp = [accountId copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _user.accountId = tmp;
  });
}

- (NSString *)authenticatedUserId {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _user.authUserId;
  });
  return tmp;
}

- (void)setAuthenticatedUserId:(NSString *)authenticatedUserId {
  NSString* tmp = [authenticatedUserId copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _user.authUserId = tmp;
  });
}

- (NSString *)authenticatedUserAcquisitionDate {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _user.authUserAcquisitionDate;
  });
  return tmp;
}

- (void)setAuthenticatedUserAcquisitionDate:(NSString *)authenticatedUserAcquisitionDate {
  NSString* tmp = [authenticatedUserAcquisitionDate copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _user.authUserAcquisitionDate = tmp;
  });
}

- (NSString *)anonymousUserAquisitionDate {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _user.anonUserAcquisitionDate;
  });
  return tmp;
}

- (void)setAnonymousUserAquisitionDate:(NSString *)anonymousUserAquisitionDate {
  NSString* tmp = [anonymousUserAquisitionDate copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _user.anonUserAcquisitionDate = tmp;
  });
}

- (NSString *)sdkVersion {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _internal.sdkVersion;
  });
  return tmp;
}

- (void)setSdkVersion:(NSString *)sdkVersion {
  NSString* tmp = [sdkVersion copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _internal.sdkVersion = tmp;
  });
}

- (NSString *)sessionId {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _session.sessionId;
  });
  return tmp;
}

- (void)setSessionId:(NSString *)sessionId {
  NSString* tmp = [sessionId copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _session.sessionId = tmp;
  });
}

- (NSString *)isFirstSession {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _session.isFirst;
  });
  return tmp;
}

- (void)setIsFirstSession:(NSString *)isFirstSession {
  NSString* tmp = [isFirstSession copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _session.isFirst = tmp;
  });
}

- (NSString *)isNewSession {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _session.isNew;
  });
  return tmp;
}

- (void)setIsNewSession:(NSString *)isNewSession {
  NSString* tmp = [isNewSession copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _session.isNew = tmp;
  });
}

- (NSString *)osVersion {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.osVersion;
  });
  return tmp;
}

- (void)setOsVersion:(NSString *)osVersion {
  NSString* tmp = [osVersion copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.osVersion = tmp;
  });
}

- (NSString *)osName {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.os;
  });
  return tmp;
}

- (void)setOsName:(NSString *)osName {
  NSString* tmp = [osName copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.os = tmp;
  });
}

- (NSString *)deviceModel {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.model;
  });
  return tmp;
}

- (void)setDeviceModel:(NSString *)deviceModel {
  NSString* tmp = [deviceModel copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.model = tmp;
  });
}

- (NSString *)deviceOemName {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.oemName;
  });
  return tmp;
}

- (void)setDeviceOemName:(NSString *)oemName {
  NSString* tmp = [oemName copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.oemName = tmp;
  });
}

- (NSString *)osLocale {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.locale;
  });
  return tmp;
}

- (void)setOsLocale:(NSString *)osLocale {
  NSString* tmp = [osLocale copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.locale = tmp;
  });
}

- (NSString *)deviceId {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.deviceId;
  });
  return tmp;
}

- (void)setDeviceId:(NSString *)deviceId {
  NSString* tmp = [deviceId copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.deviceId = tmp;
  });
}

- (NSString *)deviceType {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.type;
  });
  return tmp;
}

- (void)setDeviceType:(NSString *)deviceType {
  NSString* tmp = [deviceType copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.type = tmp;
  });
}

- (NSString *)networkType {
  __block NSString *tmp;
  dispatch_sync(_operationsQueue, ^{
    tmp = _device.network;
  });
  return tmp;
}

- (void)setNetworkType:(NSString *)networkType {
  NSString* tmp = [networkType copy];
  dispatch_barrier_async(_operationsQueue, ^{
    _device.network = tmp;
  });
}

#pragma mark - Custom getter
#pragma mark - Helper

// TODO: Cache context
- (BITOrderedDictionary *)contextDictionary {
  __block BITOrderedDictionary *contextDictionary = [BITOrderedDictionary new];
  dispatch_sync(_operationsQueue, ^{
    [contextDictionary addEntriesFromDictionary:[self.session serializeToDictionary]];
    [contextDictionary addEntriesFromDictionary:[self.user serializeToDictionary]];
    [contextDictionary addEntriesFromDictionary:[self.device serializeToDictionary]];
    [contextDictionary addEntriesFromDictionary:[self.application serializeToDictionary]];
    [contextDictionary addEntriesFromDictionary:[self.location serializeToDictionary]];
    [contextDictionary addEntriesFromDictionary:[self.internal serializeToDictionary]];
    [contextDictionary addEntriesFromDictionary:[self.operation serializeToDictionary]];
  });
  return contextDictionary;
}

@end

#endif /* HOCKEYSDK_FEATURE_TELEMETRY */

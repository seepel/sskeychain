//
//  SSKeychain.m
//  SSToolkit
//
//  Created by Sam Soffes on 5/19/10.
//  Copyright (c) 2009-2011 Sam Soffes. All rights reserved.
//

#import "SSKeychain.h"

NSString * const kSSKeychainErrorDomain = @"com.samsoffes.sskeychain";

#if __has_feature(objc_arc)
	#define SSKeychainBridgedCast(type) __bridge type
	#define SSKeychainBridgeTransferCast(type) __bridge_transfer type
	#define SSKeychainAutorelease(stmt) stmt
#else
	#define SSKeychainBridgedCast(type) type
	#define SSKeychainBridgeTransferCast(type) type
	#define SSKeychainAutorelease(stmt) [stmt autorelease]
#endif


#if __IPHONE_4_0 && TARGET_OS_IPHONE  
CFTypeRef SSKeychainAccessibilityType = NULL;
#endif

@interface SSKeychain ()

/**
 Simple interface to `SecItemCopyMatching`.
 */
+ (id)_secItemCopyMatchingWithQuery:(NSDictionary *)query error:(NSError **)error;

/**
 Simple interface to `SecItemAdd`.
 */
+ (BOOL)_secItemAddWithQuery:(NSDictionary *)query error:(NSError **)error;

/**
 Simple interface to `SecItemDelete` (iOS) or `SecKeychainItemDelete` (Mac OS).
 */
+ (BOOL)_secItemDeleteWithQuery:(NSDictionary *)query error:(NSError **)error;

/**
 Get a base query for the given parameters.
 */
+ (NSMutableDictionary *)_queryForService:(NSString *)service account:(NSString *)account;

/**
 Generate an `NSError` object for the given status code
 */
+ (NSError *)_errorWithCode:(OSStatus)code;

@end

@implementation SSKeychain

#pragma mark - Advanced Query Interface


//+ (NSArray *)accountsForQuery:(NSDictionary *)query error:(NSError **)error {
//	NSMutableDictionary *mutableQuery = SSKeychainAutorelease([query mutableCopy]);
//	[mutableQuery setObject:(SSKeychainBridgedCast(id))kCFBooleanTrue forKey:(SSKeychainBridgedCast(id))kSecReturnAttributes];
//	[mutableQuery setObject:(SSKeychainBridgedCast(id))kSecMatchLimitAll forKey:(SSKeychainBridgedCast(id))kSecMatchLimit];
//	return [self
//			secItemCopyMatchingWithQuery:mutableQuery
//			error:error];
//}


//+ (NSDictionary *)accountForQuery:(NSDictionary *)query error:(NSError **)error {
//	NSMutableDictionary *mutableQuery = SSKeychainAutorelease([query mutableCopy]);
//	[mutableQuery setObject:(SSKeychainBridgedCast(id))kCFBooleanTrue forKey:(SSKeychainBridgedCast(id))kSecReturnAttributes];
//	[mutableQuery setObject:(SSKeychainBridgedCast(id))kSecMatchLimitOne forKey:(SSKeychainBridgedCast(id))kSecMatchLimit];
//	return [self
//			secItemCopyMatchingWithQuery:mutableQuery
//			error:error];
//}


//+ (BOOL)addItemForQuery:(NSDictionary *)query error:(NSError **)error {
//	
//}


//+ (BOOL)deleteItemForQuery:(NSDictionary *)query error:(NSError **)error {
//	
//}


#pragma mark - Getting Accounts

+ (NSArray *)allAccounts {
    return [self accountsForService:nil error:nil];
}


+ (NSArray *)allAccounts:(NSError **)error {
    return [self accountsForService:nil error:error];
}


+ (NSArray *)accountsForService:(NSString *)service {
    return [self accountsForService:service error:nil];
}


+ (NSArray *)accountsForService:(NSString *)service error:(NSError **)error {
    NSMutableDictionary *query = [self _queryForService:service account:nil];
    query[(SSKeychainBridgedCast(id))kSecMatchLimit] = (SSKeychainBridgedCast(id))kSecMatchLimitAll;
    query[(SSKeychainBridgedCast(id))kSecReturnAttributes] = (SSKeychainBridgedCast(id))kCFBooleanTrue;
    return [self _secItemCopyMatchingWithQuery:query error:error];
}


#pragma mark - Getting Passwords

+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account {
	return [self passwordForService:service account:account error:nil];
}


+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    NSData *data = [self passwordDataForService:service account:account error:error];
	if (data.length > 0) {
		NSString *string = [[NSString alloc] initWithData:(NSData *)data encoding:NSUTF8StringEncoding];
		return SSKeychainAutorelease(string);
	}
	return nil;
}


+ (NSData *)passwordDataForService:(NSString *)service account:(NSString *)account {
    return [self passwordDataForService:service account:account error:nil];
}


+ (NSData *)passwordDataForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    NSMutableDictionary *query = [self _queryForService:service account:account];
    query[(SSKeychainBridgedCast(id))kSecReturnData] = (SSKeychainBridgedCast(id))kCFBooleanTrue;
    query[(SSKeychainBridgedCast(id))kSecMatchLimit] = (SSKeychainBridgedCast(id))kSecMatchLimitOne;
	return [self _secItemCopyMatchingWithQuery:query error:nil];
}


#pragma mark - Deleting Passwords

+ (BOOL)deletePasswordForService:(NSString *)service account:(NSString *)account {
	return [self deletePasswordForService:service account:account error:nil];
}


+ (BOOL)deletePasswordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    NSMutableDictionary *query = [self _queryForService:service account:account];
    return [self _secItemDeleteWithQuery:query error:error];
}


#pragma mark - Setting Passwords

+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account {
	return [self setPassword:password forService:service account:account error:nil];
}


+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    NSData *data = [password dataUsingEncoding:NSUTF8StringEncoding];
    return [self setPasswordData:data forService:service account:account error:error];
}


+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)service account:(NSString *)account {
    return [self setPasswordData:password forService:service account:account error:nil];
}


+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)service account:(NSString *)account error:(NSError **)error {
	[self deletePasswordForService:service account:account error:nil];
	NSMutableDictionary *query = [self _queryForService:service account:account];
	query[(SSKeychainBridgedCast(id))kSecValueData] = password;
	return [self _secItemAddWithQuery:query error:error];
}


#pragma mark - Configuration

#if __IPHONE_4_0 && TARGET_OS_IPHONE 
+ (CFTypeRef)accessibilityType {
	return SSKeychainAccessibilityType;
}


+ (void)setAccessibilityType:(CFTypeRef)accessibilityType {
	CFRetain(accessibilityType);
	if (SSKeychainAccessibilityType) {
		CFRelease(SSKeychainAccessibilityType);
	}
	SSKeychainAccessibilityType = accessibilityType;
}
#endif


#pragma mark - Private

+ (NSMutableDictionary *)_queryForService:(NSString *)service account:(NSString *)account {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:3];
    dictionary[(SSKeychainBridgedCast(id))kSecClass] = (SSKeychainBridgedCast(id))kSecClassGenericPassword;
    if (service) {
        dictionary[(SSKeychainBridgedCast(id))kSecAttrService] = service;
    }
    if (account) {
        dictionary[(SSKeychainBridgedCast(id))kSecAttrAccount] = account;
    }
    return dictionary;
}


+ (NSError *)_errorWithCode:(OSStatus) code {
    NSString *message = nil;
    switch (code) {
        case errSecSuccess: return nil;
        case SSKeychainErrorBadArguments: message = @"Some of the arguments were invalid"; break;
          
#if TARGET_OS_IPHONE
        case errSecUnimplemented: message = @"Function or operation not implemented"; break;
        case errSecParam: message = @"One or more parameters passed to a function were not valid"; break;
        case errSecAllocate: message = @"Failed to allocate memory"; break;
        case errSecNotAvailable: message = @"No keychain is available. You may need to restart your computer"; break;
        case errSecDuplicateItem: message = @"The specified item already exists in the keychain"; break;
        case errSecItemNotFound: message = @"The specified item could not be found in the keychain"; break;
        case errSecInteractionNotAllowed: message = @"User interaction is not allowed"; break;
        case errSecDecode: message = @"Unable to decode the provided data"; break;
        case errSecAuthFailed: message = @"The user name or passphrase you entered is not correct"; break;
        default: message = @"Refer to SecBase.h for description";
#else
		default:
            message = SSKeychainAutorelease((SSKeychainBridgeTransferCast(NSString *))SecCopyErrorMessageString(code, NULL));
#endif
    }
    
    NSDictionary *userInfo = nil;
    if (message) { userInfo = @{ NSLocalizedDescriptionKey : message }; }
    return [NSError errorWithDomain:kSSKeychainErrorDomain
                               code:code
                           userInfo:userInfo];
}


+ (id)_secItemCopyMatchingWithQuery:(NSDictionary *)query error:(NSError **)error {
	OSStatus status = SSKeychainErrorBadArguments;
	CFTypeRef result = NULL;
	status = SecItemCopyMatching((SSKeychainBridgedCast(CFDictionaryRef))query, &result);
	if (status != errSecSuccess && error != NULL) {
		*error = [self _errorWithCode:status];
		return nil;
	}
	return SSKeychainAutorelease((SSKeychainBridgeTransferCast(id))result);
}


+ (BOOL)_secItemAddWithQuery:(NSDictionary *)query error:(NSError **)error {
	OSStatus status = SSKeychainErrorBadArguments;
	NSMutableDictionary *mutableQuery = SSKeychainAutorelease([query mutableCopy]);
#if __IPHONE_4_0 && TARGET_OS_IPHONE
	if (SSKeychainAccessibilityType) {
		mutableQuery[(SSKeychainBridgedCast(id))kSecAttrAccessible] = (SSKeychainBridgedCast(id))[self accessibilityType];
	}
#endif
	status = SecItemAdd((SSKeychainBridgedCast(CFDictionaryRef))mutableQuery, NULL);
	if (status != errSecSuccess && error != NULL) {
		*error = [self _errorWithCode:status];
	}
	return (status == errSecSuccess);
}


+ (BOOL)_secItemDeleteWithQuery:(NSDictionary *)query error:(NSError **)error {
	OSStatus status = SSKeychainErrorBadArguments;
#if TARGET_OS_IPHONE
	status = SecItemDelete((SSKeychainBridgedCast(CFDictionaryRef))query);
#else
	NSMutableDictionary *mutableQuery = SSKeychainAutorelease([query mutableCopy]);
	mutableQuery[(SSKeychainBridgedCast(id))kSecReturnRef] = (SSKeychainBridgedCast(id))kCFBooleanTrue;
	CFTypeRef result = NULL;
	status = SecItemCopyMatching((SSKeychainBridgedCast(CFDictionaryRef))mutableQuery, &result);
	if (status == errSecSuccess) {
        status = SecKeychainItemDelete((SecKeychainItemRef)result);
        CFRelease(result);
    }
#endif
    if (status != errSecSuccess && error != NULL) {
		*error = [self _errorWithCode:status];
	}
	return (status == errSecSuccess);
}


@end

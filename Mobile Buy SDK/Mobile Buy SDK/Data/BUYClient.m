//
//  BUYDataClient.m
//  Mobile Buy SDK
//
//  Created by Shopify.
//  Copyright (c) 2015 Shopify Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "BUYClient+Internal.h"
#import "BUYAssert.h"
#import "BUYModelManager.h"

static NSString * const BUYClientJSONMimeType = @"application/json";

@interface BUYClient () <NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation BUYClient

#pragma mark - Init

- (instancetype)init {
	BUYAssert(NO, @"BUYClient must be initialized using the designated initializer.");
	return nil;
}

- (instancetype)initWithShopDomain:(NSString *)shopDomain apiKey:(NSString *)apiKey appId:(NSString *)appId
{
	BUYAssert(shopDomain.length > 0, @"Bad shop domain. Please ensure you initialize with a shop domain.");
	BUYAssert(apiKey.length > 0,     @"Bad API key. Please ensure you initialize with a valid API key.");
	BUYAssert(appId.length > 0,      @"Bad app ID. Please ensure you initialize with a valid App ID.");
	
	self = [super init];
	if (self) {
		_modelManager = [BUYModelManager modelManager];
		_shopDomain = shopDomain;
		_apiKey = apiKey;
		_appId = appId;
		_applicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"] ?: @"";
		_queue = dispatch_get_main_queue();
		_requestQueue = [NSOperationQueue new];
		_session = [self urlSession];
		_pageSize = 25;
	}
	return self;
}

#pragma mark - Accessors -

- (NSURLSession *)urlSession
{
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
	
	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	
	config.HTTPAdditionalHeaders = @{@"User-Agent": [NSString stringWithFormat:@"Mobile Buy SDK iOS/%@/%@", BUYClientVersionString, bundleIdentifier]};
	
	return [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:self.requestQueue];
}

- (void)setPageSize:(NSUInteger)pageSize
{
	_pageSize = MAX(MIN(pageSize, 250), 1);
}

#pragma mark - Error

- (BUYStatus)statusForStatusCode:(NSUInteger)statusCode error:(NSError *)error
{
	BUYStatus status = BUYStatusUnknown;
	if (statusCode == BUYStatusPreconditionFailed) {
		status = BUYStatusPreconditionFailed;
	}
	else if (statusCode == BUYStatusNotFound) {
		status = BUYStatusNotFound;
	}
	else if (error || statusCode == BUYStatusFailed) {
		status = BUYStatusFailed;
	}
	else if (statusCode == BUYStatusProcessing) {
		status = BUYStatusProcessing;
	}
	else if (statusCode == BUYStatusComplete) {
		status = BUYStatusComplete;
	}
	return status;
}

- (NSError *)errorFromJSON:(NSDictionary *)json response:(NSURLResponse *)response
{
	NSInteger statusCode = [((NSHTTPURLResponse *) response) statusCode];
	if ((int)(statusCode / 100.0) != 2) { // If not a 2xx response code
		return [[NSError alloc] initWithDomain:BUYShopifyErrorDomain code:statusCode userInfo:json];
	}
	return nil;
}

#pragma mark - Convenience Requests

- (BUYRequestOperation *)getRequestForURL:(NSURL *)url completionHandler:(void (^)(NSDictionary *json, NSURLResponse *response, NSError *error))completionHandler
{
	return [self requestForURL:url method:@"GET" object:nil completionHandler:completionHandler];
}

- (BUYRequestOperation *)postRequestForURL:(NSURL *)url object:(id <BUYSerializable>)object completionHandler:(void (^)(NSDictionary *json, NSURLResponse *response, NSError *error))completionHandler
{
	return [self requestForURL:url method:@"POST" object:object completionHandler:completionHandler];
}

- (BUYRequestOperation *)putRequestForURL:(NSURL *)url object:(id<BUYSerializable>)object completionHandler:(void (^)(NSDictionary *json, NSURLResponse *response, NSError *error))completionHandler
{
	return [self requestForURL:url method:@"PUT" object:object completionHandler:completionHandler];
}

- (BUYRequestOperation *)patchRequestForURL:(NSURL *)url object:(id <BUYSerializable>)object completionHandler:(void (^)(NSDictionary *json, NSURLResponse *response, NSError *error))completionHandler
{
	return [self requestForURL:url method:@"PATCH" object:object completionHandler:completionHandler];
}

- (BUYRequestOperation *)deleteRequestForURL:(NSURL *)url completionHandler:(void (^)(NSDictionary *json, NSURLResponse *response, NSError *error))completionHandler
{
	return [self requestForURL:url method:@"DELETE" object:nil completionHandler:completionHandler];
}

#pragma mark - Generic Requests

- (void)startTask:(BUYRequestOperation *)task
{
	[self.requestQueue addOperation:task];
}

- (NSString *)authorizationHeader
{
	NSData *data = [_apiKey dataUsingEncoding:NSUTF8StringEncoding];
	return [NSString stringWithFormat:@"%@ %@", @"Basic", [data base64EncodedStringWithOptions:0]];
}

- (BUYRequestOperation *)requestForURL:(NSURL *)url method:(NSString *)method object:(id <BUYSerializable>)object completionHandler:(void (^)(NSDictionary *json, NSURLResponse *response, NSError *error))completionHandler
{
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	if (object) {
		request.HTTPBody = [NSJSONSerialization dataWithJSONObject:[object jsonDictionaryForCheckout] options:0 error:nil];
	}
	
	[request addValue:[self authorizationHeader] forHTTPHeaderField:@"Authorization"];
	[request addValue:BUYClientJSONMimeType forHTTPHeaderField:@"Content-Type"];
	[request addValue:BUYClientJSONMimeType forHTTPHeaderField:@"Accept"];
	
	if (self.customerToken) {
		[request addValue:self.customerToken forHTTPHeaderField:BUYClientCustomerAccessToken];
	}
	
	request.HTTPMethod = method;
	
	BUYRequestOperation *operation = [[BUYRequestOperation alloc] initWithSession:self.session request:request payload:object completion:^(NSDictionary *json, NSURLResponse *response, NSError *error) {
		dispatch_async(self.queue, ^{
			completionHandler(json, response, error);
		});
	}];
	
	[self startTask:operation];
	return operation;
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
	NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
	
	if (protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
		
		SecTrustResultType resultType;
		SecTrustEvaluate(protectionSpace.serverTrust, &resultType);
		
		BOOL trusted = (resultType == kSecTrustResultUnspecified) || (resultType == kSecTrustResultProceed);
		
		if (trusted) {
			NSURLCredential *credential = [NSURLCredential credentialForTrust:protectionSpace.serverTrust];
			completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
		}
		else {
			completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
		}
		
	}
	else {
		completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, NULL);
	}
}

#pragma mark - Deprecations

- (void)enableApplePayWithMerchantId:(NSString *)merchantId
{
	_merchantId = merchantId;
}

@end

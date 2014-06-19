//
// Created by Alexander Mertvetsov on 20.05.14.
// Copyright (c) 2014 Yandex.Money. All rights reserved.
//

#import "YMABaseSession.h"

static NSString *const kValueHeaderAuthorizationFormat = @"Bearer %@";
static NSString *const kHeaderAuthorization = @"Authorization";
static NSString *const kHeaderWWWAuthenticate = @"WWW-Authenticate";
static NSString *const kValueContentTypeImage = @"image/png";
static NSString *const kHeaderAcceptEncoding = @"Accept-Encoding";
static NSString *const kValueAcceptEncoding = @"gzip";
static NSString *const kHeaderAcceptLanguage = @"Accept-Language";
static NSString *const kValueAcceptLanguageDefault = @"ru";

NSString *const kValueUserAgentDefault = @"Yandex.Money.SDK/iOS";
NSString *const kHeaderContentType = @"Content-Type";
NSString *const kHeaderUserAgent = @"User-Agent";
NSString *const kMethodPost = @"POST";
NSString *const kValueContentTypeDefault = @"application/x-www-form-urlencoded;charset=UTF-8";

@implementation YMABaseSession

- (id)init {
    self = [super init];

    if (self) {
        _requestQueue = [[NSOperationQueue alloc] init];
        _responseQueue = [[NSOperationQueue alloc] init];
        _userAgent = kValueUserAgentDefault;
        _language = kValueAcceptLanguageDefault;
    }

    return self;
}

- (id)initWithUserAgent:(NSString *)userAgent {
    self = [self init];

    if (self) {
        _userAgent = [userAgent copy];
    }

    return self;
}

#pragma mark -
#pragma mark *** Public methods ***
#pragma mark -

- (void)performRequestWithToken:(NSString *)token parameters:(NSDictionary *)parameters url:(NSURL *)url completion:(YMAConnectionHandler)block {
    YMAConnection *connection = [self connectionWithUrl:url andToken:token];
    [connection addPostParams:parameters];

    [connection sendAsynchronousWithQueue:_requestQueue completionHandler:block];
}

- (void)performAndProcessRequestWithToken:(NSString *)token parameters:(NSDictionary *)parameters url:(NSURL *)url completion:(YMAConnectionHandler)block {
    [self performRequestWithToken:token parameters:parameters url:url completion:^(NSURLRequest *urlRequest, NSURLResponse *urlResponse, NSData *responseData, NSError *error) {
        [self processRequest:urlRequest response:urlResponse responseData:responseData error:error completion:block];
    }];
}

- (void)performAndProcessRequestWithToken:(NSString *)token data:(NSData *)data url:(NSURL *)url completion:(YMAConnectionHandler)block {
    [self performRequestWithToken:token data:data url:url andCompletionHandler:^(NSURLRequest *urlRequest, NSURLResponse *urlResponse, NSData *responseData, NSError *error) {
        [self processRequest:urlRequest response:urlResponse responseData:responseData error:error completion:block];
    }];
}

#pragma mark -
#pragma mark *** Private methods ***
#pragma mark -

- (void)performRequestWithToken:(NSString *)token data:(NSData *)data url:(NSURL *)url andCompletionHandler:(YMAConnectionHandler)handler {
    YMAConnection *connection = [self connectionWithUrl:url andToken:token];
    [connection addBodyData:data];

    [connection sendAsynchronousWithQueue:_requestQueue completionHandler:handler];
}

- (void)processRequest:(NSURLRequest *)urlRequest response:(NSURLResponse *)urlResponse responseData:(NSData *)responseData error:(NSError *)error completion:(YMAConnectionHandler)block {
    if (error) {
        block(urlRequest, urlResponse, responseData, error);
        return;
    }

    NSInteger statusCode = ((NSHTTPURLResponse *) urlResponse).statusCode;
    NSError *technicalError = [NSError errorWithDomain:kErrorKeyUnknown code:statusCode userInfo:@{@"request" : urlRequest, @"response" : urlResponse}];

    switch (statusCode) {
        case YMAStatusCodeOkHTTP:
            block(urlRequest, urlResponse, responseData, nil);
            break;
        case YMAStatusCodeInsufficientScopeHTTP:
        case YMAStatusCodeInvalidTokenHTTP:
            block(urlRequest, urlResponse, responseData, [NSError errorWithDomain:[self valueOfHeader:kHeaderWWWAuthenticate forResponse:urlResponse] code:statusCode userInfo:@{@"request" : urlRequest, @"response" : urlResponse}]);
            break;
        default:
            block(urlRequest, urlResponse, responseData, technicalError);
            break;
    }
}

- (YMAConnection *)connectionWithUrl:(NSURL *)url andToken:(NSString *)token {
    YMAConnection *connection = [[YMAConnection alloc] initWithUrl:url];
    connection.requestMethod = kMethodPost;
    [connection addValue:kValueContentTypeDefault forHeader:kHeaderContentType];
    [connection addValue:_userAgent forHeader:kHeaderUserAgent];
    [connection addValue:kValueAcceptEncoding forHeader:kHeaderAcceptEncoding];
    [connection addValue:self.language forHeader:kHeaderAcceptLanguage];

    if (token)
        [connection addValue:[NSString stringWithFormat:kValueHeaderAuthorizationFormat, token] forHeader:kHeaderAuthorization];

    return connection;
}

- (NSString *)valueOfHeader:(NSString *)headerName forResponse:(NSURLResponse *)response {
    NSDictionary *headers = [((NSHTTPURLResponse *) response) allHeaderFields];

    for (NSString *header in headers.allKeys) {
        if ([header caseInsensitiveCompare:headerName] == NSOrderedSame)
            return [headers objectForKey:header];
    }

    return nil;
}

@end
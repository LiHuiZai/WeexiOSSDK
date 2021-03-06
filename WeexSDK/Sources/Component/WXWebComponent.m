/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import "WXWebComponent.h"
#import "WXComponent_internal.h"
#import "WXUtility.h"
#import "WXHandlerFactory.h"
#import "WXURLRewriteProtocol.h"
#import "WXSDKEngine.h"

#import <JavaScriptCore/JavaScriptCore.h>
#import <ErosPluginBaseLibrary/BMNotifactionCenter.h>
#import <ErosPluginBaseLibrary/BMMediatorManager.h>

@interface WXWebView : WKWebView

@end

@implementation WXWebView

- (void)dealloc
{
    if (self) { //!OCLint
//        self.delegate = nil;
    }
}

@end

@interface WXWebComponent ()<WKScriptMessageHandler>

@property (nonatomic, strong) WXWebView *webview;
@property (nonatomic, strong) JSContext *jsContext;

@property (nonatomic, strong) NSString *url;

@property (nonatomic, strong) NSString *source;

// save source during this initialization
@property (nonatomic, strong) NSString *inInitsource;

@property (nonatomic, assign) BOOL startLoadEvent;

@property (nonatomic, assign) BOOL finishLoadEvent;

@property (nonatomic, assign) BOOL failLoadEvent;

@property (nonatomic, assign) BOOL notifyEvent;

@end

@implementation WXWebComponent

WX_EXPORT_METHOD(@selector(postMessage:))
WX_EXPORT_METHOD(@selector(goBack))
WX_EXPORT_METHOD(@selector(reload))
WX_EXPORT_METHOD(@selector(goForward))

- (instancetype)initWithRef:(NSString *)ref type:(NSString *)type styles:(NSDictionary *)styles attributes:(NSDictionary *)attributes events:(NSArray *)events weexInstance:(WXSDKInstance *)weexInstance
{
    if (self = [super initWithRef:ref type:type styles:styles attributes:attributes events:events weexInstance:weexInstance]) {
        self.url = attributes[@"src"];
        
        if(attributes[@"source"]){
            self.inInitsource = attributes[@"source"];
        }
        
    }
    return self;
}

- (WKWebViewConfiguration *)baseConfiguration {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    NSString *scalesPageToFitScript = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
    configuration.preferences.javaScriptEnabled = YES;
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:scalesPageToFitScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    [userContentController addUserScript:userScript];
    [userContentController addScriptMessageHandler: self name: @"closePage"];
    [userContentController addScriptMessageHandler: self name: @"fireEvent"];
    configuration.userContentController = userContentController;
    configuration.allowsInlineMediaPlayback = YES;
    
    return configuration;
}

- (UIView *)loadView
{
    return [[WXWebView alloc] initWithFrame:CGRectZero configuration:[self baseConfiguration]];
}

- (void)viewDidLoad
{
    _webview = (WXWebView *)self.view;
    _webview.navigationDelegate = self;
    _webview.UIDelegate = self;
    [_webview setBackgroundColor:[UIColor clearColor]];
    _webview.opaque = NO;
//    _jsContext = [_webview valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
//    __weak typeof(self) weakSelf = self;

    // This method will be abandoned slowly.
//    _jsContext[@"$notifyWeex"] = ^(JSValue *data) {
//        if (weakSelf.notifyEvent) {
//            [weakSelf fireEvent:@"notify" params:[data toDictionary]];
//        }
//    };
//
//    //Weex catch postMessage event from web
//    _jsContext[@"postMessage"] = ^() {
//
//        NSArray *args = [JSContext currentArguments];
//
//        if (args && args.count < 2) {
//            return;
//        }
//
//        NSDictionary *data = [args[0] toDictionary];
//        NSString *origin = [args[1] toString];
//
//        if (data == nil) {
//            return;
//        }
//
//        NSDictionary *initDic = @{ @"type" : @"message",
//                                   @"data" : data,
//                                   @"origin" : origin
//        };
//
//        [weakSelf fireEvent:@"message" params:initDic];
//    };
    
    // 配置页面自适应缩放
        NSString *jscript = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
        
        NSString *promptCode = @"(function(){window.bmnative={closePage:function(){if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.closePage&&window.webkit.messageHandlers.closePage.postMessage){window.webkit.messageHandlers.closePage.postMessage('')}else{return}},fireEvent:function(event,info){event=event||'eventName';info=info||'';if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.bmnative&&window.webkit.messageHandlers.bmnative.postMessage){var params=JSON.stringify({event,info});window.webkit.messageHandlers.bmnative.postMessage(params)}else{return}}};return 2})();";

        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:jscript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        WKUserContentController *userContentController = [[WKUserContentController alloc] init];
        [userContentController addUserScript:userScript];
        // 添加HTML页面js的调用方法，这里默认添加的方法名称为getSlideData，可自行按需更改
        [userContentController addScriptMessageHandler:self name:@"bmnative"];
        [userContentController addScriptMessageHandler:self name:@"closePage"];
        // 配置WKWebView
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.userContentController = userContentController;
        // 显示WKWebView
        _webview = [[WKWebView alloc] initWithFrame:self.view.frame configuration:configuration];
        [self.view addSubview:_webview];
        
        [_webview evaluateJavaScript:promptCode completionHandler:^(id _Nullable object, NSError * _Nullable error) {
                            NSLog(@" - %@ -- %@ --- ",error,object);
        }];
    
    self.source = _inInitsource;
    if (_url) {
        [self loadURL:_url];
    }
}

//- (void)updateAttributes:(NSDictionary *)attributes
//{
//    if (attributes[@"src"]) {
//        self.url = attributes[@"src"];
//    }
//
//    if (attributes[@"source"]) {
//        self.inInitsource = attributes[@"source"];
//        self.source = self.inInitsource;
//    }
//}
//
//- (void)addEvent:(NSString *)eventName
//{
//    if ([eventName isEqualToString:@"pagestart"]) {
//        _startLoadEvent = YES;
//    }
//    else if ([eventName isEqualToString:@"pagefinish"]) {
//        _finishLoadEvent = YES;
//    }
//    else if ([eventName isEqualToString:@"error"]) {
//        _failLoadEvent = YES;
//    }
//}

//- (void)setUrl:(NSString *)url
//{
//    NSString* newURL = [url copy];
//    WX_REWRITE_URL(url, WXResourceTypeLink, self.weexInstance)
//    if (!newURL) {
//        return;
//    }
//
//    if (![newURL isEqualToString:_url]) {
//        _url = newURL;
//        if (_url) {
//            [self loadURL:_url];
//        }
//    }
//}
//
//- (void) setSource:(NSString *)source
//{
//    NSString *newSource=[source copy];
//    if(!newSource || _url){
//        return;
//    }
//    if(![newSource isEqualToString:_source]){
//        _source=newSource;
//        if(_source){
//            [_webview loadHTMLString:_source baseURL:nil];
//        }
//    }
//
//}

- (void)loadURL:(NSString *)url
{
    if (self.webview) {
        NSURLRequest *request =[NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        [self.webview loadRequest:request];
    }
}

//- (void)reload
//{
//    [self.webview reload];
//}
//
//- (void)goBack
//{
//    if ([self.webview canGoBack]) {
//        [self.webview goBack];
//    }
//}
//
//- (void)goForward
//{
//    if ([self.webview canGoForward]) {
//        [self.webview goForward];
//    }
//}

// This method will be abandoned slowly, use postMessage
//- (void)notifyWebview:(NSDictionary *) data
//{
//    NSString *json = [WXUtility JSONString:data];
//    NSString *code = [NSString stringWithFormat:@"(function(){var evt=null;var data=%@;if(typeof CustomEvent==='function'){evt=new CustomEvent('notify',{detail:data})}else{evt=document.createEvent('CustomEvent');evt.initCustomEvent('notify',true,true,data)}document.dispatchEvent(evt)}())", json];
//    [_webview evaluateJavaScript:code completionHandler:nil];
//}

// Weex postMessage to web
//- (void)postMessage:(NSDictionary *)data {
//    WXSDKInstance *instance = [WXSDKEngine topInstance];
//
//    NSString *bundleUrlOrigin = @"";
//
//    if (instance.pageName) {
//        NSString *bundleUrl = [instance.scriptURL absoluteString];
//        NSURL *url = [NSURL URLWithString:bundleUrl];
//        bundleUrlOrigin = [NSString stringWithFormat:@"%@://%@%@", url.scheme, url.host, url.port ? [NSString stringWithFormat:@":%@", url.port] : @""];
//    }
//
//    NSDictionary *initDic = @{
//        @"type" : @"message",
//        @"data" : data,
//        @"origin" : bundleUrlOrigin
//    };
//
//    NSString *json = [WXUtility JSONString:initDic];
//
//    NSString *code = [NSString stringWithFormat:@"(function (){window.dispatchEvent(new MessageEvent('message', %@));}())", json];
//    [_webview evaluateJavaScript:code completionHandler:nil];
//}

//#pragma mark Webview Delegate
//
//- (void)baseInfoWithCompletion:(void (^)(NSMutableDictionary<NSString *, id> *data))completion {
//    NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary new];
//    [info setObject:self.webview.URL.absoluteString ?: @"" forKey:@"url"];
//    [info setObject:@(self.webview.canGoBack) forKey:@"canGoBack"];
//    [info setObject:@(self.webview.canGoForward) forKey:@"canGoForward"];
//    [self.webview evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
//        [info setObject:result ? result : @"" forKey:@"title"];
//        if (completion) {
//            completion(info);
//        }
//    }];
//}

//- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
//{
//
//}
//
//- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
//{
//    if (_finishLoadEvent) {
//        [self baseInfoWithCompletion:^(NSMutableDictionary<NSString *,id> *data) {
//            [self fireEvent:@"pagefinish" params:data domChanges:@{@"attrs": @{@"src":self.webview.URL.absoluteString}}];
//        }];
//    }
//}

//- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
//{
//    if (_failLoadEvent) {
//        [self baseInfoWithCompletion:^(NSMutableDictionary<NSString *,id> *data) {
//            [data setObject:[error localizedDescription] forKey:@"errorMsg"];
//            [data setObject:[NSString stringWithFormat:@"%ld", (long)error.code] forKey:@"errorCode"];
//
//            NSString * urlString = error.userInfo[NSURLErrorFailingURLStringErrorKey];
//            if (urlString) {
//                // webview.request may not be the real error URL, must get from error.userInfo
//                [data setObject:urlString forKey:@"url"];
//                if (![urlString hasPrefix:@"http"]) {
//                    return;
//                }
//            }
//            [self fireEvent:@"error" params:data];
//        }];
//    }
//}

//- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
//       if (_startLoadEvent) {
//           NSMutableDictionary<NSString *, id> *data = [NSMutableDictionary new];
//           [data setObject:navigationAction.request.URL.absoluteString ?:@"" forKey:@"url"];
//           [self fireEvent:@"pagestart" params:data];
//       }
//
//       decisionHandler(WKNavigationActionPolicyAllow);
//}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    
    NSLog(@"%@", message.name);
    if([message.name isEqualToString: @"closePage"]){
        //window.webkit.messageHandlers.closePage.postMessage()
        dispatch_async(dispatch_get_main_queue(), ^{
            [[BMMediatorManager shareInstance].currentViewController.navigationController popViewControllerAnimated:YES];
            [[BMMediatorManager shareInstance].currentViewController dismissViewControllerAnimated:YES completion:nil];
        });
    }else if([message.name isEqualToString: @"fireEvent"]){
        //window.webkit.messageHandlers.fireEvent.postMessage(['通知名称', 通知参数 jsonstring])
        NSArray *array = message.body;
        NSString *event = @"";
        NSString *info = @"";
        if([array.firstObject isKindOfClass: [NSString class]]){
            event = array.firstObject;
        }
        
        if([array.lastObject isKindOfClass: [NSString class]]){
            info = [[[[array.lastObject stringByReplacingOccurrencesOfString: @"\"" withString:@""] stringByReplacingOccurrencesOfString: @"'" withString:@""] stringByReplacingOccurrencesOfString:@"{" withString:@""] stringByReplacingOccurrencesOfString:@"}" withString:@""];
        }
        NSArray *tmp = [info componentsSeparatedByString: @","];
        NSMutableDictionary *tmpDict = [NSMutableDictionary new];
        for (int i = 0; i < tmp.count; i++) {
            NSString *tmpStr = tmp[i];
            if([tmpStr hasPrefix: @"url"]){
                tmpDict[@"url"] = [tmpStr substringFromIndex: 4];
            }
            if([tmpStr hasPrefix: @"content"]){
                tmpDict[@"content"] = [tmpStr substringFromIndex: 8];
            }
            if([tmpStr hasPrefix: @"image"]){
                tmpDict[@"image"] = [tmpStr substringFromIndex: 6];
            }
        }
        
        [[BMNotifactionCenter defaultCenter] emit: event  info: tmpDict];
    }else if ([message.name isEqualToString:@"bmnative"]) {
        // 获取HTML页面js调用相应方法获取的验证码服务返回值，方法名应与添加在HTML页面js调用方法名保持一致
        NSDictionary *dic = [self convertjsonStringToDict:message.body];
        [[BMNotifactionCenter defaultCenter] emit:[dic objectForKey:@"event"] info:[dic objectForKey:@"info"]];

    }
}


- (NSDictionary *)convertjsonStringToDict:(NSString *)jsonString{
    
    NSDictionary *retDict = nil;
    if ([jsonString isKindOfClass:[NSString class]]) {
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        retDict = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        return  retDict;
    }else{
        return retDict;
    }
    
}


@end

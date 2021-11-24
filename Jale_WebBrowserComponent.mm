// clang-format off

#include "JaLe_WebBrowserComponent.h"

#import <Foundation/Foundation.h>
#import <objc/objc-runtime.h>
#import <WebKit/WebKit.h>

#include <juce_core/juce_core.h>
#include <juce_core/native/juce_mac_ObjCHelpers.h>
#import <juce_gui_extra/embedding/juce_NSViewComponent.h>

// clang-format on

#if JUCE_IOS || \
    (defined(MAC_OS_X_VERSION_10_10) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_10)

    #define JUCE_USE_WKWEBVIEW 1

    #if (defined(MAC_OS_X_VERSION_10_11) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_11)
        #define WKWEBVIEW_WEBVIEWDIDCLOSE_SUPPORTED 1
    #endif

    #if (defined(MAC_OS_X_VERSION_10_12) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_12)
        #define WKWEBVIEW_OPENPANEL_SUPPORTED 1
    #endif

#endif

static NSURL * appendParametersToFileURL (const juce::URL & url, NSURL * fileUrl)
{
#if JUCE_IOS || \
    (defined(MAC_OS_X_VERSION_10_9) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_9)
    const auto parameterNames = url.getParameterNames ();
    const auto parameterValues = url.getParameterValues ();

    jassert (parameterNames.size () == parameterValues.size ());

    if (parameterNames.isEmpty ())
        return fileUrl;

    juce::NSUniquePtr<NSURLComponents> components ([[NSURLComponents alloc] initWithURL:fileUrl
                                                                resolvingAgainstBaseURL:NO]);
    juce::NSUniquePtr<NSMutableArray> queryItems ([[NSMutableArray alloc] init]);

    for (int i = 0; i < parameterNames.size (); ++i)
        [queryItems.get ()
            addObject:[NSURLQueryItem queryItemWithName:juceStringToNS (parameterNames [i])
                                                  value:juceStringToNS (parameterValues [i])]];

    [components.get () setQueryItems:queryItems.get ()];

    return [components.get () URL];
#else
    const auto queryString = url.getQueryString ();

    if (queryString.isNotEmpty ())
        if (NSString * fileUrlString = [fileUrl absoluteString])
            return [NSURL
                URLWithString:[fileUrlString stringByAppendingString:juceStringToNS (queryString)]];

    return fileUrl;
#endif
}

static NSMutableURLRequest * getRequestForURL (const juce::String & url,
                                               const juce::StringArray * headers,
                                               const juce::MemoryBlock * postData)
{
    NSString * urlString = juceStringToNS (url);

#if JUCE_IOS || \
    (defined(MAC_OS_X_VERSION_10_9) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_9)
    urlString = [urlString
        stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                               URLQueryAllowedCharacterSet]];
#else
    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
#endif

    if (NSURL * nsURL = [NSURL URLWithString:urlString])
    {
        NSMutableURLRequest * r =
            [NSMutableURLRequest requestWithURL:nsURL
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                timeoutInterval:30.0];

        if (postData != nullptr && postData->getSize () > 0)
        {
            [r setHTTPMethod:juce::nsStringLiteral ("POST")];
            [r setHTTPBody:[NSData dataWithBytes:postData->getData () length:postData->getSize ()]];
        }

        if (headers != nullptr)
        {
            for (int i = 0; i < headers->size (); ++i)
            {
                auto headerName = (*headers) [i].upToFirstOccurrenceOf (":", false, false).trim ();
                auto headerValue = (*headers) [i].fromFirstOccurrenceOf (":", false, false).trim ();

                [r setValue:juceStringToNS (headerValue)
                    forHTTPHeaderField:juceStringToNS (headerName)];
            }
        }

        return r;
    }

    return nullptr;
}

#if JUCE_MAC

    #if JUCE_USE_WKWEBVIEW
using WebViewBase = juce::ObjCClass<WKWebView>;
    #else
using WebViewBase = ObjCClass<WebView>;
    #endif

struct WebViewKeyEquivalentResponder : public WebViewBase
{
    WebViewKeyEquivalentResponder ()
        : WebViewBase ("WebViewKeyEquivalentResponder_")
    {
        addMethod (@selector (performKeyEquivalent:), performKeyEquivalent, @encode (BOOL), "@:@");
        registerClass ();
    }

private:
    static BOOL performKeyEquivalent (id self, SEL selector, NSEvent * event)
    {
        NSResponder * first = [[self window] firstResponder];

    #if (defined(MAC_OS_X_VERSION_10_12) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_12)
        constexpr auto mask = NSEventModifierFlagDeviceIndependentFlagsMask;
        constexpr auto key = NSEventModifierFlagCommand;
    #else
        constexpr auto mask = NSDeviceIndependentModifierFlagsMask;
        constexpr auto key = NSCommandKeyMask;
    #endif

        if (([event modifierFlags] & mask) == key)
        {
            auto sendAction = [&] (SEL actionSelector) -> BOOL
            { return [NSApp sendAction:actionSelector to:first from:self]; };

            if ([[event charactersIgnoringModifiers] isEqualToString:@"x"])
                return sendAction (@selector (cut:));
            if ([[event charactersIgnoringModifiers] isEqualToString:@"c"])
                return sendAction (@selector (copy:));
            if ([[event charactersIgnoringModifiers] isEqualToString:@"v"])
                return sendAction (@selector (paste:));
            if ([[event charactersIgnoringModifiers] isEqualToString:@"a"])
                return sendAction (@selector (selectAll:));
        }

        return sendSuperclassMessage<BOOL> (self, selector, event);
    }
};

#endif

#if JUCE_USE_WKWEBVIEW

struct WebViewDelegateClass : public juce::ObjCClass<NSObject>
{
    WebViewDelegateClass ()
        : ObjCClass<NSObject> ("JUCEWebViewDelegate_")
    {
        addIvar<WebBrowserComponent *> ("owner");

        addMethod (@selector (webView:decidePolicyForNavigationAction:decisionHandler:),
                   decidePolicyForNavigationAction,
                   "v@:@@@");
        addMethod (@selector (webView:didFinishNavigation:), didFinishNavigation, "v@:@@");
        addMethod (@selector (webView:didFailNavigation:withError:), didFailNavigation, "v@:@@@");
        addMethod (@selector (webView:didFailProvisionalNavigation:withError:),
                   didFailProvisionalNavigation,
                   "v@:@@@");

    #if WKWEBVIEW_WEBVIEWDIDCLOSE_SUPPORTED
        addMethod (@selector (webViewDidClose:), webViewDidClose, "v@:@");
    #endif

        addMethod (@selector (webView:
                       createWebViewWithConfiguration:forNavigationAction:windowFeatures:),
                   createWebView,
                   "@@:@@@@");

    #if WKWEBVIEW_OPENPANEL_SUPPORTED
        addMethod (@selector (webView:
                       runOpenPanelWithParameters:initiatedByFrame:completionHandler:),
                   runOpenPanel,
                   "v@:@@@@");
    #endif

        registerClass ();
    }

    static void setOwner (id self, WebBrowserComponent * owner)
    {
        object_setInstanceVariable (self, "owner", owner);
    }
    static WebBrowserComponent * getOwner (id self)
    {
        return juce::getIvar<WebBrowserComponent *> (self, "owner");
    }

private:
    static void decidePolicyForNavigationAction (id self,
                                                 SEL,
                                                 WKWebView *,
                                                 WKNavigationAction * navigationAction,
                                                 void (^decisionHandler) (WKNavigationActionPolicy))
    {
        if (getOwner (self)->pageAboutToLoad (
                juce::nsStringToJuce ([[[navigationAction request] URL] absoluteString])))
            decisionHandler (WKNavigationActionPolicyAllow);
        else
            decisionHandler (WKNavigationActionPolicyCancel);
    }

    static void didFinishNavigation (id self, SEL, WKWebView * webview, WKNavigation *)
    {
        getOwner (self)->pageFinishedLoading (
            juce::nsStringToJuce ([[webview URL] absoluteString]));
    }

    static void displayError (WebBrowserComponent * owner, NSError * error)
    {
        if ([error code] != NSURLErrorCancelled)
        {
            auto errorString = juce::nsStringToJuce ([error localizedDescription]);
            bool proceedToErrorPage = owner->pageLoadHadNetworkError (errorString);

            // WKWebView doesn't have an internal error page, so make a really simple one ourselves
            if (proceedToErrorPage)
                owner->goToURL ("data:text/plain;charset=UTF-8," + errorString);
        }
    }

    static void didFailNavigation (id self, SEL, WKWebView *, WKNavigation *, NSError * error)
    {
        displayError (getOwner (self), error);
    }

    static void
    didFailProvisionalNavigation (id self, SEL, WKWebView *, WKNavigation *, NSError * error)
    {
        displayError (getOwner (self), error);
    }

    #if WKWEBVIEW_WEBVIEWDIDCLOSE_SUPPORTED
    static void webViewDidClose (id self, SEL, WKWebView *)
    {
        getOwner (self)->windowCloseRequest ();
    }
    #endif

    static WKWebView * createWebView (id self,
                                      SEL,
                                      WKWebView *,
                                      WKWebViewConfiguration *,
                                      WKNavigationAction * navigationAction,
                                      WKWindowFeatures *)
    {
        getOwner (self)->newWindowAttemptingToLoad (
            juce::nsStringToJuce ([[[navigationAction request] URL] absoluteString]));
        return nil;
    }

    #if WKWEBVIEW_OPENPANEL_SUPPORTED
    static void runOpenPanel (id,
                              SEL,
                              WKWebView *,
                              WKOpenPanelParameters * parameters,
                              WKFrameInfo *,
                              void (^completionHandler) (NSArray<NSURL *> *))
    {
        using CompletionHandlerType = decltype (completionHandler);

        class DeletedFileChooserWrapper : private juce::DeletedAtShutdown
        {
        public:
            DeletedFileChooserWrapper (std::unique_ptr<juce::FileChooser> fc,
                                       CompletionHandlerType h)
                : chooser (std::move (fc))
                , handler (h)
            {
                [handler retain];
            }

            ~DeletedFileChooserWrapper ()
            {
                callHandler (nullptr);
                [handler release];
            }

            void callHandler (NSArray<NSURL *> * urls)
            {
                if (handlerCalled)
                    return;

                handler (urls);
                handlerCalled = true;
            }

            std::unique_ptr<juce::FileChooser> chooser;

        private:
            CompletionHandlerType handler;
            bool handlerCalled = false;
        };

        auto chooser = std::make_unique<juce::FileChooser> (
            TRANS ("Select the file you want to upload..."),
            juce::File::getSpecialLocation (juce::File::userHomeDirectory),
            "*");
        auto * wrapper = new DeletedFileChooserWrapper (std::move (chooser), completionHandler);

        auto flags = juce::FileBrowserComponent::openMode |
                     juce::FileBrowserComponent::canSelectFiles |
                     ([parameters allowsMultipleSelection]
                          ? juce::FileBrowserComponent::canSelectMultipleItems
                          : 0);

        #if (defined(MAC_OS_X_VERSION_10_14) && \
             MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_14)
        if ([parameters allowsDirectories])
            flags |= juce::FileBrowserComponent::canSelectDirectories;
        #endif

        wrapper->chooser->launchAsync (
            flags,
            [wrapper] (const juce::FileChooser &)
            {
                auto results = wrapper->chooser->getResults ();
                auto urls = [NSMutableArray arrayWithCapacity:(NSUInteger) results.size ()];

                for (auto & f : results)
                    [urls addObject:[NSURL fileURLWithPath:juceStringToNS (f.getFullPathName ())]];

                wrapper->callHandler (urls);
                delete wrapper;
            });
    }
    #endif
};

struct JaLeScriptHandler : public juce::ObjCClass<NSObject>
{
    JaLeScriptHandler ()
        : ObjCClass<NSObject> ("JaLeScriptHandler")
    {
        addIvar<WebBrowserComponent*>("owner");
        addIvar<WKWebView*>("webView");
        
        addMethod (@selector (userContentController:didReceiveScriptMessage:),
                   didRecieveScriptMessage,
                   "v@:@@");

        registerClass ();
    }

    static void
    didRecieveScriptMessage (id self, SEL, WKUserContentController * controller, WKScriptMessage * message)
    {
        juce::ignoreUnused (self, controller);
        juce::Logger::writeToLog (juce::nsStringToJuce ([[NSString alloc] initWithFormat:@"body %@ name %@", message.body, message.name]));

        if([message.name isEqualToString:@"JaLeInterop"]) {

            juce::Logger::writeToLog ("did it");
            [getWebView(self) evaluateJavaScript:@"fromApp();" completionHandler:nil];
        }
        
        if([message.name isEqualToString:@"JaLeInteropReturn"]) {

            juce::Logger::writeToLog ("returned it");
        }
    }

    static void setOwner (id self, WebBrowserComponent * owner)
    {
        object_setInstanceVariable (self, "owner", owner);
    }
    
    static WebBrowserComponent * getOwner (id self)
    {
        return juce::getIvar<WebBrowserComponent *> (self, "owner");
    }
    
    static void setWebView (id self, WKWebView * webView)
    {
        object_setInstanceVariable (self, "webView", webView);
    }
    
    static WKWebView * getWebView (id self)
    {
        return juce::getIvar<WKWebView *> (self, "webView");
    }
};

//==============================================================================
class WebBrowserComponent::Pimpl
    #if JUCE_MAC
    : public juce::NSViewComponent
    #else
    : public UIViewComponent
    #endif
{
public:
    Pimpl (WebBrowserComponent * owner)
    {
    #if JUCE_MAC
        static WebViewKeyEquivalentResponder webviewClass;
        webView = (WKWebView *) webviewClass.createInstance ();
        
        WKWebViewConfiguration* webConfiguration = [[WKWebViewConfiguration alloc] init];
        webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:webConfiguration];
        
        static JaLeScriptHandler jaleScriptHandler;
        scriptHandler = [jaleScriptHandler.createInstance() init];
        JaLeScriptHandler::setOwner (scriptHandler, owner);
        JaLeScriptHandler::setWebView (scriptHandler, webView);

        [webView.configuration.userContentController addScriptMessageHandler:scriptHandler name:@"JaLeInterop"];
        [webView.configuration.userContentController addScriptMessageHandler:scriptHandler name:@"JaLeInteropReturn"];
    #else
        webView = [[WKWebView alloc] initWithFrame:CGRectMake (0, 0, 100.0f, 100.0f)];
    #endif
       
        static WebViewDelegateClass cls;
        webViewDelegate = [cls.createInstance () init];
        WebViewDelegateClass::setOwner (webViewDelegate, owner);

        [webView setNavigationDelegate:webViewDelegate];
        [webView setUIDelegate:webViewDelegate];

        setView (webView);
    }

    ~Pimpl ()
    {
        [webView setNavigationDelegate:nil];
        [webView setUIDelegate:nil];

        [webViewDelegate release];

        setView (nil);
    }

    void goToURL (const juce::String & url,
                  const juce::StringArray * headers,
                  const juce::MemoryBlock * postData)
    {
        auto trimmed = url.trimStart ();

        if (trimmed.startsWithIgnoreCase ("javascript:"))
        {
            [webView
                evaluateJavaScript:juceStringToNS (url.fromFirstOccurrenceOf (":", false, false))
                 completionHandler:nil];

            return;
        }

        stop ();

        if (trimmed.startsWithIgnoreCase ("file:"))
        {
            auto file = juce::URL (url).getLocalFile ();

            if (NSURL * nsUrl =
                    [NSURL fileURLWithPath:juce::juceStringToNS (file.getFullPathName ())])
                [webView loadFileURL:appendParametersToFileURL (url, nsUrl)
                    allowingReadAccessToURL:nsUrl];
        }
        else if (NSMutableURLRequest * request = getRequestForURL (url, headers, postData))
        {
            [webView loadRequest:request];
        }
    }

    void goBack ()
    {
        [webView goBack];
    }
    void goForward ()
    {
        [webView goForward];
    }

    void stop ()
    {
        [webView stopLoading];
    }
    void refresh ()
    {
        [webView reload];
    }

private:
    WKWebView * webView = nil;
    id webViewDelegate;
    id scriptHandler;
};

#else

    #if JUCE_MAC

struct DownloadClickDetectorClass : public ObjCClass<NSObject>
{
    DownloadClickDetectorClass ()
        : ObjCClass<NSObject> ("JUCEWebClickDetector_")
    {
        addIvar<WebBrowserComponent *> ("owner");

        addMethod (@selector (webView:
                       decidePolicyForNavigationAction:request:frame:decisionListener:),
                   decidePolicyForNavigationAction,
                   "v@:@@@@@");
        addMethod (@selector (webView:
                       decidePolicyForNewWindowAction:request:newFrameName:decisionListener:),
                   decidePolicyForNewWindowAction,
                   "v@:@@@@@");
        addMethod (@selector (webView:didFinishLoadForFrame:), didFinishLoadForFrame, "v@:@@");
        addMethod (
            @selector (webView:didFailLoadWithError:forFrame:), didFailLoadWithError, "v@:@@@");
        addMethod (@selector (webView:didFailProvisionalLoadWithError:forFrame:),
                   didFailLoadWithError,
                   "v@:@@@");
        addMethod (@selector (webView:willCloseFrame:), willCloseFrame, "v@:@@");
        addMethod (@selector (webView:
                       runOpenPanelForFileButtonWithResultListener:allowMultipleFiles:),
                   runOpenPanel,
                   "v@:@@",
                   @encode (BOOL));

        registerClass ();
    }

    static void setOwner (id self, WebBrowserComponent * owner)
    {
        object_setInstanceVariable (self, "owner", owner);
    }
    static WebBrowserComponent * getOwner (id self)
    {
        return getIvar<WebBrowserComponent *> (self, "owner");
    }

private:
    static String getOriginalURL (NSDictionary * actionInformation)
    {
        if (NSURL * url =
                [actionInformation valueForKey:nsStringLiteral ("WebActionOriginalURLKey")])
            return nsStringToJuce ([url absoluteString]);

        return {};
    }

    static void decidePolicyForNavigationAction (id self,
                                                 SEL,
                                                 WebView *,
                                                 NSDictionary * actionInformation,
                                                 NSURLRequest *,
                                                 WebFrame *,
                                                 id<WebPolicyDecisionListener> listener)
    {
        if (getOwner (self)->pageAboutToLoad (getOriginalURL (actionInformation)))
            [listener use];
        else
            [listener ignore];
    }

    static void decidePolicyForNewWindowAction (id self,
                                                SEL,
                                                WebView *,
                                                NSDictionary * actionInformation,
                                                NSURLRequest *,
                                                NSString *,
                                                id<WebPolicyDecisionListener> listener)
    {
        getOwner (self)->newWindowAttemptingToLoad (getOriginalURL (actionInformation));
        [listener ignore];
    }

    static void didFinishLoadForFrame (id self, SEL, WebView * sender, WebFrame * frame)
    {
        if ([frame isEqual:[sender mainFrame]])
        {
            NSURL * url = [[[frame dataSource] request] URL];
            getOwner (self)->pageFinishedLoading (nsStringToJuce ([url absoluteString]));
        }
    }

    static void
    didFailLoadWithError (id self, SEL, WebView * sender, NSError * error, WebFrame * frame)
    {
        if ([frame isEqual:[sender mainFrame]] && error != nullptr &&
            [error code] != NSURLErrorCancelled)
        {
            auto errorString = nsStringToJuce ([error localizedDescription]);
            bool proceedToErrorPage = getOwner (self)->pageLoadHadNetworkError (errorString);

            // WebKit doesn't have an internal error page, so make a really simple one ourselves
            if (proceedToErrorPage)
                getOwner (self)->goToURL ("data:text/plain;charset=UTF-8," + errorString);
        }
    }

    static void willCloseFrame (id self, SEL, WebView *, WebFrame *)
    {
        getOwner (self)->windowCloseRequest ();
    }

    static void runOpenPanel (id,
                              SEL,
                              WebView *,
                              id<WebOpenPanelResultListener> resultListener,
                              BOOL allowMultipleFiles)
    {
        struct DeletedFileChooserWrapper : private DeletedAtShutdown
        {
            DeletedFileChooserWrapper (std::unique_ptr<FileChooser> fc,
                                       id<WebOpenPanelResultListener> rl)
                : chooser (std::move (fc))
                , listener (rl)
            {
                [listener retain];
            }

            ~DeletedFileChooserWrapper ()
            {
                [listener release];
            }

            std::unique_ptr<FileChooser> chooser;
            id<WebOpenPanelResultListener> listener;
        };

        auto chooser =
            std::make_unique<FileChooser> (TRANS ("Select the file you want to upload..."),
                                           File::getSpecialLocation (File::userHomeDirectory),
                                           "*");
        auto * wrapper = new DeletedFileChooserWrapper (std::move (chooser), resultListener);

        auto flags = FileBrowserComponent::openMode | FileBrowserComponent::canSelectFiles |
                     (allowMultipleFiles ? FileBrowserComponent::canSelectMultipleItems : 0);

        wrapper->chooser->launchAsync (
            flags,
            [wrapper] (const FileChooser &)
            {
                for (auto & f : wrapper->chooser->getResults ())
                    [wrapper->listener chooseFilename:juceStringToNS (f.getFullPathName ())];

                delete wrapper;
            });
    }
};

    #else

struct WebViewDelegateClass : public ObjCClass<NSObject>
{
    WebViewDelegateClass ()
        : ObjCClass<NSObject> ("JUCEWebViewDelegate_")
    {
        addIvar<WebBrowserComponent *> ("owner");

        addMethod (@selector (gestureRecognizer:
                       shouldRecognizeSimultaneouslyWithGestureRecognizer:),
                   shouldRecognizeSimultaneouslyWithGestureRecognizer,
                   "c@:@@");

        addMethod (@selector (webView:shouldStartLoadWithRequest:navigationType:),
                   shouldStartLoadWithRequest,
                   "c@:@@@");
        addMethod (@selector (webViewDidFinishLoad:), webViewDidFinishLoad, "v@:@");

        registerClass ();
    }

    static void setOwner (id self, WebBrowserComponent * owner)
    {
        object_setInstanceVariable (self, "owner", owner);
    }
    static WebBrowserComponent * getOwner (id self)
    {
        return getIvar<WebBrowserComponent *> (self, "owner");
    }

private:
    static BOOL shouldRecognizeSimultaneouslyWithGestureRecognizer (id,
                                                                    SEL,
                                                                    UIGestureRecognizer *,
                                                                    UIGestureRecognizer *)
    {
        return YES;
    }

    static BOOL shouldStartLoadWithRequest (id self,
                                            SEL,
                                            UIWebView *,
                                            NSURLRequest * request,
                                            UIWebViewNavigationType)
    {
        return getOwner (self)->pageAboutToLoad (nsStringToJuce ([[request URL] absoluteString]));
    }

    static void webViewDidFinishLoad (id self, SEL, UIWebView * webView)
    {
        getOwner (self)->pageFinishedLoading (
            nsStringToJuce ([[[webView request] URL] absoluteString]));
    }
};

    #endif

//==============================================================================
class WebBrowserComponent::Pimpl
    #if JUCE_MAC
    : public NSViewComponent
    #else
    : public UIViewComponent
    #endif
{
public:
    Pimpl (WebBrowserComponent * owner)
    {
    #if JUCE_MAC
        static WebViewKeyEquivalentResponder webviewClass;
        webView = (WebView *) webviewClass.createInstance ();

        webView = [webView initWithFrame:NSMakeRect (0, 0, 100.0f, 100.0f)
                               frameName:nsEmptyString ()
                               groupName:nsEmptyString ()];

        static DownloadClickDetectorClass cls;
        clickListener = [cls.createInstance () init];
        DownloadClickDetectorClass::setOwner (clickListener, owner);

        [webView setPolicyDelegate:clickListener];
        [webView setFrameLoadDelegate:clickListener];
        [webView setUIDelegate:clickListener];
    #else
        webView = [[UIWebView alloc] initWithFrame:CGRectMake (0, 0, 1.0f, 1.0f)];

        static WebViewDelegateClass cls;
        webViewDelegate = [cls.createInstance () init];
        WebViewDelegateClass::setOwner (webViewDelegate, owner);

        [webView setDelegate:webViewDelegate];
    #endif

        setView (webView);
    }

    ~Pimpl ()
    {
    #if JUCE_MAC
        [webView setPolicyDelegate:nil];
        [webView setFrameLoadDelegate:nil];
        [webView setUIDelegate:nil];

        [clickListener release];
    #else
        [webView setDelegate:nil];
        [webViewDelegate release];
    #endif

        setView (nil);
    }

    void goToURL (const String & url, const StringArray * headers, const MemoryBlock * postData)
    {
        if (url.trimStart ().startsWithIgnoreCase ("javascript:"))
        {
            [webView
                stringByEvaluatingJavaScriptFromString:juceStringToNS (url.fromFirstOccurrenceOf (
                                                           ":", false, false))];
            return;
        }

        stop ();

        auto getRequest = [&] () -> NSMutableURLRequest *
        {
            if (url.trimStart ().startsWithIgnoreCase ("file:"))
            {
                auto file = URL (url).getLocalFile ();

                if (NSURL * nsUrl =
                        [NSURL fileURLWithPath:juceStringToNS (file.getFullPathName ())])
                    return
                        [NSMutableURLRequest requestWithURL:appendParametersToFileURL (url, nsUrl)
                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval:30.0];

                return nullptr;
            }

            return getRequestForURL (url, headers, postData);
        };

        if (NSMutableURLRequest * request = getRequest ())
        {
    #if JUCE_MAC
            [[webView mainFrame] loadRequest:request];
    #else
            [webView loadRequest:request];
    #endif

    #if JUCE_IOS
            [webView setScalesPageToFit:YES];
    #endif
        }
    }

    void goBack ()
    {
        [webView goBack];
    }
    void goForward ()
    {
        [webView goForward];
    }

    #if JUCE_MAC
    void stop ()
    {
        [webView stopLoading:nil];
    }
    void refresh ()
    {
        [webView reload:nil];
    }
    #else
    void stop ()
    {
        [webView stopLoading];
    }
    void refresh ()
    {
        [webView reload];
    }
    #endif

    void mouseMove (const MouseEvent &)
    {
        JUCE_BEGIN_IGNORE_WARNINGS_GCC_LIKE ("-Wundeclared-selector")
        // WebKit doesn't capture mouse-moves itself, so it seems the only way to make
        // them work is to push them via this non-public method..
        if ([webView respondsToSelector:@selector (_updateMouseoverWithFakeEvent)])
            [webView performSelector:@selector (_updateMouseoverWithFakeEvent)];
        JUCE_END_IGNORE_WARNINGS_GCC_LIKE
    }

private:
    #if JUCE_MAC
    WebView * webView = nil;
    id clickListener;
    #else
    UIWebView * webView = nil;
    id webViewDelegate;
    #endif
};

#endif

//==============================================================================
WebBrowserComponent::WebBrowserComponent (bool unloadWhenHidden)
    : unloadPageWhenHidden (unloadWhenHidden)
{
    setOpaque (true);
    browser.reset (new Pimpl (this));
    addAndMakeVisible (browser.get ());
}

WebBrowserComponent::WebBrowserComponent (bool unloadWhenHidden,
                                          const juce::File &,
                                          const juce::File &)
    : WebBrowserComponent (unloadWhenHidden)
{
}

WebBrowserComponent::~WebBrowserComponent ()
{
}

//==============================================================================
void WebBrowserComponent::goToURL (const juce::String & url,
                                   const juce::StringArray * headers,
                                   const juce::MemoryBlock * postData)
{
    lastURL = url;

    if (headers != nullptr)
        lastHeaders = *headers;
    else
        lastHeaders.clear ();

    if (postData != nullptr)
        lastPostData = *postData;
    else
        lastPostData.reset ();

    blankPageShown = false;

    browser->goToURL (url, headers, postData);
}

void WebBrowserComponent::stop ()
{
    browser->stop ();
}

void WebBrowserComponent::goBack ()
{
    lastURL.clear ();
    blankPageShown = false;
    browser->goBack ();
}

void WebBrowserComponent::goForward ()
{
    lastURL.clear ();
    browser->goForward ();
}

void WebBrowserComponent::refresh ()
{
    browser->refresh ();
}

//==============================================================================
void WebBrowserComponent::paint (juce::Graphics &)
{
}

void WebBrowserComponent::checkWindowAssociation ()
{
    if (isShowing ())
    {
        reloadLastURL ();

        if (blankPageShown)
            goBack ();
    }
    else
    {
        if (unloadPageWhenHidden && ! blankPageShown)
        {
            // when the component becomes invisible, some stuff like flash
            // carries on playing audio, so we need to force it onto a blank
            // page to avoid this, (and send it back when it's made visible again).

            blankPageShown = true;
            browser->goToURL ("about:blank", nullptr, nullptr);
        }
    }
}

void WebBrowserComponent::reloadLastURL ()
{
    if (lastURL.isNotEmpty ())
    {
        goToURL (lastURL, &lastHeaders, &lastPostData);
        lastURL.clear ();
    }
}

void WebBrowserComponent::parentHierarchyChanged ()
{
    checkWindowAssociation ();
}

void WebBrowserComponent::resized ()
{
    browser->setSize (getWidth (), getHeight ());
}

void WebBrowserComponent::visibilityChanged ()
{
    checkWindowAssociation ();
}

void WebBrowserComponent::focusGained (FocusChangeType)
{
}

void WebBrowserComponent::clearCookies ()
{
    NSHTTPCookieStorage * storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];

    if (NSArray * cookies = [storage cookies])
    {
        const NSUInteger n = [cookies count];

        for (NSUInteger i = 0; i < n; ++i)
            [storage deleteCookie:[cookies objectAtIndex:i]];
    }

    [[NSUserDefaults standardUserDefaults] synchronize];
}

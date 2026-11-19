#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Ponte JS<->ObjC: intercepta chamadas brainmax://acao?json no UIWebView e
// implementa o backend (chaves, modelos, conversas, chat). Chama de volta o JS.
@interface BMWebBridge : NSObject

- (BOOL)handleURL:(NSURL *)url webView:(UIWebView *)webView;

@end
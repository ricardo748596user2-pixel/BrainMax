#import "BMViewController.h"
#import "BMWebBridge.h"

// Controlador principal: exibe a interface web (index.html) num UIWebView
// e encaminha as chamadas brainmax:// para o backend nativo (BMWebBridge).
@interface BMViewController () <UIWebViewDelegate>
@property(nonatomic, strong) UIWebView *webView;
@property(nonatomic, strong) BMWebBridge *bridge;
@end

@implementation BMViewController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.bridge = [[BMWebBridge alloc] init];

    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = NO;
    self.webView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.webView];

    // Carrega o index.html embutido nos recursos do app.
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"];
    if (htmlPath) {
        NSURL *baseURL = [NSURL fileURLWithPath:[htmlPath stringByDeletingLastPathComponent]];
        [self.webView loadHTMLString:[NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil]
                             baseURL:baseURL];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = request.URL;
    if ([url.scheme isEqualToString:@"brainmax"]) {
        return ![self.bridge handleURL:url webView:webView];
    }
    // Permite carregar o arquivo local.
    return YES;
}

@end
#import "BMAppDelegate.h"
#import "BMViewController.h"

@implementation BMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    self.window.rootViewController = [[BMViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
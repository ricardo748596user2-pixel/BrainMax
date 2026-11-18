#import "BMProvider.h"

@implementation BMProvider

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        self.nome = dict[@"nome"] ?: @"";
        self.baseURL = dict[@"baseURL"] ?: @"";
        self.modelo = dict[@"modelo"] ?: @"";
        self.chave = dict[@"chave"] ?: @"";
        self.aceitaImagem = [dict[@"aceitaImagem"] boolValue];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"nome"] = self.nome ?: @"";
    d[@"baseURL"] = self.baseURL ?: @"";
    d[@"modelo"] = self.modelo ?: @"";
    d[@"chave"] = self.chave ?: @"";
    d[@"aceitaImagem"] = @(self.aceitaImagem);
    return d;
}

- (NSString *)endpoint {
    NSString *base = self.baseURL ?: @"";
    if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    return [base stringByAppendingString:@"/chat/completions"];
}

@end
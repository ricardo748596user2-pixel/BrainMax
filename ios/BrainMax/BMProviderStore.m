#import "BMProviderStore.h"
#import "BMProvider.h"

@implementation BMProviderStore

+ (instancetype)shared {
    static BMProviderStore *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[BMProviderStore alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _provedores = [NSMutableArray array];
        [self carregar];
    }
    return self;
}

- (NSString *)arquivoProvedores {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = paths.firstObject;
    if (dir.length == 0) dir = NSTemporaryDirectory();
    return [dir stringByAppendingPathComponent:@"provedores.json"];
}

- (void)carregar {
    NSString *path = [self arquivoProvedores];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) return;
    NSArray *arr = obj[@"provedores"];
    if ([arr isKindOfClass:[NSArray class]]) {
        for (id item in arr) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                BMProvider *p = [[BMProvider alloc] initWithDictionary:item];
                [_provedores addObject:p];
            }
        }
    }
    NSNumber *ativoIdx = obj[@"ativoIdx"];
    if ([ativoIdx isKindOfClass:[NSNumber class]]) {
        NSInteger idx = [ativoIdx integerValue];
        if (idx >= 0 && idx < (NSInteger)_provedores.count) {
            _ativo = _provedores[idx];
        }
    }
}

- (void)salvar {
    NSMutableDictionary *root = [NSMutableDictionary dictionary];
    NSMutableArray *arr = [NSMutableArray array];
    for (BMProvider *p in _provedores) {
        [arr addObject:[p toDictionary]];
    }
    root[@"provedores"] = arr;
    NSInteger ativoIdx = -1;
    if (_ativo) {
        ativoIdx = (NSInteger)[_provedores indexOfObject:_ativo];
    }
    root[@"ativoIdx"] = @(ativoIdx);
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    if (data) [data writeToFile:[self arquivoProvedores] atomically:YES];
}

- (void)adicionarProvedor:(BMProvider *)provider {
    if (!provider) return;
    [_provedores addObject:provider];
    if (!_ativo) _ativo = provider;
    [self salvar];
}

- (void)removerProvedor:(NSInteger)indice {
    if (indice < 0 || indice >= (NSInteger)_provedores.count) return;
    BMProvider *p = _provedores[indice];
    [_provedores removeObjectAtIndex:indice];
    if (p == _ativo) _ativo = (_provedores.count > 0 ? _provedores[0] : nil);
    [self salvar];
}

- (void)setProvedorAtivoIndice:(NSInteger)indice {
    if (indice < 0 || indice >= (NSInteger)_provedores.count) return;
    _ativo = _provedores[indice];
    [self salvar];
}

@end
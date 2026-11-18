#import "BMHistoryStore.h"

@implementation BMHistoryStore

+ (instancetype)shared {
    static BMHistoryStore *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[BMHistoryStore alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _atual = [NSMutableArray array];
        _conversas = [NSMutableArray array];
        [self carregar];
    }
    return self;
}

- (NSString *)arquivoHistorico {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = paths.firstObject;
    if (dir.length == 0) dir = NSTemporaryDirectory();
    return [dir stringByAppendingPathComponent:@"historico.json"];
}

- (void)carregar {
    NSString *path = [self arquivoHistorico];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![obj isKindOfClass:[NSDictionary class]]) return;
    NSArray *conv = obj[@"conversas"];
    if ([conv isKindOfClass:[NSArray class]]) {
        [_conversas addObjectsFromArray:conv];
    }
    NSArray *cur = obj[@"atual"];
    if ([cur isKindOfClass:[NSArray class]]) {
        [_atual addObjectsFromArray:cur];
    }
}

- (void)salvar {
    NSMutableDictionary *root = [NSMutableDictionary dictionary];
    root[@"conversas"] = _conversas;
    root[@"atual"] = _atual;
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    if (data) [data writeToFile:[self arquivoHistorico] atomically:YES];
}

- (void)adicionarMensagem:(NSString *)texto role:(NSString *)role {
    if (texto.length == 0) return;
    NSDictionary *m = @{@"role": role ?: @"user", @"text": texto};
    [_atual addObject:m];
    [self salvar];
}

- (void)salvarConversaAtual {
    if (_atual.count == 0) return;
    [_conversas addObject:[_atual copy]];
    [_atual removeAllObjects];
    [self salvar];
}

- (void)iniciarNovaConversa {
    [self salvarConversaAtual];
}

- (void)excluirConversa:(NSInteger)indice {
    if (indice >= 0 && indice < (NSInteger)_conversas.count) {
        [_conversas removeObjectAtIndex:indice];
        [self salvar];
    }
}

- (NSString *)conteudoExibicao {
    NSMutableArray *linhas = [NSMutableArray array];
    for (NSDictionary *m in _atual) {
        NSString *role = m[@"role"];
        NSString *texto = m[@"text"];
        if ([role isEqualToString:@"user"]) {
            [linhas addObject:[@"Você: " stringByAppendingString:texto]];
        } else if ([role isEqualToString:@"assistant"]) {
            [linhas addObject:[@"IA: " stringByAppendingString:texto]];
        }
    }
    return [linhas componentsJoinedByString:@"\n\n"];
}

@end
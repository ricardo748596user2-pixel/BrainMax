#import "BMAPIClient.h"
#import "BMProvider.h"

@implementation BMAPIClient

- (instancetype)init {
    self = [super init];
    if (self) {
        _relayHost = @"192.168.15.47";
        _relayPort = 8890;
    }
    return self;
}

- (void)enviarMensagens:(NSArray *)mensagens
               provider:(BMProvider *)provider
              imagemData:(NSData *)imagemData
               completion:(BMCompletionBlock)completion {
    if (!provider || provider.chave.length == 0) {
        if (completion) completion(nil, @"Nenhum provedor ativo ou chave vazia.");
        return;
    }

    // Corpo no formato OpenAI /chat/completions.
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"model"] = provider.modelo ?: @"";
    body[@"stream"] = @(NO);

    // Converte mensagens {role,text} para o formato OpenAI.
    NSMutableArray *openaiMsgs = [NSMutableArray array];
    for (NSDictionary *m in mensagens) {
        NSString *role = m[@"role"] ?: @"user";
        NSString *texto = m[@"text"] ?: @"";
        NSDictionary *msg = @{@"role": role, @"content": texto};
        [openaiMsgs addObject:msg];
    }

    // Se houver imagem anexada e o modelo aceitar, monta content com imagem base64.
    if (imagemData && imagemData.length > 0 && provider.aceitaImagem) {
        NSMutableArray *novaMsgs = [NSMutableArray array];
        for (NSDictionary *m in openaiMsgs) {
            NSDictionary *nova = m;
            if ([m[@"role"] isEqualToString:@"user"] && novaMsgs.count == openaiMsgs.count - 1) {
                NSString *b64 = [imagemData base64EncodedStringWithOptions:0];
                NSString *dataURL = [@"data:image/jpeg;base64," stringByAppendingString:b64];
                NSArray *parts = @[
                    @{@"type": @"text", @"text": m[@"content"] ?: @""},
                    @{@"type": @"image_url", @"image_url": @{@"url": dataURL}}
                ];
                nova = @{@"role": @"user", @"content": parts};
            }
            [novaMsgs addObject:nova];
        }
        openaiMsgs = novaMsgs;
    }

    body[@"messages"] = openaiMsgs;

    NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (!payload) {
        if (completion) completion(nil, @"Erro ao montar a requisição.");
        return;
    }

    // Envelope que o relay local usa para fazer a chamada HTTPS real.
    NSMutableDictionary *envelope = [NSMutableDictionary dictionary];
    envelope[@"url"] = [provider endpoint];
    envelope[@"method"] = @"POST";
    envelope[@"auth"] = provider.chave;
    envelope[@"body"] = [NSString stringWithUTF8String:[[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding].UTF8String];
    // Segurança: se o body falhar em UTF8, envia via data.
    NSString *bodyString = [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding];
    if (!bodyString) bodyString = @"{}";
    envelope[@"body"] = bodyString;

    NSData *envData = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:nil];
    if (!envData) {
        if (completion) completion(nil, @"Erro ao montar o envelope.");
        return;
    }

    // Envia ao relay via HTTP (o iOS 9 aceita HTTP simples na rede local).
    NSString *relayURL = [NSString stringWithFormat:@"http://%@:%lu/proxy", self.relayHost, (unsigned long)self.relayPort];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:relayURL]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setHTTPBody:envData];
    [req setTimeoutInterval:150];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest = 150;
    cfg.timeoutIntervalForResource = 200;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                if (completion) completion(nil, [NSString stringWithFormat:@"Erro de rede: %@", error.localizedDescription]);
                return;
            }
            if (data.length == 0) {
                if (completion) completion(nil, @"Resposta vazia do relay.");
                return;
            }
            // O relay devolve { status, data } onde data é a resposta JSON bruta da API.
            id envObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![envObj isKindOfClass:[NSDictionary class]]) {
                if (completion) completion(nil, @"Relay respondeu em formato inesperado.");
                return;
            }
            NSInteger status = [envObj[@"status"] integerValue];
            id apiData = envObj[@"data"];
            if (status >= 400) {
                NSString *msg = [self extrairErro:apiData status:status];
                if (completion) completion(nil, msg);
                return;
            }
            NSString *texto = [self extrairTexto:apiData];
            if (completion) completion(texto, nil);
        }];
    [task resume];
}

- (NSString *)extrairTexto:(id)obj {
    if (![obj isKindOfClass:[NSDictionary class]]) return nil;
    NSArray *choices = obj[@"choices"];
    if (![choices isKindOfClass:[NSArray class]] || choices.count == 0) return nil;
    NSDictionary *first = choices[0];
    NSDictionary *message = first[@"message"];
    if ([message isKindOfClass:[NSDictionary class]]) {
        id content = message[@"content"];
        if ([content isKindOfClass:[NSString class]]) return content;
        if ([content isKindOfClass:[NSArray class]]) {
            NSMutableString *s = [NSMutableString string];
            for (id part in content) {
                if ([part isKindOfClass:[NSDictionary class]] && [part[@"type"] isEqualToString:@"text"]) {
                    [s appendString:part[@"text"] ?: @""];
                }
            }
            if (s.length > 0) return s;
        }
    }
    return nil;
}

- (NSString *)extrairErro:(id)obj status:(NSInteger)status {
    NSString *base = [NSString stringWithFormat:@"HTTP %ld", (long)status];
    if (![obj isKindOfClass:[NSDictionary class]]) return base;
    id err = obj[@"error"];
    if ([err isKindOfClass:[NSDictionary class]]) {
        NSString *message = err[@"message"];
        if (message.length > 0) return [base stringByAppendingFormat:@": %@", message];
    } else if ([err isKindOfClass:[NSString class]]) {
        return [base stringByAppendingFormat:@": %@", err];
    }
    return base;
}

@end
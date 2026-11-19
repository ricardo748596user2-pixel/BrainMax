#import "BMWebBridge.h"

// Backend nativo. Persiste chaves e conversas em JSON no Documents do app.
// As chamadas de rede (buscar modelos, chat) vão para o relay local via HTTP,
// e o relay faz HTTPS com a API real. A chave completa fica só no app (Documents).

static NSString * const kBMAcaoKeys = @"keys";
static NSString * const kBMAcaoKeyAdd = @"keyadd";
static NSString * const kBMAcaoKeyDel = @"keydel";
static NSString * const kBMAcaoModels = @"models";
static NSString * const kBMAcaoChats = @"chats";
static NSString * const kBMAcaoChatGet = @"chatget";
static NSString * const kBMAcaoChatSave = @"chatsave";
static NSString * const kBMAcaoChatDel = @"chatdel";
static NSString * const kBMAcaoChat = @"chat";

static NSString * const kBMRelayHost = @"192.168.15.47";
static NSString * const kBMRelayPort = @"8890";

@implementation BMWebBridge

- (NSString *)docsDir {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = paths.firstObject;
    if (dir.length == 0) dir = NSTemporaryDirectory();
    return dir;
}
- (NSString *)chavesFile { return [[self docsDir] stringByAppendingPathComponent:@"chaves.json"]; }
- (NSString *)conversasFile { return [[self docsDir] stringByAppendingPathComponent:@"conversas.json"]; }

- (NSMutableArray *)lerChaves {
    NSMutableArray *arr = [NSMutableArray array];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self chavesFile]]) {
        NSData *d = [NSData dataWithContentsOfFile:[self chavesFile]];
        id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if ([obj isKindOfClass:[NSArray class]]) [arr addObjectsFromArray:obj];
    }
    return arr;
}
- (void)salvarChaves:(NSArray *)chaves {
    NSData *d = [NSJSONSerialization dataWithJSONObject:chaves options:0 error:nil];
    if (d) [d writeToFile:[self chavesFile] atomically:YES];
}
- (NSMutableArray *)lerConversas {
    NSMutableArray *arr = [NSMutableArray array];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self conversasFile]]) {
        NSData *d = [NSData dataWithContentsOfFile:[self conversasFile]];
        id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if ([obj isKindOfClass:[NSArray class]]) [arr addObjectsFromArray:obj];
    }
    return arr;
}
- (void)salvarConversas:(NSArray *)conv {
    NSData *d = [NSJSONSerialization dataWithJSONObject:conv options:0 error:nil];
    if (d) [d writeToFile:[self conversasFile] atomically:YES];
}
- (NSInteger)proximoId:(NSArray *)arr {
    NSInteger max = 0;
    for (NSDictionary *x in arr) {
        if ([x[@"id"] isKindOfClass:[NSNumber class]] && [x[@"id"] integerValue] > max) max = [x[@"id"] integerValue];
    }
    return max + 1;
}

- (NSString *)keyTail:(NSString *)key {
    if (key.length <= 4) return key ?: @"";
    return [key substringFromIndex:key.length - 4];
}

// ----- Rede via relay local (HTTP) -----
- (void)viaRelay:(NSString *)path body:(NSDictionary *)body completion:(void(^)(NSDictionary *res, NSString *err))completion {
    NSString *url = [NSString stringWithFormat:@"http://%@:%@/proxy", kBMRelayHost, kBMRelayPort];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [req setHTTPBody:payload];
    [req setTimeoutInterval:150];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest = 150;
    cfg.timeoutIntervalForResource = 200;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        if (error) { if (completion) completion(nil, error.localizedDescription); return; }
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([obj isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(obj, nil);
        } else {
            if (completion) completion(nil, @"Resposta inválida do relay.");
        }
    }];
    [task resume];
}

// Detecção de vision por heurística no nome do modelo.
- (BOOL)detectVision:(NSString *)modelId {
    NSString *n = [modelId lowercaseString];
    return [n containsString:@"vision"] || [n containsString:@"vl"] || [n containsString:@"llava"]
        || [n containsString:@"gemini"] || [n containsString:@"4o"] || [n containsString:@"omni"]
        || [n containsString:@"qwen3-vl"] || [n containsString:@"claude"] || [n containsString:@"pixtral"];
}

// Busca modelos chamando GET {base}/models via relay.
- (void)buscarModelos:(NSDictionary *)chave completion:(void(^)(NSArray *models, NSString *err))completion {
    NSString *prov = chave[@"prov"];
    NSDictionary *custom = chave[@"custom"];
    NSString *base;
    if (custom && [custom isKindOfClass:[NSDictionary class]] && custom[@"url"]) {
        base = custom[@"url"];
    } else {
        base = [self baseURLParaProvedor:prov];
    }
    base = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    NSString *url = [base stringByAppendingString:@"/models"];
    NSMutableDictionary *envelope = [NSMutableDictionary dictionary];
    envelope[@"url"] = url;
    envelope[@"method"] = @"GET";
    if (chave[@"key"]) envelope[@"auth"] = chave[@"key"];
    envelope[@"body"] = @"";
    [self viaRelay:nil body:envelope completion:^(NSDictionary *res, NSString *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSInteger status = [res[@"status"] integerValue];
        id data = res[@"data"];
        if (status >= 400) {
            NSString *msg = [NSString stringWithFormat:@"Falha ao buscar modelos (HTTP %ld)", (long)status];
            if ([data isKindOfClass:[NSDictionary class]] && data[@"error"]) msg = [NSString stringWithFormat:@"%@: %@", msg, data[@"error"]];
            if (completion) completion(nil, msg);
            return;
        }
        // data tem { models: [...] } ou [{...}] — o relay devolve o corpo da API.
        NSArray *models = [self extrairModelos:data provedor:prov custom:custom];
        if (completion) completion(models, nil);
    }];
}

- (NSArray *)extrairModelos:(id)obj provedor:(NSString *)prov custom:(NSDictionary *)custom {
    NSMutableArray *outArr = [NSMutableArray array];
    NSArray *data = nil;
    if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"data"] isKindOfClass:[NSArray class]]) data = obj[@"data"];
    else if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"models"] isKindOfClass:[NSArray class]]) data = obj[@"models"];
    else if ([obj isKindOfClass:[NSArray class]]) data = obj;
    if (data) {
        for (id m in data) {
            NSString *mid = nil;
            if ([m isKindOfClass:[NSDictionary class]]) {
                mid = m[@"id"];
                if (!mid) mid = m[@"model"];
            } else if ([m isKindOfClass:[NSString class]]) {
                mid = m;
            }
            if (!mid || !mid.length) continue;
            BOOL vision = [self detectVision:mid];
            // OpenRouter: modalities com 'image'.
            if ([m isKindOfClass:[NSDictionary class]] && [m[@"modalities"] isKindOfClass:[NSArray class]] && [m[@"modalities"] containsObject:@"image"]) vision = YES;
            [outArr addObject:@{ @"id": mid, @"vision": @(vision) }];
        }
    }
    // Se for Personalizado com lista manual, usa ela.
    if (custom && [custom isKindOfClass:[NSDictionary class]] && [custom[@"manual"] isKindOfClass:[NSArray class]] && [custom[@"manual"] count]) {
        NSMutableArray *manual = [NSMutableArray array];
        for (NSString *mid in custom[@"manual"]) {
            NSString *trim = [mid stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (!trim.length) continue;
            BOOL found = NO;
            for (NSDictionary *x in outArr) if ([x[@"id"] isEqualToString:trim]) { [manual addObject:x]; found = YES; break; }
            if (!found) [manual addObject:@{ @"id": trim, @"vision": @([self detectVision:trim]) }];
        }
        if (manual.count) return manual;
    }
    return outArr;
}

- (NSString *)baseURLParaProvedor:(NSString *)prov {
    NSDictionary *map = @{
        @"OpenRouter": @"https://openrouter.ai/api/v1",
        @"Groq": @"https://api.groq.com/openai/v1",
        @"NVIDIA Build": @"https://integrate.api.nvidia.com/v1",
        @"AMD Token Lab": @"https://api.tokenlab.amd.com/v1",
        @"9Router": @"http://127.0.0.1:11434/v1"
    };
    NSString *base = map[prov];
    return base ?: @"";
}

// Envia mensagem de chat via relay.
- (void)enviarChat:(NSDictionary *)params chave:(NSDictionary *)chave completion:(void(^)(NSDictionary *res, NSString *err))completion {
    NSString *prov = chave[@"prov"];
    NSDictionary *custom = chave[@"custom"];
    NSString *base;
    if (custom && [custom isKindOfClass:[NSDictionary class]] && custom[@"url"]) base = custom[@"url"];
    else base = [self baseURLParaProvedor:prov];
    base = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    NSString *endpoint = [base stringByAppendingString:@"/chat/completions"];

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"model"] = params[@"model"] ?: @"";
    body[@"stream"] = @(NO);
    body[@"messages"] = [self montarMensagens:params[@"messages"] imagemBase64:params[@"imageBase64"]];

    NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *bodyString = [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding] ?: @"{}";

    NSMutableDictionary *envelope = [NSMutableDictionary dictionary];
    envelope[@"url"] = endpoint;
    envelope[@"method"] = @"POST";
    if (chave[@"key"]) envelope[@"auth"] = chave[@"key"];
    envelope[@"body"] = bodyString;
    [self viaRelay:nil body:envelope completion:^(NSDictionary *res, NSString *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSInteger status = [res[@"status"] integerValue];
        id data = res[@"data"];
        if (status >= 400) {
            NSString *msg = [NSString stringWithFormat:@"Erro da API (HTTP %ld)", (long)status];
            if ([data isKindOfClass:[NSDictionary class]] && data[@"error"] && [data[@"error"] isKindOfClass:[NSDictionary class]]) msg = [NSString stringWithFormat:@"%@: %@", msg, data[@"error"][@"message"] ?: @""];
            if (completion) completion(nil, msg);
            return;
        }
        NSString *reply = [self extrairResposta:data];
        if (reply) {
            if (completion) completion(@{ @"reply": reply }, nil);
        } else {
            if (completion) completion(nil, @"Resposta vazia ou formato inesperado.");
        }
    }];
}

- (NSArray *)montarMensagens:(NSArray *)msgs imagemBase64:(NSString *)img {
    NSMutableArray *openai = [NSMutableArray array];
    for (id m in msgs) {
        if ([m isKindOfClass:[NSDictionary class]]) {
            [openai addObject:@{ @"role": m[@"role"] ?: @"user", @"content": m[@"content"] ?: @"" }];
        }
    }
    if (img && img.length) {
        for (NSInteger i = (NSInteger)openai.count - 1; i >= 0; i--) {
            NSDictionary *mm = openai[i];
            if ([mm[@"role"] isEqualToString:@"user"]) {
                NSString *prev = [mm[@"content"] isKindOfClass:[NSString class]] ? mm[@"content"] : @"";
                openai[i] = @{ @"role": @"user", @"content": @[
                    @{ @"type": @"text", @"text": prev },
                    @{ @"type": @"image_url", @"image_url": @{ @"url": [NSString stringWithFormat:@"data:image/jpeg;base64,%@", img] } }
                ]};
                break;
            }
        }
    }
    return openai;
}

- (NSString *)extrairResposta:(id)obj {
    if (![obj isKindOfClass:[NSDictionary class]]) return nil;
    NSArray *choices = obj[@"choices"];
    if (![choices isKindOfClass:[NSArray class]] || !choices.count) return nil;
    NSDictionary *first = choices[0];
    NSDictionary *message = first[@"message"];
    if ([message isKindOfClass:[NSDictionary class]]) {
        id content = message[@"content"];
        if ([content isKindOfClass:[NSString class]]) return content;
    }
    return nil;
}

- (NSString *)publicKeys:(NSArray *)chaves {
    NSMutableArray *outArr = [NSMutableArray array];
    for (NSDictionary *k in chaves) {
        [outArr addObject:@{
            @"id": k[@"id"] ?: @0,
            @"prov": k[@"prov"] ?: @"",
            @"name": k[@"name"] ?: @"",
            @"keyTail": [self keyTail:k[@"key"]],
            @"models": k[@"models"] ?: @[]
        }];
    }
    return [self jsonFrom:@{ @"keys": outArr }];
}
- (NSString *)jsonFrom:(id)obj {
    NSData *d = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"{}";
}
- (void)responderJS:(UIWebView *)webView json:(NSString *)json {
    if (!json) json = @"{}";
    NSString *escaped = [json stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    NSString *js = [NSString stringWithFormat:@"window._bmCb('%@');", escaped];
    // stringByEvaluatingJavaScriptFromString: só pode rodar na main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        [webView stringByEvaluatingJavaScriptFromString:js];
    });
}

// ---------------------------------------------------------------
- (BOOL)handleURL:(NSURL *)url webView:(UIWebView *)webView {
    NSString *scheme = url.scheme;
    if (![scheme isEqualToString:@"brainmax"]) return NO;
    NSString *host = url.host ?: @"";
    NSString *query = url.query ?: @"";
    NSString *decoded = [query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *params = nil;
    if (decoded.length) {
        id obj = [NSJSONSerialization JSONObjectWithData:[decoded dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        if ([obj isKindOfClass:[NSDictionary class]]) params = obj;
    }
    if (!params) params = @{};

    if ([host isEqualToString:kBMAcaoKeys]) {
        [self responderJS:webView json:[self publicKeys:[self lerChaves]]];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoKeyAdd]) {
        NSMutableArray *chaves = [self lerChaves];
        NSInteger novoId = [self proximoId:chaves];
        NSString *prov = params[@"prov"] ?: @"";
        NSString *name = params[@"name"] ?: prov;
        NSString *key = params[@"key"] ?: @"";
        NSDictionary *custom = params[@"custom"];
        NSMutableDictionary *nova = [NSMutableDictionary dictionary];
        nova[@"id"] = @(novoId);
        nova[@"prov"] = prov;
        nova[@"name"] = name;
        nova[@"key"] = key;
        if (custom) nova[@"custom"] = custom;
        nova[@"models"] = @[];
        [chaves addObject:nova];
        [self salvarChaves:chaves];
        NSMutableDictionary *resp = [NSMutableDictionary dictionary];
        resp[@"id"] = @(novoId);
        resp[@"prov"] = prov;
        resp[@"name"] = name;
        resp[@"keyTail"] = [self keyTail:key];
        resp[@"models"] = @[];
        // Busca modelos em segundo plano e atualiza.
        __weak UIWebView *wv = webView;
        [self buscarModelos:nova completion:^(NSArray *models, NSString *err) {
            NSMutableArray *chaves2 = [self lerChaves];
            for (NSMutableDictionary *k in chaves2) {
                if ([k[@"id"] isEqualToNumber:@(novoId)]) { k[@"models"] = models ?: @[]; break; }
            }
            [self salvarChaves:chaves2];
            NSMutableDictionary *resp2 = [NSMutableDictionary dictionary];
            resp2[@"id"] = @(novoId);
            resp2[@"prov"] = prov;
            resp2[@"name"] = name;
            resp2[@"keyTail"] = [self keyTail:key];
            resp2[@"models"] = models ?: @[];
            if (err) resp2[@"error"] = err;
            [self responderJS:wv json:[self jsonFrom:resp2]];
        }];
        // Resposta imediata (será sobrescrita pela busca).
        [self responderJS:webView json:[self jsonFrom:resp]];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoKeyDel]) {
        NSInteger delId = [params[@"id"] integerValue];
        NSMutableArray *chaves = [self lerChaves];
        NSMutableArray *novas = [NSMutableArray array];
        for (NSDictionary *k in chaves) if (![k[@"id"] isEqualToNumber:@(delId)]) [novas addObject:k];
        [self salvarChaves:novas];
        [self responderJS:webView json:@"{\"ok\":true}"];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoModels]) {
        NSString *prov = params[@"prov"] ?: @"";
        NSString *key = params[@"key"] ?: @"";
        NSDictionary *custom = params[@"custom"];
        NSDictionary *tmp = @{ @"prov": prov, @"key": key, @"custom": custom ?: [NSNull null] };
        __weak UIWebView *wv = webView;
        [self buscarModelos:tmp completion:^(NSArray *models, NSString *err) {
            if (err) { [self responderJS:wv json:[self jsonFrom:@{ @"error": err }]]; return; }
            [self responderJS:wv json:[self jsonFrom:@{ @"models": models ?: @[] }]];
        }];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoChats]) {
        NSMutableArray *conv = [self lerConversas];
        NSMutableArray *outArr = [NSMutableArray array];
        for (NSDictionary *c in conv) {
            [outArr addObject:@{ @"id": c[@"id"] ?: @0, @"title": c[@"title"] ?: @"", @"date": c[@"date"] ?: @"", @"keyId": c[@"keyId"] ?: @0, @"model": c[@"model"] ?: @"" }];
        }
        [self responderJS:webView json:[self jsonFrom:@{ @"chats": outArr }]];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoChatGet]) {
        NSInteger cid = [params[@"id"] integerValue];
        NSMutableArray *conv = [self lerConversas];
        for (NSDictionary *c in conv) {
            if ([c[@"id"] isEqualToNumber:@(cid)]) {
                [self responderJS:webView json:[self jsonFrom:@{ @"chat": c }]];
                return YES;
            }
        }
        [self responderJS:webView json:@"{\"error\":\"Conversa nao encontrada\"}"];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoChatSave]) {
        NSDictionary *chat = params[@"chat"];
        if ([chat isKindOfClass:[NSDictionary class]]) {
            NSMutableArray *conv = [self lerConversas];
            NSInteger cid = [chat[@"id"] integerValue];
            if (!cid) { cid = [self proximoId:conv]; }
            NSMutableDictionary *c = [chat mutableCopy];
            c[@"id"] = @(cid);
            NSMutableArray *novas = [NSMutableArray array];
            BOOL found = NO;
            for (NSDictionary *x in conv) {
                if ([x[@"id"] isEqualToNumber:@(cid)]) { [novas addObject:c]; found = YES; }
                else [novas addObject:x];
            }
            if (!found) [novas addObject:c];
            [self salvarConversas:novas];
            [self responderJS:webView json:[self jsonFrom:@{ @"chat": c }]];
            return YES;
        }
        [self responderJS:webView json:@"{\"error\":\"Dados invalidos\"}"];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoChatDel]) {
        NSInteger cid = [params[@"id"] integerValue];
        NSMutableArray *conv = [self lerConversas];
        NSMutableArray *novas = [NSMutableArray array];
        for (NSDictionary *c in conv) if (![c[@"id"] isEqualToNumber:@(cid)]) [novas addObject:c];
        [self salvarConversas:novas];
        [self responderJS:webView json:@"{\"ok\":true}"];
        return YES;
    }
    if ([host isEqualToString:kBMAcaoChat]) {
        NSInteger keyId = [params[@"keyId"] integerValue];
        NSMutableArray *chaves = [self lerChaves];
        NSDictionary *chave = nil;
        for (NSDictionary *k in chaves) if ([k[@"id"] isEqualToNumber:@(keyId)]) { chave = k; break; }
        if (!chave) { [self responderJS:webView json:@"{\"error\":\"Chave nao encontrada\"}"]; return YES; }
        __weak UIWebView *wv = webView;
        [self enviarChat:params chave:chave completion:^(NSDictionary *res, NSString *err) {
            if (err) { [self responderJS:wv json:[self jsonFrom:@{ @"error": err }]]; return; }
            [self responderJS:wv json:[self jsonFrom:res]];
        }];
        return YES;
    }

    return NO;
}

@end
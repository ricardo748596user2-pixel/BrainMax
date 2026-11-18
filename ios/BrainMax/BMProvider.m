#import "BMProvider.h"

@implementation BMProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _modelosDisponiveis = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        self.nome = dict[@"nome"] ?: @"";
        self.baseURL = dict[@"baseURL"] ?: @"";
        self.modelo = dict[@"modelo"] ?: @"";
        self.chave = dict[@"chave"] ?: @"";
        self.aceitaImagem = [dict[@"aceitaImagem"] boolValue];
        _modelosDisponiveis = [NSMutableArray array];
        NSArray *modelos = dict[@"modelos"];
        if ([modelos isKindOfClass:[NSArray class]]) {
            [_modelosDisponiveis addObjectsFromArray:modelos];
        }
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
    d[@"modelos"] = self.modelosDisponiveis ?: @[];
    return d;
}

- (NSString *)endpoint {
    NSString *base = self.baseURL ?: @"";
    if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    return [base stringByAppendingString:@"/chat/completions"];
}

// Modelos gratuitos conhecidos de cada provedor (segundo pesquisas atuais).
+ (NSArray *)modelosPadraoParaProvedor:(NSString *)nomeProvedor {
    NSString *n = [nomeProvedor lowercaseString];
    if ([n containsString:@"openrouter"]) {
        return @[
            @"openrouter/auto",
            @"meta-llama/llama-3.3-70b-instruct:free",
            @"deepseek/deepseek-chat:free",
            @"moonshotai/kimi-k2:free",
            @"google/gemma-3-27b-it:free",
            @"nvidia/llama-3.1-nemotron-70b-instruct:free",
        ];
    }
    if ([n containsString:@"groq"]) {
        return @[
            @"llama-3.1-8b-instant",
            @"llama-3.3-70b-versatile",
            @"meta-llama/llama-4-scout-17b-16e-instruct",
            @"openai/gpt-oss-120b",
            @"openai/gpt-oss-20b",
            @"qwen/qwen3-32b",
            @"qwen/qwen3.6-27b",
            @"moonshotai/kimi-k2-instruct",
            @"groq/compound",
            @"groq/compound-mini",
        ];
    }
    if ([n containsString:@"nvidia"]) {
        return @[
            @"meta/llama-3.3-70b-instruct",
            @"deepseek-ai/deepseek-v4-flash-0731",
            @"deepseek-ai/deepseek-v4-pro-0813",
            @"google/gemma-4-31b-it",
            @"google/gemma-3-12b-it",
            @"nvidia/nemotron-3-super-120b-a12b",
            @"nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
            @"nvidia/llama-3.1-nemotron-70b-instruct",
            @"openai/gpt-oss-120b",
            @"openai/gpt-oss-20b",
            @"qwen/qwen3-32b",
            @"mistralai/mistral-nemotron",
            @"moonshotai/kimi-k2.6",
            @"microsoft/phi-4-mini-instruct",
        ];
    }
    if ([n containsString:@"amd"] || [n containsString:@"tokenlab"]) {
        return @[
            @"Gemma-4-31B-IT",
            @"DeepSeek-V4-Flash",
            @"DeepSeek-V4.1-Flash",
            @"Qwen3.8-27B",
            @"MiniCPM5-1B",
        ];
    }
    return @[];
}

@end
#import <Foundation/Foundation.h>

// Um provedor de API OpenAI-compatible configurado pelo usuário.
// Ex.: OpenRouter, Groq, NVIDIA Build, AMD Token Lab.
@interface BMProvider : NSObject

@property(nonatomic, copy) NSString *nome;      // rótulo do provedor (ex.: "Groq")
@property(nonatomic, copy) NSString *baseURL;   // base da API (sem /chat/completions)
@property(nonatomic, copy) NSString *modelo;    // id do modelo (ex.: "llama-3.3-70b-versatile")
@property(nonatomic, copy) NSString *chave;     // API key (Bearer)
@property(nonatomic, assign) BOOL aceitaImagem; // se o modelo aceita input de imagem

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

// Endpoint /chat/completions completo
- (NSString *)endpoint;

@end
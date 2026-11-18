#import <Foundation/Foundation.h>

// Um provedor de API OpenAI-compatible configurado pelo usuário.
// Ex.: OpenRouter, Groq, NVIDIA Build, AMD Token Lab.
@interface BMProvider : NSObject

@property(nonatomic, copy) NSString *nome;      // rótulo do provedor (ex.: "Groq")
@property(nonatomic, copy) NSString *baseURL;   // base da API (sem /chat/completions)
@property(nonatomic, copy) NSString *modelo;    // id do modelo (ex.: "llama-3.3-70b-versatile")
@property(nonatomic, copy) NSString *chave;     // API key (Bearer)
@property(nonatomic, assign) BOOL aceitaImagem; // se o modelo aceita input de imagem
// Modelos disponíveis (gratuitos) deste provedor, para seleção rápida.
@property(nonatomic, strong) NSMutableArray *modelosDisponiveis;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

// Modelos gratuitos conhecidos de um provedor (pelo nome).
+ (NSArray *)modelosPadraoParaProvedor:(NSString *)nomeProvedor;

// Endpoint /chat/completions completo
- (NSString *)endpoint;

@end
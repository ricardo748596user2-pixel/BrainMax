#import <Foundation/Foundation.h>

// Persistência nativa do histórico de conversa em Documents/historico.json.
@interface BMHistoryStore : NSObject

+ (instancetype)shared;

// Conversa atual: array de mensagens @{@"role":..., @"text":...}
@property(nonatomic, strong, readonly) NSMutableArray *atual;
// Conversas anteriores salvas
@property(nonatomic, strong, readonly) NSMutableArray *conversas;

- (void)adicionarMensagem:(NSString *)texto role:(NSString *)role;
- (void)salvarConversaAtual;   // arquiva a conversa atual em "conversas"
- (void)iniciarNovaConversa;
- (void)excluirConversa:(NSInteger)indice;
- (NSString *)conteudoExibicao; // join das mensagens da conversa atual

@end
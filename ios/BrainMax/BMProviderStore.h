#import <Foundation/Foundation.h>
#import "BMProvider.h"

// Gerenciamento de provedores de API salvos nativamente em Documents/provedores.json.
@interface BMProviderStore : NSObject

+ (instancetype)shared;

@property(nonatomic, strong, readonly) NSMutableArray *provedores; // de BMProvider
@property(nonatomic, strong) BMProvider *ativo;

- (void)adicionarProvedor:(BMProvider *)provider;
- (void)removerProvedor:(NSInteger)indice;
- (void)setProvedorAtivoIndice:(NSInteger)indice;
- (void)salvar;

@end
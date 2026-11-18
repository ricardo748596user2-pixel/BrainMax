#import <Foundation/Foundation.h>
#import "BMProvider.h"

// Cliente HTTP que envia ao RELAY local (que por sua vez fala HTTPS com a API).
// O iOS 9 não negocia TLS moderno com as APIs (OpenRouter/Groq/NVIDIA/AMD),
// então o app fala HTTP simples com um relay local no Windows, e esse relay
// faz a chamada HTTPS real para a API escolhida.
typedef void (^BMCompletionBlock)(NSString *resposta, NSString *erro);

@interface BMAPIClient : NSObject

// Host do relay (Windows). Padrão: 192.168.15.47
@property(nonatomic, copy) NSString *relayHost;
// Porta do relay. Padrão: 8890
@property(nonatomic, assign) NSUInteger relayPort;

- (void)enviarMensagens:(NSArray *)mensagens
               provider:(BMProvider *)provider
              imagemData:(NSData *)imagemData
               completion:(BMCompletionBlock)completion;

@end
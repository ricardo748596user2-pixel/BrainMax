#import "BMViewController.h"
#import "BMHistoryStore.h"
#import "BMProviderStore.h"
#import "BMProvider.h"
#import "BMAPIClient.h"
#import "BMProvidersController.h"

static NSString * const kBMTileColor = @"#0F172A";
static NSString * const kBMCardColor = @"#111827";
static NSString * const kBMAccentColor = @"#0D9488";

@interface BMViewController () <UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate>
@property(nonatomic, strong) UITextView *chat;
@property(nonatomic, strong) UITextView *input;
@property(nonatomic, strong) UILabel *provedorLabel;
@property(nonatomic, strong) UIButton *provedorBtn;
@property(nonatomic, strong) UIButton *modeloBtn;
@property(nonatomic, strong) UIImage *imagemAnexada;
@property(nonatomic, assign) BOOL processando;
@end

@implementation BMViewController

+ (UIColor *)corHex:(NSString *)hex {
    unsigned r = 0, g = 0, b = 0;
    if (hex.length == 7 && [hex hasPrefix:@"#"]) {
        NSScanner *sc = [NSScanner scannerWithString:[hex substringFromIndex:1]];
        unsigned long long val = 0;
        if ([sc scanHexLongLong:&val]) { r = (unsigned)((val >> 16) & 0xFF); g = (unsigned)((val >> 8) & 0xFF); b = (unsigned)(val & 0xFF); }
    }
    return [UIColor colorWithRed:(r/255.0) green:(g/255.0) blue:(b/255.0) alpha:1.0];
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [BMViewController corHex:kBMTileColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;

    // Barra de título.
    UIView *top = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 64)];
    top.backgroundColor = [BMViewController corHex:kBMCardColor];
    UILabel *titulo = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, W - 200, 40)];
    titulo.text = @"Brain Max";
    titulo.font = [UIFont boldSystemFontOfSize:24];
    titulo.textColor = [UIColor whiteColor];
    [top addSubview:titulo];

    UIButton *nova = [UIButton buttonWithType:UIButtonTypeSystem];
    nova.frame = CGRectMake(W - 116, 12, 100, 40);
    [nova setTitle:@"Nova" forState:UIControlStateNormal];
    [nova setTitleColor:[BMViewController corHex:kBMAccentColor] forState:UIControlStateNormal];
    nova.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [nova addTarget:self action:@selector(novaConversa:) forControlEvents:UIControlEventTouchUpInside];
    [top addSubview:nova];
    [self.view addSubview:top];

    // Seletor de provedor (esquerda) + botão de modelo (direita).
    UIButton *provBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    provBtn.frame = CGRectMake(16, 72, W - 150, 40);
    provBtn.backgroundColor = [BMViewController corHex:kBMCardColor];
    provBtn.layer.cornerRadius = 6;
    [provBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    provBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    provBtn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [provBtn setTitle:@"Provedores" forState:UIControlStateNormal];
    [provBtn addTarget:self action:@selector(abrirProvedores:) forControlEvents:UIControlEventTouchUpInside];
    self.provedorLabel = provBtn.titleLabel;
    [self.view addSubview:provBtn];
    self.provedorBtn = provBtn;

    UIButton *modeloBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    modeloBtn.frame = CGRectMake(W - 126, 72, 110, 40);
    modeloBtn.backgroundColor = [BMViewController corHex:kBMAccentColor];
    modeloBtn.layer.cornerRadius = 6;
    [modeloBtn setTitle:@"Modelo ▾" forState:UIControlStateNormal];
    [modeloBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    modeloBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    modeloBtn.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [modeloBtn addTarget:self action:@selector(abrirSelecaoModelo:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:modeloBtn];
    self.modeloBtn = modeloBtn;

    // Área de mensagens.
    self.chat = [[UITextView alloc] initWithFrame:CGRectMake(8, 120, W - 16, H - 120 - 120)];
    self.chat.editable = NO;
    self.chat.backgroundColor = [BMViewController corHex:kBMTileColor];
    self.chat.textColor = [UIColor whiteColor];
    self.chat.font = [UIFont systemFontOfSize:16];
    self.chat.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    [self.view addSubview:self.chat];

    // Rodapé de entrada.
    UIView *bottom = [[UIView alloc] initWithFrame:CGRectMake(0, H - 120, W, 120)];
    bottom.backgroundColor = [BMViewController corHex:kBMCardColor];

    self.input = [[UITextView alloc] initWithFrame:CGRectMake(8, 8, W - 100, 84)];
    self.input.delegate = self;
    self.input.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.input.textColor = [UIColor whiteColor];
    self.input.font = [UIFont systemFontOfSize:16];
    self.input.layer.cornerRadius = 6;
    [bottom addSubview:self.input];

    UIButton *enviar = [UIButton buttonWithType:UIButtonTypeSystem];
    enviar.frame = CGRectMake(W - 84, 8, 76, 44);
    [enviar setTitle:@"Enviar" forState:UIControlStateNormal];
    [enviar setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    enviar.backgroundColor = [BMViewController corHex:kBMAccentColor];
    enviar.layer.cornerRadius = 6;
    enviar.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [enviar addTarget:self action:@selector(enviar:) forControlEvents:UIControlEventTouchUpInside];
    [bottom addSubview:enviar];

    UIButton *cam = [UIButton buttonWithType:UIButtonTypeSystem];
    cam.frame = CGRectMake(W - 84, 60, 76, 40);
    [cam setTitle:@"Foto" forState:UIControlStateNormal];
    [cam setTitleColor:[BMViewController corHex:kBMAccentColor] forState:UIControlStateNormal];
    cam.titleLabel.font = [UIFont systemFontOfSize:15];
    [cam addTarget:self action:@selector(anexarImagem:) forControlEvents:UIControlEventTouchUpInside];
    [bottom addSubview:cam];
    [self.view addSubview:bottom];

    [self recarregarTela];
}

- (void)recarregarTela {
    BMProvider *p = [[BMProviderStore shared] ativo];
    if (p) {
        [self.provedorBtn setTitle:[NSString stringWithFormat:@"%@ — %@", p.nome, p.modelo] forState:UIControlStateNormal];
    } else {
        [self.provedorBtn setTitle:@"Provedores (nenhum ativo)" forState:UIControlStateNormal];
    }
    self.chat.text = [[BMHistoryStore shared] conteudoExibicao];
    [self.chat scrollRangeToVisible:NSMakeRange(self.chat.text.length, 0)];
}

- (void)novaConversa:(id)sender {
    [[BMHistoryStore shared] iniciarNovaConversa];
    self.chat.text = @"";
}

- (void)abrirProvedores:(id)sender {
    BMProvidersController *vc = [[BMProvidersController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

// Abre a lista de modelos disponíveis do provedor ativo.
- (void)abrirSelecaoModelo:(id)sender {
    BMProvider *p = [[BMProviderStore shared] ativo];
    if (!p) {
        [self mostrarAlerta:@"Nenhum provedor ativo. Abra Provedores e adicione uma chave."];
        return;
    }
    NSMutableArray *modelos = p.modelosDisponiveis;
    if (modelos.count == 0) {
        [self mostrarAlerta:@"Provedor sem modelos listados. Toque em + Modelo para adicionar."];
        return;
    }
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"%@ — escolha o modelo", p.nome]
        delegate:self cancelButtonTitle:@"Cancelar" destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSString *m in modelos) {
        [sheet addButtonWithTitle:m];
    }
    [sheet addButtonWithTitle:@"+ Adicionar modelo manual"];
    [sheet showInView:self.view];
}

// Seleção na lista de modelos.
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    BMProvider *p = [[BMProviderStore shared] ativo];
    if (!p) return;
    NSInteger count = (NSInteger)p.modelosDisponiveis.count;
    if (buttonIndex < count) {
        p.modelo = p.modelosDisponiveis[buttonIndex];
        [[BMProviderStore shared] salvar];
        [self recarregarTela];
        [self mostrarAlerta:[NSString stringWithFormat:@"Modelo ativo: %@", p.modelo]];
    } else if (buttonIndex == count) {
        [self adicionarModeloManual];
    }
}

// Pede um modelo manualmente e adiciona à lista do provedor ativo.
- (void)adicionarModeloManual {
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Novo modelo"
        message:@"Digite o id do modelo e toque em Salvar."
        delegate:self cancelButtonTitle:@"Cancelar" otherButtonTitles:@"Salvar", nil];
    av.alertViewStyle = UIAlertViewStylePlainTextInput;
    av.tag = 9001;
    [av show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag != 9001 || buttonIndex != 1) return;
    UITextField *tf = [alertView textFieldAtIndex:0];
    NSString *novo = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (novo.length == 0) return;
    BMProvider *p = [[BMProviderStore shared] ativo];
    if (!p) return;
    [p.modelosDisponiveis addObject:novo];
    p.modelo = novo;
    [[BMProviderStore shared] salvar];
    [self recarregarTela];
    [self mostrarAlerta:[NSString stringWithFormat:@"Modelo ativo: %@", novo]];
}

- (void)anexarImagem:(id)sender {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [self mostrarAlerta:@"Câmera não disponível"];
        return;
    }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    self.imagemAnexada = img;
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self mostrarAlerta:@"Imagem anexada. Envie a mensagem."];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)enviar:(id)sender {
    if (self.processando) return;
    NSString *texto = [self.input.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (texto.length == 0) return;
    self.processando = YES;

    // Salva a mensagem do usuário.
    [[BMHistoryStore shared] adicionarMensagem:texto role:@"user"];
    [self.input setText:@""];
    self.chat.text = [[BMHistoryStore shared] conteudoExibicao];

    BMProvider *provider = [[BMProviderStore shared] ativo];
    if (!provider) {
        [self mostrarAlerta:@"Nenhum provedor ativo. Abra Provedores e adicione uma chave."];
        self.processando = NO;
        return;
    }

    // Monta a lista de mensagens do histórico.
    NSArray *hist = [[BMHistoryStore shared] atual];

    // Converte imagem anexada em JPEG se o modelo aceitar.
    NSData *imgData = nil;
    if (self.imagemAnexada && provider.aceitaImagem) {
        imgData = UIImageJPEGRepresentation(self.imagemAnexada, 0.7);
    } else if (self.imagemAnexada && !provider.aceitaImagem) {
        self.imagemAnexada = nil;
        [self mostrarAlerta:@"Este modelo não aceita imagem. Enviada só o texto."];
    }
    self.imagemAnexada = nil;

    [self mostraProcessando:YES];
    BMAPIClient *client = [[BMAPIClient alloc] init];
    __weak typeof(self) weakSelf = self;
    [client enviarMensagens:hist provider:provider imagemData:imgData completion:^(NSString *resposta, NSString *erro) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) s = weakSelf;
            if (!s) return;
            [s mostraProcessando:NO];
            if (resposta.length > 0) {
                [[BMHistoryStore shared] adicionarMensagem:resposta role:@"assistant"];
            } else {
                [s mostrarAlerta:erro.length > 0 ? erro : @"Sem resposta."];
            }
            s.chat.text = [[BMHistoryStore shared] conteudoExibicao];
            [s.chat scrollRangeToVisible:NSMakeRange(s.chat.text.length, 0)];
            s.processando = NO;
        });
    }];
}

- (void)mostraProcessando:(BOOL)on {
    self.chat.text = [[BMHistoryStore shared] conteudoExibicao];
    if (on) self.chat.text = [self.chat.text stringByAppendingString:@"\n\n[aguardando resposta…]"];
}

- (void)mostrarAlerta:(NSString *)msg {
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Brain Max" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [av show];
}

@end
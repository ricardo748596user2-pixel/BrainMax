#import "BMProvidersController.h"
#import "BMProviderStore.h"
#import "BMProvider.h"

// Tela de gerenciamento de provedores de API.
// Permite: listar, selecionar ativo, excluir, e adicionar/editar provedores.
@interface BMProvidersController () <UITextFieldDelegate, UIScrollViewDelegate>
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) UITextField *fNome;
@property(nonatomic, strong) UITextField *fBaseURL;
@property(nonatomic, strong) UITextField *fModelo;
@property(nonatomic, strong) UITextField *fChave;
@property(nonatomic, assign) BOOL fAceitaImagem;
@property(nonatomic, assign) BOOL editando;
@property(nonatomic, assign) NSInteger editandoIndice;
@end

@implementation BMProvidersController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    self.title = @"Provedores";

    CGFloat W = self.view.bounds.size.width;

    UINavigationBar *nav = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, W, 64)];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@"Brain Max"];
    item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self action:@selector(fechar:)];
    [nav pushNavigationItem:item animated:NO];
    [self.view addSubview:nav];

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 64, W, self.view.bounds.size.height - 64)];
    self.scroll.delegate = self;
    [self.view addSubview:self.scroll];

    [self desenharLista];
    [self desenharFormulario];
}

- (void)fechar:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)desenharLista {
    for (UIView *v in self.scroll.subviews) { [v removeFromSuperview]; }
    self.scroll.contentOffset = CGPointZero;
    self.scroll.contentSize = CGSizeZero;

    CGFloat W = self.scroll.bounds.size.width;
    CGFloat y = 8;
    NSArray *provs = [[BMProviderStore shared] provedores];

    UILabel *titulo = [[UILabel alloc] initWithFrame:CGRectMake(16, y, W - 32, 30)];
    titulo.text = @"Provedores salvos";
    titulo.textColor = [UIColor whiteColor];
    titulo.font = [UIFont boldSystemFontOfSize:18];
    [self.scroll addSubview:titulo];
    y += 34;

    if (provs.count == 0) {
        UILabel *vazio = [[UILabel alloc] initWithFrame:CGRectMake(16, y, W - 32, 30)];
        vazio.text = @"Nenhum provedor ainda. Adicione um abaixo.";
        vazio.textColor = [UIColor lightGrayColor];
        vazio.font = [UIFont systemFontOfSize:14];
        [self.scroll addSubview:vazio];
        y += 34;
    }

    for (NSInteger i = 0; i < (NSInteger)provs.count; i++) {
        BMProvider *p = provs[i];
        BOOL ativo = (p == [[BMProviderStore shared] ativo]);

        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, y, W - 32, 64)];
        card.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        card.layer.cornerRadius = 6;
        [self.scroll addSubview:card];

        UILabel *nome = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, W - 120, 26)];
        nome.text = [NSString stringWithFormat:@"%@ %@", p.nome, ativo ? @"●" : @""];
        nome.textColor = ativo ? [UIColor colorWithRed:0.05 green:0.8 blue:0.75 alpha:1.0] : [UIColor whiteColor];
        nome.font = [UIFont boldSystemFontOfSize:16];
        [card addSubview:nome];

        UILabel *det = [[UILabel alloc] initWithFrame:CGRectMake(12, 32, W - 120, 22)];
        det.text = p.modelo;
        det.textColor = [UIColor lightGrayColor];
        det.font = [UIFont systemFontOfSize:13];
        [card addSubview:det];

        UIButton *excluir = [UIButton buttonWithType:UIButtonTypeSystem];
        excluir.frame = CGRectMake(W - 136, 8, 52, 44);
        [excluir setTitle:@"Apagar" forState:UIControlStateNormal];
        [excluir setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        excluir.titleLabel.font = [UIFont systemFontOfSize:14];
        excluir.tag = i;
        [excluir addTarget:self action:@selector(excluirProvedor:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:excluir];

        UIButton *selecionar = [UIButton buttonWithType:UIButtonTypeSystem];
        selecionar.frame = CGRectMake(W - 84, 8, 56, 44);
        [selecionar setTitle:ativo ? @"Ativo" : @"Usar" forState:UIControlStateNormal];
        [selecionar setTitleColor:ativo ? [UIColor colorWithRed:0.05 green:0.8 blue:0.75 alpha:1.0] : [UIColor whiteColor] forState:UIControlStateNormal];
        selecionar.titleLabel.font = [UIFont systemFontOfSize:14];
        selecionar.tag = i;
        [selecionar addTarget:self action:@selector(usarProvedor:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:selecionar];

        y += 70;
    }
    self.scroll.contentSize = CGSizeMake(W, y);
}

- (void)desenharFormulario {
    CGFloat W = self.scroll.bounds.size.width;
    CGFloat y = self.scroll.contentSize.height + 8;

    UILabel *titulo = [[UILabel alloc] initWithFrame:CGRectMake(16, y, W - 32, 30)];
    titulo.text = self.editando ? @"Editar provedor" : @"Adicionar provedor";
    titulo.textColor = [UIColor whiteColor];
    titulo.font = [UIFont boldSystemFontOfSize:18];
    [self.scroll addSubview:titulo];
    y += 34;

    self.fNome = [self campo:CGRectMake(16, y, W - 32, 44) placeholder:@"Nome (ex.: Groq)"];
    y += 52;
    self.fBaseURL = [self campo:CGRectMake(16, y, W - 32, 44) placeholder:@"Base URL (ex.: https://api.groq.com/openai/v1)"];
    y += 52;
    self.fModelo = [self campo:CGRectMake(16, y, W - 32, 44) placeholder:@"Modelo (ex.: llama-3.3-70b-versatile)"];
    y += 52;
    self.fChave = [self campo:CGRectMake(16, y, W - 32, 44) placeholder:@"Chave API (Bearer)"];
    y += 52;

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(16, y + 6, 60, 30)];
    sw.on = self.fAceitaImagem;
    [sw addTarget:self action:@selector(switchImagem:) forControlEvents:UIControlEventValueChanged];
    [self.scroll addSubview:sw];

    UILabel *lblImagem = [[UILabel alloc] initWithFrame:CGRectMake(84, y, W - 100, 44)];
    lblImagem.text = @"Modelo aceita imagem";
    lblImagem.textColor = [UIColor whiteColor];
    lblImagem.font = [UIFont systemFontOfSize:15];
    [self.scroll addSubview:lblImagem];
    y += 52;

    UIButton *salvar = [UIButton buttonWithType:UIButtonTypeSystem];
    salvar.frame = CGRectMake(16, y, W - 32, 48);
    salvar.backgroundColor = [UIColor colorWithRed:0.05 green:0.8 blue:0.75 alpha:1.0];
    salvar.layer.cornerRadius = 6;
    [salvar setTitle:self.editando ? @"Salvar alterações" : @"Adicionar provedor" forState:UIControlStateNormal];
    [salvar setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    salvar.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [salvar addTarget:self action:@selector(salvar:) forControlEvents:UIControlEventTouchUpInside];
    [self.scroll addSubview:salvar];
    y += 58;

    if (self.editando) {
        UIButton *cancelar = [UIButton buttonWithType:UIButtonTypeSystem];
        cancelar.frame = CGRectMake(16, y, W - 32, 44);
        [cancelar setTitle:@"Cancelar edição" forState:UIControlStateNormal];
        [cancelar setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [cancelar addTarget:self action:@selector(cancelarEdicao:) forControlEvents:UIControlEventTouchUpInside];
        [self.scroll addSubview:cancelar];
        y += 52;
    }

    self.scroll.contentSize = CGSizeMake(W, y);
}

- (UITextField *)campo:(CGRect)frame placeholder:(NSString *)placeholder {
    UITextField *f = [[UITextField alloc] initWithFrame:frame];
    f.placeholder = placeholder;
    f.textColor = [UIColor whiteColor];
    f.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    f.borderStyle = UITextBorderStyleRoundedRect;
    f.font = [UIFont systemFontOfSize:14];
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.delegate = self;
    [self.scroll addSubview:f];
    return f;
}

- (void)switchImagem:(UISwitch *)sw {
    self.fAceitaImagem = sw.on;
}

- (void)excluirProvedor:(UIButton *)sender {
    NSInteger i = sender.tag;
    [[BMProviderStore shared] removerProvedor:i];
    [self desenharLista];
    [self desenharFormulario];
}

- (void)usarProvedor:(UIButton *)sender {
    [[BMProviderStore shared] setProvedorAtivoIndice:sender.tag];
    [self desenharLista];
    [self desenharFormulario];
}

- (void)salvar:(id)sender {
    NSString *nome = self.fNome.text;
    NSString *base = self.fBaseURL.text;
    NSString *modelo = self.fModelo.text;
    NSString *chave = self.fChave.text;
    if (nome.length == 0 || base.length == 0 || modelo.length == 0 || chave.length == 0) {
        [self alerta:@"Preencha todos os campos."];
        return;
    }
    BMProvider *p = [[BMProvider alloc] init];
    p.nome = nome;
    p.baseURL = base;
    p.modelo = modelo;
    p.chave = chave;
    p.aceitaImagem = self.fAceitaImagem;
    if (self.editando) {
        [[BMProviderStore shared] removerProvedor:self.editandoIndice];
        [[BMProviderStore shared] adicionarProvedor:p];
        self.editando = NO;
    } else {
        [[BMProviderStore shared] adicionarProvedor:p];
    }
    self.fNome.text = self.fBaseURL.text = self.fModelo.text = self.fChave.text = @"";
    self.fAceitaImagem = NO;
    [self desenharLista];
    [self desenharFormulario];
}

- (void)cancelarEdicao:(id)sender {
    self.editando = NO;
    self.fNome.text = self.fBaseURL.text = self.fModelo.text = self.fChave.text = @"";
    self.fAceitaImagem = NO;
    [self desenharLista];
    [self desenharFormulario];
}

- (void)alerta:(NSString *)msg {
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Brain Max" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [av show];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

@end
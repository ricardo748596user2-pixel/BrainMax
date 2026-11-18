# Brain Max

App de chat nativo (Objective-C/UIKit) para **iPad 2 / iOS 9.3.5**.

- Guarda **histórico de conversa de forma nativa** (JSON em `Documents/` do app).
- Funciona com **chaves de API gratuitas** de vários provedores OpenAI-compatible:
  - **OpenRouter**, **Groq**, **NVIDIA Build**, **AMD Token Lab**.
- Permite **adicionar, excluir e guardar várias chaves**, escolher o provedor/modelo
  ativo, e **enviar imagem** quando o modelo aceitar.

## Por que um relay local?

O iPad 2 / iOS 9.3 **não negocia TLS moderno** com as APIs atuais (OpenRouter, Groq,
NVIDIA, AMD ficam atrás de CDNs que exigem TLS/ciphers que o iOS 9 não oferece). Por
isso o app fala **HTTP simples** com um **relay local** que roda no Windows, e esse
relay faz a chamada **HTTPS real** para a API escolhida.

```
iPad (app Brain Max) --HTTP--> Windows (relay 8890) --HTTPS--> API (OpenRouter/Groq/NVIDIA/AMD)
```

As **chaves de API ficam salvas no iPad**; o relay só repassa e não persiste nada.

## Build

Feito em GitHub Actions (mesmo caminho validado do PadControl):
- Clang `--target=armv7-apple-ios9.3`, SDK iPhoneOS 9.3, ld64 (cctools-port), `ldid -S`.
- Gera `Payload/BrainMax.app` empacotado em `BrainMax-iOS9-armv7.ipa`.

Workflow: `.github/workflows/build-ipa.yml` (dispara em `push` para `ios/**`).

## Instalação no iPad (SSH/SCP + ipainstaller)

```
scp BrainMax-iOS9-armv7.ipa root@<ipad>:/tmp/BrainMax.ipa
ssh root@<ipad> "cd /tmp && ipainstaller BrainMax.ipa"
```

## Como usar

1. Inicie o relay no Windows: `relay\iniciar-relay.cmd` (porta 8890).
2. No app (iPad), abra **Provedores** e **Adicionar** um provedor:
   - **Nome**: rótulo (ex.: "Groq")
   - **Base URL**: URL da API **sem** `/chat/completions`
   - **Modelo**: id do modelo
   - **Chave**: sua API key
   - **Modelo aceita imagem**: ligue se o modelo aceitar imagem
3. Toque **Usar** para ativar.
4. Digite no campo de chat e toque **Enviar**.

### Base URLs (exemplos)

| Provedor | Base URL |
|----------|----------|
| OpenRouter | `https://openrouter.ai/api/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| NVIDIA Build | `https://integrate.api.nvidia.com/v1` |
| AMD Token Lab | o endpoint que a sua conta AMD fornecer |

## Estrutura

- `ios/BrainMax/` — fontes do app (Objective-C/UIKit)
- `ios/icons/` — ícones (gerados do `iconebrainmax.png`)
- `relay/` — relay local Node (sem dependências externas)
- `.github/workflows/build-ipa.yml` — build ARMv7/iOS 9.3

## Notas de rede

- O iPad precisa alcançar o Windows na rede local. O app usa o host padrão
  `192.168.15.47:8890` para o relay (constante `relayHost`/`relayPort` em
  `BMAPIClient.m`). Se o IP mudar, ajuste ali.
- A abertura do app em iOS 9.3.x usa USBMux + DeveloperDiskImage + DVT
  (`pymobiledevice3 developer dvt launch com.ricardo.brainmax`).
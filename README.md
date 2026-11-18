# Brain Max

App de chat nativo (Objective-C/UIKit) para iPad 2 / iOS 9.3.5.

- Guarda histórico de conversa de forma nativa (JSON em `Documents/`).
- Funciona com chaves de API gratuitas de vários provedores OpenAI-compatible:
  - OpenRouter
  - Groq
  - NVIDIA Build (NIM)
  - AMD Token Lab
- Permite adicionar, excluir e guardar várias chaves, escolher o provedor/modelo ativo,
  e enviar imagem quando o modelo aceitar.

## Build
Feito em GitHub Actions (mesmo caminho validado do PadControl):
- Clang `--target=armv7-apple-ios9.3`, SDK iPhoneOS 9.3, ld64 (cctools-port), `ldid -S`.
- Gera `Payload/BrainMax.app` empacotado em `BrainMax-iOS9-armv7.ipa`.

## Instalação (SSH/SCP + ipainstaller)
```
scp BrainMax-iOS9-armv7.ipa root@<ipad>:/tmp/BrainMax.ipa
ssh root@<ipad> "cd /tmp && ipainstaller BrainMax.ipa"
```
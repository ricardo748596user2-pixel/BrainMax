# Brain Max — relay local

O iPad 2 / iOS 9.3 não negocia TLS moderno com as APIs (OpenRouter, Groq, NVIDIA,
AMD). Por isso o app **Brain Max** no iPad fala **HTTP simples** com este relay (que
roda no Windows, na rede local), e o relay faz a chamada **HTTPS real** para a API
escolhida.

## Como iniciar (no Windows)

```bat
relay\iniciar-relay.cmd
```

ou manualmente:

```bat
cd relay
node server.js
```

O relay escuta em `0.0.0.0:8890`. Porta configurável por `BRAINMAX_PORT`.

## Como o app usa

1. No app (iPad), abra **Provedores** e adicione um provedor:
   - **Nome**: rótulo (ex.: "Groq")
   - **Base URL**: a URL da API **sem** `/chat/completions`
   - **Modelo**: id do modelo
   - **Chave**: sua API key
   - **Modelo aceita imagem**: ligue se o modelo aceitar imagem
2. Toque **Usar** no provedor para torná-lo o ativo.
3. Digite no campo de chat e toque **Enviar**.

## Endpoints do relay

- `GET /health` → `{ ok: true, name: 'brainmax-relay' }`
- `POST /proxy` → recebe `{ url, method, auth, body }`, faz a chamada HTTPS real e
  devolve `{ status, data }`.

## Provedores OpenAI-compatible suportados (endpoints de exemplo)

| Provedor | Base URL |
|----------|----------|
| OpenRouter | `https://openrouter.ai/api/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| NVIDIA Build | `https://integrate.api.nvidia.com/v1` |
| AMD Token Lab | o endpoint que a sua conta AMD fornecer |

## Chaves de API

As chaves ficam **salvas no iPad** (em `Documents/provedores.json` do app). O relay
só repassa a chave de cada requisição e não persiste nada.

## Notas

- O iPad precisa alcançar o Windows na rede local. Se o relay estiver na porta 8890,
  o app usa o host padrão `192.168.15.47`. Se o IP mudar, ajuste a constante
  `relayHost` em `BMAPIClient.m` (ou exponha um campo de configuração).
- O relay usa apenas Node.js nativo (`http`/`https`), sem `npm install`.
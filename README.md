# Brain Max

Chat de IA para **iPad 2 / iOS 9.3.5** com **interface web** servida por um **servidor local no PC**.

O iPad (Safari iOS 9, sem fetch/async/ES6) só abre uma página e fala com o servidor via HTTP.
Quem chama as APIs dos provedores é o servidor do PC — o iPad nunca faz HTTPS moderno.

## Como iniciar o servidor (no PC)

1. Instale o Node.js (se não tiver).
2. Na pasta do projeto:

```bat
iniciar-web.cmd
```

ou:

```bat
node server.js
```

O servidor escuta em `0.0.0.0:8890`.

## Endereço para abrir no iPad

Abra no Safari do iPad:

```
http://<IP-DESTE-PC>:8890
```

Exemplo: se o IP do PC for `192.168.15.47`:

```
http://192.168.15.47:8890
```

## O que a interface faz

- **Seletor de modelo no topo**, agrupado por chave de API (cada chave tem apelido e provedor).
- **Tela "Chaves de API"**: listar, excluir e adicionar chaves. Ao adicionar, escolhe o provedor,
  coloca apelido e chave, e o servidor busca **todos os modelos disponíveis** do provedor.
  Pode haver **várias chaves do mesmo provedor**.
- **Provedores prontos**: OpenRouter, 9Router, AMD Token Lab, NVIDIA Build, Groq.
  Mais **Personalizado** (nome + URL base OpenAI-compatible + lista manual de modelos opcional).
- **Painel de histórico à direita**: conversas por data, abrir e continuar o contexto,
  excluir, nova conversa.
- **Anexo de imagem**: o clipe só funciona se o modelo aceitar imagem; reduz antes de enviar.
- **Tema claro/escuro**.

## Segurança e dados

- As **chaves de API** ficam salvas em `data/keys.json` no **PC** (nunca no navegador).
  O servidor devolve ao navegador apenas o **apelido** e os **últimos 4 caracteres** da chave.
- As **conversas** ficam em `data/chats.json` no PC.
- A pasta `data/` não é versionada (não sobe para o GitHub).

## Provedores prontos (base URL no servidor)

| Provedor | Base URL |
|----------|----------|
| OpenRouter | `https://openrouter.ai/api/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| NVIDIA Build | `https://integrate.api.nvidia.com/v1` |
| AMD Token Lab | `https://api.tokenlab.amd.com/v1` |
| 9Router | `http://127.0.0.1:11434/v1` (padrão local, configurável via `BRAINMAX_NINEROUTER`) |

## Estrutura

- `server.js` — servidor local Node (chaves, modelos, conversas, chat; CORS p/ rede local)
- `web/index.html` — interface (visual)
- `web/app.js` — lógica do frontend (ES5, XMLHttpRequest)
- `data/` — chaves e conversas salvas (não versionado)
- `ios/` — versão anterior do app nativo Objective-C (não usada na nova interface)

## Endpoints do servidor

- `GET/POST/DELETE /keys` — listar / adicionar (busca modelos) / excluir chaves
- `POST /models` — buscar modelos de um provedor com uma chave (sem salvar)
- `GET/POST/DELETE /chats` — listar / salvar / excluir conversas
- `GET /chats/:id` — ler conversa (com mensagens)
- `POST /chat` — enviar mensagem: recebe histórico + modelo + chave, chama a API, devolve resposta
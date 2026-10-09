# Descobertas de qualidade e decisões técnicas

## Resumo da auditoria

| Indicador | Resultado |
|---|---:|
| Sessões identificadas | 360.129 |
| Sessões com canal completo | 264.810 (73,53%) |
| Sessões sem source | 95.318 |
| Sessões com múltiplas sources | 63.540 |
| Eventos de compra | 5.692 |
| Compras canônicas | 5.372 |
| Linhas de compra excedentes | 320 |
| IDs válidos | 4.786 linhas |
| IDs placeholder | 883 linhas |
| IDs ausentes | 23 linhas |

## ADR-001 — Origem do canal da sessão

**Contexto:** o dataset histórico não contém `collected_traffic_source`.
Os parâmetros `source`, `medium` e `campaign` aparecem em eventos como
`page_view`, mas não em `session_start`.

**Decisão:** reconstruir o canal usando o primeiro evento da sessão que possua
`source` e `medium` completos, após excluir autorreferências conhecidas.

**Autorreferências identificadas:**

- `shop.googlemerchandisestore.com / referral`
- `googlemerchandisestore.com / referral`

**Motivo:** a maior transição observada foi
`google / organic → shop.googlemerchandisestore.com / referral`, responsável
por 33,71% das sessões com mudança de canal. Usar o último evento atribuiria
aquisição ao próprio site.

## ADR-002 — Chave canônica da compra

**Problema:** `transaction_id` não é globalmente confiável na amostra
ofuscada. O placeholder `(not set)` aparece em 883 linhas e outros IDs colidem
entre usuários distintos.

**Decisão:**

- ID válido: `user_pseudo_id + transaction_id`;
- ID ausente ou placeholder: `user_pseudo_id + event_timestamp`.

A estratégia produziu 5.372 chaves canônicas. Restaram 314 chaves repetidas,
com 320 linhas excedentes, mas sem qualquer conflito de usuário, sessão ou
receita. Essas linhas podem ser deduplicadas mantendo o primeiro evento.

## Tratamento semântico de valores especiais

| Valor | Tratamento |
|---|---|
| `(direct) / (none)` | tráfego direto identificado |
| `(data deleted)` | informação removida |
| `<Other>` | valor agregado/ofuscado |
| `NULL` | informação ausente |
| autorreferência interna | removida da escolha do canal externo |

Essas categorias não serão agrupadas entre si para evitar perda de informação
de qualidade.

# Etapa 1 — Auditoria do dado bruto

Esta etapa cria a linha de base de qualidade antes da modelagem de sessões,
jornadas ou atribuição. Nenhum resultado de negócio deve ser publicado antes
dessas verificações.

## Como executar

Abra o BigQuery Studio e execute, nesta ordem:

1. `sql/00_audit/00_dataset_profile.sql`
2. `sql/00_audit/01_channel_field_audit.sql`
3. `sql/00_audit/02_purchase_integrity.sql`

Salve os resultados de cada consulta. Eles serão usados para definir o contrato
das camadas Silver.

## Decisões bloqueadas até a auditoria

- chave canônica da compra;
- regra de deduplicação de `transaction_id`;
- estratégia de preenchimento do canal por sessão;
- tratamento de `direct / none`, valores ausentes e `gclid`;
- reconciliação entre receita bruta e receita deduplicada;
- tratamento de compras sem sessão ou usuário;
- janela de atribuição e regra para compras recorrentes.

## Critérios mínimos esperados

| Regra | Expectativa |
|---|---|
| Período lido | 2020-11-01 a 2021-01-31 |
| Chave de sessão | `user_pseudo_id + ga_session_id` |
| Chave preferencial de compra | `transaction_id` |
| Receita negativa | deve ser investigada |
| Transação duplicada | deve ser deduplicada explicitamente |
| Soma dos créditos | deve reconciliar com as conversões elegíveis |
| Soma da receita atribuída | deve reconciliar com a receita elegível |

## Por que o modelo atual será substituído

As consultas originais utilizam `traffic_source.source` e
`traffic_source.medium` em cada sessão. Esses campos descrevem a aquisição
inicial do usuário e não devem ser assumidos como o canal observado em todas as
sessões posteriores. A auditoria compara esses campos com
`collected_traffic_source` para quantificar o risco antes da reconstrução.

## Próxima etapa

Depois de registrar os três resultados, construir:

- `stg_ga4_events`;
- `int_sessions`;
- `int_purchases`;
- testes de unicidade, completude e reconciliação.

A camada de visualização será um dashboard HTML publicado no GitHub Pages,
alimentado apenas por dados Gold agregados. Nenhuma credencial do BigQuery será
exposta no navegador.

# 📊 GA4 Multi-Touch Attribution Analysis

Análise comparativa de modelos de atribuição multi-touch usando o dataset público
`ga4_obfuscated_sample_ecommerce` do BigQuery. Todo o projeto roda 100% em SQL,
sem instalação local, usando apenas BigQuery Sandbox (gratuito).

---

## 🎯 Objetivo

Comparar três modelos de atribuição de conversão e discutir onde cada um erra:

| Modelo | Lógica |
|--------|--------|
| **Last-Click** | 100% do crédito para o último canal antes da compra |
| **Linear** | Crédito igual entre todos os canais tocados |
| **Time-Decay** | Mais crédito para canais próximos da conversão (meia-vida: 7 dias) |

---

## 🗂️ Estrutura do Repositório

```
ga4-multi-touch-attribution/
│
├── sql/
│   ├── 01_explore_schema.sql   # Exploração do dataset
│   ├── 02_last_click.sql       # Modelo Last-Click
│   ├── 03_linear.sql           # Modelo Linear
│   ├── 04_time_decay.sql       # Modelo Time-Decay
│   └── 05_comparison.sql       # Comparação lado a lado
└── README.md
```

---

## 📦 Dataset

- **Fonte:** `bigquery-public-data.ga4_obfuscated_sample_ecommerce`
- **Total de eventos:** 4.295.584
- **Evento de conversão:** `purchase` (5.692 ocorrências)
- **Período:** Out/2020 – Jan/2021

### Funil de conversão identificado

| Etapa | Evento | Volume |
|-------|--------|--------|
| 1 | `page_view` | 1.350.428 |
| 2 | `view_item` | 386.068 |
| 3 | `add_to_cart` | 58.543 |
| 4 | `begin_checkout` | 38.757 |
| 5 | `add_shipping_info` | 19.722 |
| 6 | `add_payment_info` | 13.899 |
| 7 ⭐ | `purchase` | **5.692** |

---

## 📈 Resultados

### Comparação dos 3 Modelos (conversões atribuídas)

| Canal | Last-Click | Linear | Time-Decay | Δ LC→Linear |
|-------|-----------|--------|------------|-------------|
| google / organic | 1.440 | 1.556 | 1.535 | **+8,1%** |
| direct / none | 1.244 | 1.255 | 1.247 | +0,9% |
| data deleted | 814 | 642 | 690 | **-21,1%** |
| google store / referral | 686 | 603 | 614 | **-12,1%** |
| Other / Other | 604 | 679 | 660 | +12,4% |
| Other / referral | 551 | 550 | 553 | -0,2% |
| google / cpc | 165 | 202 | 193 | **+22,4%** |
| Other / organic | 112 | 127 | 122 | +13,4% |

---

## 🔍 Análise: Onde Cada Modelo Erra

### ❌ Last-Click
- **Injusto com canais de descoberta:** `google/organic` perde 8% de crédito
  que merece por iniciar jornadas.
- **Injusto com CPC pago:** `google/cpc` perde 22% de crédito — o anúncio
  pago frequentemente traz o usuário no meio da jornada, mas quem "fecha"
  é o direct ou organic. Decisões de budget baseadas em Last-Click
  subinvestem em mídia paga.
- **Superestima o último touchpoint:** canais que aparecem no final da
  jornada (referral da Google Store) ganham crédito desproporcional.

### ❌ Linear
- **Ignora posição na jornada:** trata uma visita orgânica de 30 dias
  antes da compra igual à sessão do dia da compra. Na prática, o canal
  que fechou a venda tem mais relevância operacional.
- **Dilui canais de alto valor:** em jornadas longas (5+ sessões),
  até o canal que converteu recebe apenas 20% do crédito.
- **Não reflete comportamento real:** usuários não são influenciados
  igualmente por todos os pontos de contato.

### ❌ Time-Decay
- **Penaliza estratégias de awareness:** campanhas de branding e
  SEO que plantam a semente da compra semanas antes são
  sistematicamente desvalorizadas.
- **Viesado para canais de retargeting:** remarketing e direct
  sempre aparecem no final da jornada e ganham crédito excessivo,
  podendo inflar seu ROI percebido.
- **Meia-vida arbitrária:** o valor de 7 dias (padrão do GA)
  não tem base empírica para todos os negócios. Produtos de
  ciclo de compra longo (B2B, imóveis) exigem meia-vida maior.

---

## 🏆 Qual modelo usar?

> **Nenhum modelo regra-based é perfeito.** A recomendação de engenharia
> é usar modelos data-driven (como o próprio GA4 oferece via ML),
> mas entender os modelos clássicos é fundamental para interpretar
> e questionar qualquer resultado de atribuição.

| Cenário | Modelo recomendado |
|---------|-------------------|
| E-commerce com ciclo curto (< 1 dia) | Last-Click |
| Jornadas multi-canal equilibradas | Linear |
| Foco em canais de fechamento | Time-Decay |
| Decisão estratégica de budget | **Data-Driven (ML)** |

---

## 🚀 Como reproduzir

1. Acesse [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Nenhuma configuração adicional necessária — o dataset é público
3. Execute os arquivos da pasta `sql/` na ordem numérica

**Custo:** $0 (BigQuery Sandbox + dataset público)

---

## 🛠️ Stack

- **Query engine:** Google BigQuery (SQL)
- **Dataset:** GA4 Obfuscated Sample E-commerce (público)
- **Versionamento:** GitHub
- **Custo total:** Gratuito

---

## 👤 Autor

**Alexandre Santos Rodrigues**  
[GitHub](https://github.com/AlexandreSantosRodrigues)

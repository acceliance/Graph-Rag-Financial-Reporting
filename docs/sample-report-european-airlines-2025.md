# European airlines: credit comparison and lender watchlist, 2025 reports

A sample of what an AI agent produces from the graph. Claude (model Fable 5.2) wrote it on 25 November 2026 by querying the Graph-RAG MCP endpoint (`cypher_read` on the graph built with [`model/financial-reporting-model.json`](../model/financial-reporting-model.json)). It combines two readers' views: the credit analyst's comparison and the private debt fund's watchlist.

Scope: the 2025 annual reports of four groups, 1,400 pages in all. Lufthansa Group is not covered, because its reports were not in the graph on that date.

Every figure below was read from the graph with its page, then checked against that page of the PDF. Pages are PDF page numbers. This is analysis support, not investment advice, and it gives no rating.

## Summary

- **Two groups carry net debt, two hold net cash.** Air France-KLM reports net debt of EUR 8,392 million (1.66x EBITDA) and IAG EUR 5,948 million (0.8x). Ryanair reports net cash of EUR 1,304 million and easyJet GBP 602 million.
- **No group reports a covenant breach.** Air France-KLM describes tested covenants and states they were met. IAG states it has no financial covenants. The Ryanair and easyJet 2025 reports describe none in the graph.
- **Debt due within 24 months is covered by stated liquidity in all four**, from 2% of liquidity at easyJet to 53% at Ryanair.
- **The largest future cash need is aircraft, not debt.** Firm orders and capital commitments exceed financial debt at every group.
- **Watchlist: no borrower on alert.** Air France-KLM is on watch for leverage and the weight of its order book; the other three show no adverse change.

## Headline figures

Amounts in millions, in each group's reporting currency, as printed.

| | Air France-KLM | IAG | Ryanair | easyJet |
|---|---|---|---|---|
| Report | URD 2025 | Annual Report 2025 | Annual Report 2025 | Annual Report 2025 |
| Year end | 31 Dec 2025 | 31 Dec 2025 | 31 Mar 2025 | 30 Sep 2025 |
| Currency | EUR | EUR | EUR | GBP |
| Revenue | 33,007 (p.368) | 33,213 (p.154) | 13,948.5 (p.163) | 10,106 (p.145) |
| Operating result | 2,004 (p.368) | 5,024 (p.154) | 1,558.0 (p.163) | 696 (p.145) |
| Net result | 1,754 (p.368) | 3,342 (p.154) | 1,611.6 (p.163) | 494 (p.145) |
| Audit opinion | Unqualified | Not captured in the graph | Unqualified | Unqualified |

Computed operating margin (operating result ÷ revenue, rounded to one decimal): Air France-KLM 2,004 ÷ 33,007 = 6.1%; IAG 5,024 ÷ 33,213 = 15.1%; Ryanair 1,558.0 ÷ 13,948.5 = 11.2%; easyJet 696 ÷ 10,106 = 6.9%.

## Debt and liquidity

| | Air France-KLM | IAG | Ryanair | easyJet |
|---|---|---|---|---|
| Net debt, or net cash | Net debt 8,392 (p.452) | Net debt 5,948 (p.41) | Net cash 1,304 (p.4) | Net cash 602 (p.176) |
| Net debt / EBITDA, as stated | 1.66x (p.374) | 0.8x (p.41) | Not applicable | Not applicable |
| Borrowings excluding leases | 15,250 gross financial liabilities (p.452) | 14,267 gross debt, leases included (p.41) | 2,682.7 debt and leases (p.295) | 1,881 (p.176) |
| Lease liabilities | 6,445 (p.452) | 6,995 (p.190) | 149.1 (p.295) | 1,045 (p.176) |
| Liquidity, as each group defines it | EUR 9.4 billion of available cash, including 2.5 billion of undrawn facilities (p.194) | 10,948 total liquidity (p.43) | 3,986.5 gross cash (p.330) | 4,791 total liquidity (p.181) |

## Debt due within 24 months against liquidity

| | Due within 1 year | Due in 1 to 2 years | Computed: sum | Computed: share of stated liquidity |
|---|---|---|---|---|
| Air France-KLM, financial liabilities (p.450) | 2,113 | 959 | 3,072 | 3,072 ÷ 9,400 = 33% |
| IAG, borrowings and leases (p.191) | 1,960 | 1,822 | 3,782 | 3,782 ÷ 10,948 = 35% |
| Ryanair, financial liabilities (p.295) | 885.8 | 1,234.2 | 2,120.0 | 2,120.0 ÷ 3,986.5 = 53% |
| easyJet, borrowings principal and interest (p.181) | 47 | 47 | 94 | 94 ÷ 4,791 = 2% |

## Covenants

| Group | What the 2025 report states |
|---|---|
| Air France-KLM | Its revolving credit facilities carry covenants, among them an interest coverage ratio that "should be greater than 2.5"; the graph records them as complied with (p.451). The report gives no level reached, so no headroom can be computed. |
| IAG | "At 31 December 2025, the Group had no financial covenants associated with its loans and borrowings" (p.160). |
| Ryanair | No covenant is described in the graph for the 2025 report. |
| easyJet | No covenant is described in the graph for the 2025 report. Its 2023 and 2024 reports mention restrictive covenants on a UK Export Finance facility. |

## Aircraft orders and capital commitments

These are future cash needs outside the balance sheet. They are not added to debt.

| Group | Commitment as stated |
|---|---|
| Air France-KLM | Firm orders of flight equipment of EUR 14,592 million, of which 2,307 in the first year and 3,181 in the second (p.466); 215 aircraft on firm order (p.65). |
| IAG | Capital expenditure authorised and contracted for of EUR 20,248 million, up from 12,634 million in 2024 (p.40). |
| Ryanair | 210 Boeing 737-8200 valued at about USD 9.6 billion (p.191), and 150 firm Boeing 737 MAX-10 valued at about USD 10.6 billion (p.192), before price concessions. |
| easyJet | 290 Airbus A320 family aircraft with an estimated list price of USD 35.2 billion before escalations and discounts, for delivery in financial years 2026 to 2034 (p.167). |

## Audit: key audit matters

| Group | Key audit matters in the graph |
|---|---|
| Air France-KLM | Recoverability of flight equipment assets; recognition of deferred tax assets of the French tax group; revenue recognition for unused passenger tickets (p.476 to 478). |
| IAG | VAT on the issuance of Avios; customer loyalty valuation; aircraft maintenance, restoration and hand-back costs (p.124, 128). |
| Ryanair | Aircraft useful lives and expected residual values (p.258). |
| easyJet | Valuation of the leased aircraft maintenance provision (p.139). |

None concerns going concern or liquidity.

## Watchlist

Status is assigned only from the cited facts above.

| Borrower | Status | Facts behind the status |
|---|---|---|
| Air France-KLM | Watch | Highest stated leverage of the four (1.66x); net debt rose from EUR 7,332 million to 8,392 million (p.452); firm orders of EUR 14,592 million. Covenants stated as met. |
| IAG | No adverse change | Net debt fell from EUR 7,517 million to 5,948 million and leverage from 1.1x to 0.8x (p.41); no financial covenants. Capital commitments rose to EUR 20,248 million. |
| Ryanair | No adverse change | Net cash of EUR 1,304 million against 1,373 million a year earlier (p.4). Debt of EUR 2,120 million falls due within 24 months, 53% of gross cash. |
| easyJet | No adverse change | Net cash rose from GBP 181 million to 602 million (p.176); 2% of liquidity falls due within 24 months. |

## Comparability

- **Currency.** easyJet reports in GBP, the others in EUR. Nothing is converted here; ratios and shares are compared, not amounts.
- **Year ends differ.** Ryanair's year ends on 31 March 2025 and easyJet's on 30 September 2025, so the four reports cover periods up to nine months apart.
- **Net debt is defined by each group.** Air France-KLM's and IAG's measures include lease debt; whether a figure includes leases is stated in each row.
- **Maturity tables differ.** IAG's and Ryanair's amounts due include leases; Air France-KLM's row is financial liabilities without lease debt; easyJet's is borrowings with interest.
- **Order values are not like for like.** Air France-KLM and IAG state contracted amounts in euros; Ryanair and easyJet state list or contract values in US dollars before discounts.
- **Liquidity is defined by each group**, with or without undrawn facilities.

## Gaps

- Lufthansa Group: no report in the graph on the date of this note.
- IAG: the audit opinion was not captured in the graph for the 2025 report.
- Covenant levels reached: no report states them, so no headroom is computed.
- Three source pages differ from the page the graph cites by one page (Air France-KLM p.368 and p.466, IAG p.154); the pages above are the verified ones.

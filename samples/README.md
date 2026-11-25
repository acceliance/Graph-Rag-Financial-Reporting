# Samples

| Folder | Content | State |
|---|---|---|
| [`real-reports/`](real-reports/README.md) | Manifest of public annual reports and how to download them | Ready: 15 reports of five European airlines, 2023 to 2025 |
| `source-docs/` | Annual reports of a fictive group, written for this repository | Planned |
| [`profiles/`](profiles/) | Four agent profiles for this corpus, each with questions to try (see below) | Ready; only the credit analyst has been tried on ingested reports |

## Agent profiles

Each profile gives the agent the role of one kind of reader. All four cite every figure with its report, page, scale and currency, keep stated figures apart from computed ones, and give no advice.

| Profile | For | What it produces |
|---|---|---|
| [`credit-analyst.md`](profiles/credit-analyst.md) | Credit analysts | Debt, maturities, covenant headroom, liquidity, commitments |
| [`due-diligence-analyst.md`](profiles/due-diligence-analyst.md) | Transaction-services and M&A teams | Numbered findings, red flags with the document that would close each, requests |
| [`private-debt-monitor.md`](profiles/private-debt-monitor.md) | Private debt funds | A portfolio table, changes since the previous report, a watchlist |
| [`equity-analyst.md`](profiles/equity-analyst.md) | Equity research | Peer comparison tables, growth and margins, guidance against delivery |

## Planned sample reports

Two annual reports, 2024 and 2025, of Orvanne Group, the fictive distributor of heating and ventilation equipment already used in the enterprise architecture repository. Being written for this repository, they can be committed, shown in a public demonstration, and built to contain cases a real report would not offer on demand:

- a 2024 figure restated in the 2025 report;
- a covenant whose headroom shrinks between the two years;
- a reorganisation of the segments;
- a subsidiary sold during 2025;
- one contradiction between the two reports.

Because the figures are invented, they are known exactly, which lets the extraction be measured against them.

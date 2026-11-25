# Public annual reports

This folder holds a list of public annual reports, not the reports. A report published on the web still belongs to its issuer, and committing it here would be redistributing it. The script downloads each one from its publisher's own site onto your machine.

| File | Content |
|---|---|
| [`manifest.csv`](manifest.csv) | One line per report: where it is and what its checksum must be |
| `downloads/` | Created by the script, git-ignored |

## Download

```powershell
.\scripts\fetch-reports.ps1
```

```bash
scripts/fetch-reports.sh
```

For each line the script downloads the file, checks that it is a PDF, and compares its SHA-256 checksum with the manifest. A file already downloaded with the right checksum is skipped. The script ends with an error if a download failed or a checksum differs: an issuer that replaces a report (a corrected edition, for instance) changes the checksum, and the graph you would build would no longer be the one others built from the same manifest.

Then upload the files of `downloads/` on the **Documents** screen.

## Add a report

1. Find the direct link to the PDF on the issuer's investor pages, or on the regulator's site. The link must start with `https://` and return the PDF itself, not a page that shows it.
2. Add a line to [`manifest.csv`](manifest.csv), with the `sha256` column empty. The columns are described at the top of the file.
3. Run the script. It keeps the file and prints its checksum.
4. Read the first pages of the downloaded file to confirm it is the report you meant, then paste the checksum into the line.

Before proposing a line to this repository, read the terms of use of the site the link points to. Linking to a public document is not redistributing it, but some sites forbid automated downloads.

## Sites that ask who you are

Some sites refuse a client that does not identify itself. The US Securities and Exchange Commission (sec.gov) asks for a User-Agent with a contact address:

```powershell
.\scripts\fetch-reports.ps1 -UserAgent "Your Company name@example.com"
```

```bash
FETCH_USER_AGENT="Your Company name@example.com" scripts/fetch-reports.sh
```

Filings on EDGAR are mostly HTML, and the application ingests PDFs: use the PDF the company publishes on its investor pages, or print the filing to PDF yourself.

## Several companies in one graph

- **Choose comparable companies.** Five or six of one sector over three years is a corpus you can still check by hand.
- **Mind the units.** Reports state figures in thousands, millions or billions, in different currencies, under IFRS or US GAAP, with financial years that end on different dates. The `framework` and `currency` columns are there to remind you; the agent profile must not compare unlike figures without saying so.
- **Keep the fictive group apart.** Do not load the reports of [`../source-docs/`](../source-docs/) in the same deployment as real companies.
- **Mind the size.** The defaults accept 500 pages and 50 MB per file (`GRAPHRAG_MAX_PAGES`, `GRAPHRAG_MAX_UPLOAD_MB` in `.env`).

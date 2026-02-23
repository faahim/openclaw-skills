# Listing Copy: Invoice Generator

## Metadata
- **Type:** Skill
- **Name:** invoice-generator
- **Display Name:** Invoice Generator
- **Categories:** [finance, productivity]
- **Price:** $12
- **Dependencies:** [wkhtmltopdf, jq, bash]
- **Icon:** 🧾

## Tagline
Generate professional PDF invoices from CLI — no SaaS, no subscriptions.

## Description

Manually creating invoices in Google Docs or paying $15/month for an invoicing SaaS is a waste of time and money. Freelancers and small businesses need a fast, repeatable way to generate polished invoices.

Invoice Generator creates professional PDF invoices from structured JSON data or simple CLI flags. Pass in line items, client details, and payment terms — get a branded PDF ready to send. Uses wkhtmltopdf under the hood for pixel-perfect HTML-to-PDF rendering.

**What it does:**
- 🧾 Generate PDF invoices from JSON data or CLI arguments
- 📋 Batch generate from a folder of invoice JSON files
- 🎨 Customizable HTML templates (bring your own brand)
- 📊 Built-in invoice ledger — track paid/pending/overdue
- 💰 Multi-currency support (USD, EUR, GBP, BDT, INR, JPY, etc.)
- 📐 Automatic tax calculations
- 🔢 Auto-numbering with configurable prefix/year
- 🖨️ Works headless (xvfb support for servers)

Perfect for freelancers, agencies, and indie devs who want fast invoice generation without leaving the terminal.

## Quick Start Preview

```bash
bash scripts/generate.sh \
  --number "INV-2026-001" \
  --from "Your Name" --to "Client Name" \
  --item "Web Development|40|75.00" \
  --item "Design|10|90.00" \
  --due-days 30 --output invoices/

# ✅ Generated: invoices/INV-2026-001.pdf
```

## Core Capabilities

1. PDF generation — Professional invoices via wkhtmltopdf (HTML → PDF)
2. CLI-first — Generate invoices without opening any app
3. JSON input — Structured data for automation and integrations
4. Batch processing — Generate dozens of invoices at once
5. Custom templates — Branded HTML templates with placeholder variables
6. Invoice ledger — Track status (pending/paid/overdue)
7. Multi-currency — USD, EUR, GBP, BDT, INR, JPY and more
8. Tax calculation — Automatic subtotal + tax + total
9. Auto-numbering — Sequential invoice numbers with prefix
10. Headless-ready — Works on servers without display (xvfb)

## Dependencies
- `wkhtmltopdf` (HTML to PDF)
- `jq` (JSON parsing)
- `bash` (4.0+)
- Optional: `xvfb` (headless servers)

## Installation Time
**5 minutes** — install wkhtmltopdf, generate first invoice

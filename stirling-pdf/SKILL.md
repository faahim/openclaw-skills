---
name: stirling-pdf
description: >-
  Deploy and manage Stirling PDF — a self-hosted PDF toolkit with 30+ operations including merge, split, compress, OCR, watermark, sign, and convert.
categories: [productivity, automation]
dependencies: [docker, curl]
---

# Stirling PDF Server Manager

## What This Does

Deploy a self-hosted PDF processing server with 30+ operations: merge, split, compress, rotate, watermark, OCR, convert (images/HTML/Office to PDF), add signatures, extract text, and more. Runs as a Docker container — no data leaves your server.

**Example:** "Deploy Stirling PDF on port 8080, then use the API to merge 3 PDFs into one."

## Quick Start (3 minutes)

### 1. Check Prerequisites

```bash
which docker > /dev/null 2>&1 || { echo "❌ Docker required. Install: https://docs.docker.com/engine/install/"; exit 1; }
echo "✅ Docker found"
```

### 2. Deploy Stirling PDF

```bash
bash scripts/deploy.sh
```

This starts Stirling PDF on port 8080 with persistent storage.

### 3. Verify

```bash
curl -s http://localhost:8080/api/v1/info/status | head -5
echo "✅ Stirling PDF running at http://localhost:8080"
```

## Core Workflows

### Workflow 1: Merge PDFs

**Use case:** Combine multiple PDF files into one.

```bash
# Merge via API
curl -X POST http://localhost:8080/api/v1/general/merge-pdfs \
  -F "fileInput=@file1.pdf" \
  -F "fileInput=@file2.pdf" \
  -F "fileInput=@file3.pdf" \
  -o merged.pdf

echo "✅ Merged into merged.pdf"
```

### Workflow 2: Split PDF by Pages

**Use case:** Extract specific pages from a PDF.

```bash
# Extract pages 1-3 and 5
curl -X POST http://localhost:8080/api/v1/general/split-pages \
  -F "fileInput=@document.pdf" \
  -F "pageNumbers=1-3,5" \
  -o split.pdf
```

### Workflow 3: Compress PDF

**Use case:** Reduce PDF file size for email/upload.

```bash
curl -X POST http://localhost:8080/api/v1/general/compress-pdf \
  -F "fileInput=@large-document.pdf" \
  -F "optimizeLevel=3" \
  -o compressed.pdf

ls -lh large-document.pdf compressed.pdf
```

### Workflow 4: OCR — Extract Text from Scanned PDFs

**Use case:** Make scanned documents searchable.

```bash
# Deploy with OCR support (uses larger image)
bash scripts/deploy.sh --ocr

# Run OCR on a scanned PDF
curl -X POST http://localhost:8080/api/v1/misc/ocr-pdf \
  -F "fileInput=@scanned.pdf" \
  -F "languages=eng" \
  -F "sidecar=false" \
  -F "ocrType=force-ocr" \
  -o searchable.pdf
```

### Workflow 5: Add Watermark

**Use case:** Stamp "CONFIDENTIAL" or "DRAFT" on documents.

```bash
curl -X POST http://localhost:8080/api/v1/security/add-watermark \
  -F "fileInput=@document.pdf" \
  -F "watermarkText=CONFIDENTIAL" \
  -F "fontSize=50" \
  -F "rotation=45" \
  -F "opacity=0.3" \
  -o watermarked.pdf
```

### Workflow 6: Convert Images to PDF

**Use case:** Bundle photos/scans into a single PDF.

```bash
curl -X POST http://localhost:8080/api/v1/convert/img-to-pdf \
  -F "fileInput=@photo1.jpg" \
  -F "fileInput=@photo2.png" \
  -F "autoRotate=true" \
  -o photos.pdf
```

### Workflow 7: PDF to Images

**Use case:** Extract pages as PNG/JPEG images.

```bash
curl -X POST http://localhost:8080/api/v1/convert/pdf-to-img \
  -F "fileInput=@document.pdf" \
  -F "imageFormat=png" \
  -F "dpi=300" \
  -o pages.zip
```

### Workflow 8: Rotate Pages

```bash
curl -X POST http://localhost:8080/api/v1/general/rotate-pdf \
  -F "fileInput=@document.pdf" \
  -F "angle=90" \
  -o rotated.pdf
```

### Workflow 9: Remove Password Protection

```bash
curl -X POST http://localhost:8080/api/v1/security/remove-password \
  -F "fileInput=@protected.pdf" \
  -F "password=oldpassword" \
  -o unlocked.pdf
```

### Workflow 10: Add Password Protection

```bash
curl -X POST http://localhost:8080/api/v1/security/add-password \
  -F "fileInput=@document.pdf" \
  -F "ownerPassword=admin123" \
  -F "password=user123" \
  -o protected.pdf
```

## Batch Processing

### Process Multiple Files

```bash
# Compress all PDFs in a directory
for pdf in /path/to/pdfs/*.pdf; do
  filename=$(basename "$pdf")
  curl -s -X POST http://localhost:8080/api/v1/general/compress-pdf \
    -F "fileInput=@$pdf" \
    -F "optimizeLevel=3" \
    -o "/path/to/output/$filename"
  echo "✅ Compressed: $filename"
done
```

### Automated Pipeline (Cron)

```bash
# Add to crontab: compress new PDFs every hour
# */60 * * * * bash /path/to/scripts/batch-compress.sh /inbox /outbox >> /var/log/pdf-compress.log 2>&1
```

## Management Commands

### Check Status

```bash
bash scripts/deploy.sh --status
```

### View Logs

```bash
docker logs stirling-pdf --tail 50
```

### Stop / Start / Restart

```bash
bash scripts/deploy.sh --stop
bash scripts/deploy.sh --start
bash scripts/deploy.sh --restart
```

### Update to Latest Version

```bash
bash scripts/deploy.sh --update
```

### Uninstall

```bash
bash scripts/deploy.sh --remove
```

## Configuration

### Environment Variables

```bash
# Set in scripts/deploy.sh or pass as flags
STIRLING_PORT=8080           # Web UI port
STIRLING_DATA=/opt/stirling  # Persistent data directory
STIRLING_OCR=false           # Enable OCR (larger image)
STIRLING_LANG=en_GB          # UI language
```

### Custom Port

```bash
bash scripts/deploy.sh --port 9090
```

### Enable Authentication

```bash
bash scripts/deploy.sh --auth --user admin --pass secretpassword
```

### Behind Reverse Proxy

```bash
# Nginx config snippet
# location /pdf/ {
#     proxy_pass http://localhost:8080/;
#     proxy_set_header Host $host;
#     proxy_set_header X-Real-IP $remote_addr;
#     client_max_body_size 100M;
# }
```

## Available API Endpoints

| Category | Endpoint | Description |
|----------|----------|-------------|
| General | `/api/v1/general/merge-pdfs` | Merge multiple PDFs |
| General | `/api/v1/general/split-pages` | Split by page numbers |
| General | `/api/v1/general/rotate-pdf` | Rotate pages |
| General | `/api/v1/general/compress-pdf` | Compress file size |
| Convert | `/api/v1/convert/img-to-pdf` | Images → PDF |
| Convert | `/api/v1/convert/pdf-to-img` | PDF → Images |
| Convert | `/api/v1/convert/html-to-pdf` | HTML → PDF |
| Security | `/api/v1/security/add-password` | Encrypt PDF |
| Security | `/api/v1/security/remove-password` | Decrypt PDF |
| Security | `/api/v1/security/add-watermark` | Add watermark |
| Misc | `/api/v1/misc/ocr-pdf` | OCR scanned docs |
| Misc | `/api/v1/misc/extract-text` | Extract text content |
| Misc | `/api/v1/misc/flatten` | Flatten form fields |

Full API docs at: `http://localhost:8080/swagger-ui/index.html`

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Fix:** Ensure Docker is running:
```bash
sudo systemctl start docker
sudo usermod -aG docker $USER  # Run without sudo
```

### Issue: OCR not working

**Fix:** Deploy with OCR support:
```bash
bash scripts/deploy.sh --remove
bash scripts/deploy.sh --ocr
```

### Issue: Large files timing out

**Fix:** Increase timeout and upload limit:
```bash
# If behind nginx, add to server block:
# client_max_body_size 500M;
# proxy_read_timeout 300s;
```

### Issue: Container uses too much memory

**Fix:** Set memory limits:
```bash
docker update --memory="2g" --memory-swap="4g" stirling-pdf
```

## Dependencies

- `docker` (20.10+)
- `curl` (for API calls)
- ~500MB disk (standard image) / ~1.5GB (with OCR)
- 512MB RAM minimum / 2GB recommended for OCR

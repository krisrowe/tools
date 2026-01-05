# pdf-image-extractor

Extract images from PDF files with size filtering and optional Google Drive upload.

## Requirements

```bash
pip install pymupdf
```

For Google Drive upload:
```bash
pip install gwsa
```

## Usage

### Basic extraction

```bash
python extract.py document.pdf
```

Extracts all images >= 100x100 pixels to `./extracted_images/`.

### With size filter

```bash
python extract.py document.pdf --min-size 180
```

Only extracts images where both width AND height are >= 180 pixels.

### Limit number of images (for testing)

```bash
python extract.py document.pdf --limit 10
```

### Custom output directory

```bash
python extract.py document.pdf -o /tmp/my_images
```

### Upload to Google Drive

```bash
python extract.py document.pdf --drive-folder-id YOUR_FOLDER_ID
```

Extracts images locally, then uploads to the specified Drive folder. Skips files that already exist in the folder.

### Upload-only mode

If you've already extracted images and just want to upload:

```bash
python extract.py document.pdf --upload-only --drive-folder-id YOUR_FOLDER_ID
```

## Options

| Option | Description |
|--------|-------------|
| `-o, --output-dir` | Output directory (default: `./extracted_images`) |
| `-m, --min-size` | Minimum width AND height in pixels (default: 100) |
| `-l, --limit` | Max images to process, 0 = unlimited (default: 0) |
| `--drive-folder-id` | Google Drive folder ID for upload |
| `--upload-only` | Skip extraction, upload existing images |

## Example

```bash
# Extract large images from a report, upload to Drive
python extract.py report.pdf \
    --min-size 200 \
    --output-dir ./report_images \
    --drive-folder-id 1abc123def456
```

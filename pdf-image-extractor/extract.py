#!/usr/bin/env python3
"""
Extract images from PDF files with size filtering and optional Google Drive upload.

Requires: pip install pymupdf

For Google Drive upload, also requires: pip install gwsa
"""

import argparse
import os
import sys
from pathlib import Path


def extract_images(pdf_path: str, output_dir: str, min_size: int = 100, limit: int = 0) -> list[str]:
    """
    Extract images from a PDF file.

    Args:
        pdf_path: Path to the PDF file
        output_dir: Directory to save extracted images
        min_size: Minimum width AND height in pixels (default 100)
        limit: Maximum number of images to extract (0 = unlimited)

    Returns:
        List of paths to extracted image files
    """
    try:
        import fitz  # PyMuPDF
    except ImportError:
        print("Error: PyMuPDF not installed. Run: pip install pymupdf", file=sys.stderr)
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    doc = fitz.open(pdf_path)
    extracted = []

    for page_num in range(len(doc)):
        if limit and len(extracted) >= limit:
            break

        page = doc[page_num]
        images = page.get_images()

        for img_idx, img in enumerate(images):
            if limit and len(extracted) >= limit:
                break

            xref = img[0]
            pix = fitz.Pixmap(doc, xref)

            # Skip images smaller than min_size in either dimension
            if pix.width < min_size or pix.height < min_size:
                continue

            # Convert CMYK to RGB if needed
            if pix.n - pix.alpha > 3:
                pix = fitz.Pixmap(fitz.csRGB, pix)

            img_path = os.path.join(output_dir, f"page{page_num + 1}_img{img_idx + 1}.png")
            pix.save(img_path)
            extracted.append(img_path)
            print(f"Extracted: {img_path} ({pix.width}x{pix.height})")

    doc.close()
    return extracted


def upload_to_drive(image_paths: list[str], folder_id: str, limit: int = 0) -> int:
    """
    Upload images to Google Drive, skipping existing files.

    Args:
        image_paths: List of local image file paths
        folder_id: Google Drive folder ID
        limit: Maximum number of files to upload (0 = unlimited)

    Returns:
        Number of files uploaded
    """
    try:
        from gwsa.sdk.drive import upload_file, list_folder
    except ImportError:
        print("Error: gwsa not installed. Run: pip install gwsa", file=sys.stderr)
        sys.exit(1)

    # Get existing files in the folder
    existing = list_folder(folder_id)
    existing_names = {item["name"] for item in existing.get("items", [])}

    uploaded = 0
    for path in image_paths:
        if limit and uploaded >= limit:
            break

        filename = os.path.basename(path)
        if filename in existing_names:
            print(f"Skipping (exists): {filename}")
            continue

        upload_file(path, folder_id=folder_id)
        uploaded += 1
        if uploaded % 20 == 0:
            print(f"Uploaded {uploaded}...")

    return uploaded


def main():
    parser = argparse.ArgumentParser(
        description="Extract images from PDF files with size filtering and optional Drive upload."
    )
    parser.add_argument("pdf", help="Path to the PDF file")
    parser.add_argument(
        "-o", "--output-dir",
        default="./extracted_images",
        help="Output directory for extracted images (default: ./extracted_images)"
    )
    parser.add_argument(
        "-m", "--min-size",
        type=int,
        default=100,
        help="Minimum width AND height in pixels (default: 100)"
    )
    parser.add_argument(
        "-l", "--limit",
        type=int,
        default=0,
        help="Limit number of images to process (0 = unlimited)"
    )
    parser.add_argument(
        "--drive-folder-id",
        help="Google Drive folder ID to upload images to (requires gwsa)"
    )
    parser.add_argument(
        "--upload-only",
        action="store_true",
        help="Skip extraction, only upload existing images from output-dir"
    )

    args = parser.parse_args()

    if args.upload_only:
        if not args.drive_folder_id:
            print("Error: --drive-folder-id required with --upload-only", file=sys.stderr)
            sys.exit(1)

        # Find existing images in output dir
        output_path = Path(args.output_dir)
        if not output_path.exists():
            print(f"Error: Output directory does not exist: {args.output_dir}", file=sys.stderr)
            sys.exit(1)

        image_paths = sorted(str(p) for p in output_path.glob("*.png"))
        print(f"Found {len(image_paths)} images in {args.output_dir}")
    else:
        # Extract images
        if not os.path.exists(args.pdf):
            print(f"Error: PDF file not found: {args.pdf}", file=sys.stderr)
            sys.exit(1)

        image_paths = extract_images(
            args.pdf,
            args.output_dir,
            min_size=args.min_size,
            limit=args.limit
        )
        print(f"\nExtracted {len(image_paths)} images to {args.output_dir}")

    # Upload to Drive if requested
    if args.drive_folder_id:
        print(f"\nUploading to Google Drive folder: {args.drive_folder_id}")
        upload_limit = args.limit if args.upload_only else 0
        uploaded = upload_to_drive(image_paths, args.drive_folder_id, limit=upload_limit)
        print(f"Uploaded {uploaded} new files")


if __name__ == "__main__":
    main()

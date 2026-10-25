---
name: document-workflows
description: Safe local extraction, OCR, conversion, and review workflows for PDF, Office, Markdown, and LaTeX documents.
whenToUse: Use when reading, converting, extracting, OCRing, comparing, or generating local documents.
---

# Local document workflows

Treat original documents as immutable inputs. Write generated files into an explicit output directory, use a temporary directory for intermediates, and never overwrite a source unless the user explicitly requests it.

Choose the narrowest suitable tool:

- PDF text: `pdftotext -layout -- INPUT OUTPUT.txt`; inspect metadata with `pdfinfo`.
- Scanned PDF or image: render pages if needed, then run Tesseract with an explicit language such as `-l eng` or `-l chi_sim+eng`. OCR output is evidence to verify, not a faithful copy.
- Office documents: use `libreoffice --headless --convert-to FORMAT --outdir OUTPUT_DIR INPUT`.
- Markdown, LaTeX, DOCX, and other text-oriented conversions: use Pandoc with explicit input/output formats where ambiguity exists.

After conversion, verify that the output exists, is non-empty, and has a plausible page or section count. Spot-check headings, tables, formulas, references, non-Latin text, and hyphenated line breaks. Report any losses or uncertainty and give the exact output path.

Do not execute macros or embedded scripts. Quote paths and use `--` where the command supports it. Do not send local documents to remote services unless the user explicitly authorizes that transfer.

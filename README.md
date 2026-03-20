# pdf-tools.sh

`pdf-tools.sh` is a small collection of bash-first PDF utilities.

The goal is to keep these tools:
- simple
- dependency-light
- easy to run on a normal workstation
- built on proven system tools instead of custom PDF libraries

Current tools:
- `doc-to-pdf.sh`
  Convert office documents to PDF and merge the result.
- `flatten-pdf-links.sh`
  Re-distill PDFs so interactive links are no longer clickable.

## Design

This project intentionally stays small:
- bash scripts only
- system packages for heavy lifting
- no Python package stack
- no local service or database
- no hidden state outside the output files you ask it to create

## Install

Clone the repo and run each tool's explicit setup path when needed.

```bash
git clone git@github.com:peternickol/pdf-tools.sh.git
cd pdf-tools.sh
```

Bootstrap the document conversion tool:

```bash
bash doc-to-pdf.sh --setup
```

Bootstrap the PDF flattening tool:

```bash
bash flatten-pdf-links.sh --setup
```

Each `--setup` also installs a launcher symlink into:
- `/usr/local/bin` when writable
- otherwise `~/.local/bin`

If that launcher directory is not already on `PATH`, setup appends the matching
export line to your shell startup file.

### What `--setup` installs

`doc-to-pdf.sh --setup`
- Debian: `libreoffice` and `poppler-utils`
- macOS: `LibreOffice` and `poppler`

`flatten-pdf-links.sh --setup`
- Debian: `ghostscript`
- macOS: `ghostscript`

If the platform is unsupported, the scripts stop and tell you what to install manually.

## Tool: `doc-to-pdf.sh`

Convert `.doc`, `.docx`, and `.odt` files from one directory into PDFs, then merge the PDFs into a single output file.

By default it also copies any PDFs already present in that same source directory into the output directory before the merge step.

### Requirements

- `soffice`
- `pdfunite`

### Usage

```bash
bash doc-to-pdf.sh [options]
bash doc-to-pdf.sh --setup
```

### Options

- `--setup`
  Install system prerequisites for this tool.

- `--root-dir PATH`
  Directory to scan for `.doc`, `.docx`, and `.odt` files.
  Default: `.`

- `--output-dir PATH`
  Directory where generated PDFs and the merged PDF will be written.
  Default: `./pdf_output`

- `--merged-name NAME.pdf`
  Name of the merged PDF file inside the output directory.
  Default: `OUTPUT-final_pdf_file.pdf`

- `--docs-only`
  Only merge PDFs generated from office documents in this run.
  Do not copy pre-existing PDFs from the source directory into the output directory.

- `--help`
  Show built-in help.

### Examples

Convert documents from the current directory and merge them:

```bash
bash doc-to-pdf.sh
```

Convert documents from a specific folder:

```bash
bash doc-to-pdf.sh --root-dir ./docs
```

Write output somewhere else with a custom merged filename:

```bash
bash doc-to-pdf.sh --output-dir ./build/pdf --merged-name combined.pdf
```

Merge only PDFs generated from office documents in this run:

```bash
bash doc-to-pdf.sh --docs-only
```

### Notes

- This tool scans only the top level of `--root-dir`. It does not recurse into subdirectories.
- LibreOffice conversion quality depends on the source document and LibreOffice itself.
- Existing PDFs in the source directory are copied into the output directory unless `--docs-only` is used.

## Tool: `flatten-pdf-links.sh`

Walk a directory tree, find PDFs, and rewrite them so interactive links are no longer clickable.

This works by re-distilling each PDF through Ghostscript's PDF writer. The result is a new PDF that preserves visible page content while flattening interactive annotations such as clickable links.

By default this tool overwrites the original PDFs after successful conversion.
Use `--copy` when you want sibling output files instead.

### Requirements

- `gs`

### Usage

```bash
bash flatten-pdf-links.sh <root-dir> [options]
bash flatten-pdf-links.sh --setup
```

### Options

- `--setup`
  Install system prerequisites for this tool.

- `--copy`
  Write sibling files instead of overwriting originals.

- `--suffix TEXT`
  Suffix used for copy mode output files.
  Default: `-flat`

- `--help`
  Show built-in help.

### Examples

Overwrite PDFs in place:

```bash
bash flatten-pdf-links.sh ./docs
```

Write sibling copy files instead:

```bash
bash flatten-pdf-links.sh ./docs --copy
```

Use a different suffix for copy mode:

```bash
bash flatten-pdf-links.sh ./docs --copy --suffix -print
```

### Notes

- This tool recurses through the full directory tree under the root you provide.
- By default it overwrites the original PDFs.
- Use `--copy` when you want sibling files like `example-flat.pdf`.
- Re-distilling a PDF can change file size and may slightly alter internal PDF structure even when the pages look the same.

## License

This project is released under the MIT License. See [LICENSE](/home/pan/temp/pdf-tools.sh/LICENSE).

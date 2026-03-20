# pdf-tool

`pdf-tool` is a small bash-first PDF utility.

The goal is to keep it:
- simple
- dependency-light
- easy to run on a normal workstation
- built on proven system tools instead of custom PDF libraries

Current commands:
- `pdf-tool convert`
  Convert office documents to PDF and merge the result.
- `pdf-tool flatten`
  Re-distill PDFs so interactive links are no longer clickable.

## Design

This project intentionally stays small:
- bash only
- system packages for heavy lifting
- no Python package stack
- no local service or database
- no hidden state outside the output files you ask it to create

## Install

Install `pdf-tool` with the direct download method:

```bash
curl -fsSL https://raw.githubusercontent.com/peternickol/pdf-tool.sh/master/pdf-tool -o pdf-tool && sudo bash pdf-tool --setup && rm pdf-tool
```

Force reinstall with the latest public script:

```bash
curl -fsSL https://raw.githubusercontent.com/peternickol/pdf-tool.sh/master/pdf-tool -o pdf-tool && sudo bash pdf-tool --setup && rm pdf-tool
```

`--setup` does three things:
- installs system prerequisites
- installs a launcher into:
  - `/usr/local/bin` when writable
  - otherwise `~/.local/bin`
- appends that launcher directory to your shell startup file if needed

After that, new shells should be able to run:

```bash
pdf-tool --help
pdf-tool convert ./docs
pdf-tool flatten ./docs
```

### What `--setup` installs

Automatic setup is intended for Debian and Ubuntu style systems.

On Debian/Ubuntu:
- `libreoffice`
- `poppler-utils`
- `ghostscript`

On other platforms, `pdf-tool --setup` stops and tells you what to install manually.

### Development

If you are working on the tool itself, then a git checkout still makes sense:

```bash
git clone git@github.com:peternickol/pdf-tool.sh.git
cd pdf-tool.sh
bash pdf-tool --setup
```

## Command: `pdf-tool convert`

Convert `.doc`, `.docx`, and `.odt` files from one directory into PDFs, then merge the PDFs into a single output file.

By default it also copies any PDFs already present in that same source directory into the output directory before the merge step.

### Usage

```bash
pdf-tool convert <dir> [options]
```

### Options

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

```bash
pdf-tool convert ./docs
pdf-tool convert ./docs --output-dir ./build/pdf --merged-name combined.pdf
pdf-tool convert ./docs --docs-only
```

### Notes

- This command scans only the top level of the source directory. It does not recurse into subdirectories.
- LibreOffice conversion quality depends on the source document and LibreOffice itself.
- Existing PDFs in the source directory are copied into the output directory unless `--docs-only` is used.

## Command: `pdf-tool flatten`

Walk a directory tree, find PDFs, and rewrite them so interactive links are no longer clickable.

This works by re-distilling each PDF through Ghostscript's PDF writer. The result is a new PDF that preserves visible page content while flattening interactive annotations such as clickable links.

By default this command overwrites the original PDFs after successful conversion.
Use `--copy` when you want sibling output files instead.

### Usage

```bash
pdf-tool flatten <dir> [options]
```

### Options

- `--copy`
  Write sibling files instead of overwriting originals.

- `--suffix TEXT`
  Suffix used for copy mode output files.
  Default: `-flat`

- `--help`
  Show built-in help.

### Examples

```bash
pdf-tool flatten ./docs
pdf-tool flatten ./docs --copy
pdf-tool flatten ./docs --copy --suffix -print
```

### Notes

- This command recurses through the full directory tree under the root you provide.
- By default it overwrites the original PDFs.
- Use `--copy` when you want sibling files like `example-flat.pdf`.
- Re-distilling a PDF can change file size and may slightly alter internal PDF structure even when the pages look the same.

## License

This project is released under the MIT License. See LICENSE.

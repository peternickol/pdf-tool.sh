#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE_PATH" ]]; do
  LINK_DIR="$(cd -- "$(dirname -- "$SOURCE_PATH")" && pwd)"
  SOURCE_PATH="$(readlink -- "$SOURCE_PATH")"
  [[ "$SOURCE_PATH" != /* ]] && SOURCE_PATH="$LINK_DIR/$SOURCE_PATH"
done
SCRIPT_PATH="$(cd -- "$(dirname -- "$SOURCE_PATH")" && pwd)/$(basename -- "$SOURCE_PATH")"

ROOT_DIR="."
OUTPUT_DIR="./pdf_output"
MERGED_NAME="OUTPUT-final_pdf_file.pdf"
INCLUDE_EXISTING_PDFS=1

usage() {
  cat <<EOF
Usage: bash doc-to-pdf.sh [options]
       bash doc-to-pdf.sh --setup

Convert .doc, .docx, and .odt files in a directory to PDF and optionally merge
the resulting PDFs into a single output file.

Options:
  --setup                   Install system prerequisites for this tool
  --root-dir PATH            Directory to scan for source documents (default: .)
  --output-dir PATH          Directory to write generated PDFs (default: ./pdf_output)
  --merged-name NAME.pdf     Name for the merged PDF inside output-dir
                             (default: OUTPUT-final_pdf_file.pdf)
  --docs-only                Only merge PDFs generated from documents in this run
  --help                     Show this help text

Examples:
  bash doc-to-pdf.sh --setup
  bash doc-to-pdf.sh
  bash doc-to-pdf.sh --root-dir ./docs
  bash doc-to-pdf.sh --output-dir ./build/pdf --merged-name combined.pdf
  bash doc-to-pdf.sh --docs-only
EOF
}

require_bin() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Required command not found: $name" >&2
    exit 1
  fi
}

launcher_target() {
  local name
  name="$(basename -- "$SCRIPT_PATH")"
  if [[ -w /usr/local/bin ]]; then
    printf '%s' "/usr/local/bin/$name"
  else
    printf '%s' "$HOME/.local/bin/$name"
  fi
}

shell_rc_path() {
  if [[ -n "${BASH_VERSION:-}" ]]; then
    printf '%s' "$HOME/.bashrc"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    printf '%s' "$HOME/.zshrc"
  else
    printf '%s' "$HOME/.profile"
  fi
}

ensure_launcher_path() {
  local target_dir rc_path export_line path_present=0
  target_dir="$(dirname -- "$(launcher_target)")"
  rc_path="$(shell_rc_path)"
  export_line="export PATH=\"$target_dir:\$PATH\""

  case ":$PATH:" in
    *":$target_dir:"*)
      path_present=1
      ;;
  esac

  touch "$rc_path"
  if grep -Fqx "$export_line" "$rc_path"; then
    echo "==> PATH export already present in $rc_path"
  else
    printf '\n# Added by pdf-tools.sh setup\n%s\n' "$export_line" >> "$rc_path"
    echo "==> Added launcher PATH to $rc_path"
  fi

  if [[ $path_present -eq 1 ]]; then
    echo "==> Launcher directory already on PATH in this shell: $target_dir"
  else
    echo "==> Open a new shell or run: source $rc_path"
  fi
}

install_launcher_link() {
  local target target_dir
  target="$(launcher_target)"
  target_dir="$(dirname -- "$target")"

  mkdir -p "$target_dir"
  ln -sfn "$SCRIPT_PATH" "$target"
  echo "==> Installed launcher: $target"
  ensure_launcher_path
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

is_debian_like() {
  [[ -f /etc/debian_version ]]
}

setup_prereqs() {
  local missing=()

  if ! command -v soffice >/dev/null 2>&1; then
    missing+=("soffice")
  fi
  if ! command -v pdfunite >/dev/null 2>&1; then
    missing+=("pdfunite")
  fi

  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "==> All prerequisites already installed"
    return 0
  fi

  if is_debian_like; then
    echo "==> Installing LibreOffice and poppler-utils"
    sudo apt-get update
    sudo apt-get install -y libreoffice poppler-utils
    return 0
  fi

  if is_macos; then
    require_bin brew
    echo "==> Installing poppler"
    brew install poppler
    echo "==> Installing LibreOffice"
    brew install --cask libreoffice
    return 0
  fi

  echo "Unsupported platform for --setup. Install LibreOffice and pdfunite manually." >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --setup)
      setup_prereqs
      install_launcher_link
      exit 0
      ;;
    --root-dir)
      if [[ $# -lt 2 ]]; then
        echo "--root-dir requires a value" >&2
        usage >&2
        exit 1
      fi
      ROOT_DIR="$2"
      shift
      ;;
    --output-dir)
      if [[ $# -lt 2 ]]; then
        echo "--output-dir requires a value" >&2
        usage >&2
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift
      ;;
    --merged-name)
      if [[ $# -lt 2 ]]; then
        echo "--merged-name requires a value" >&2
        usage >&2
        exit 1
      fi
      MERGED_NAME="$2"
      shift
      ;;
    --docs-only)
      INCLUDE_EXISTING_PDFS=0
      ;;
    --help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Directory not found: $ROOT_DIR" >&2
  exit 1
fi

require_bin soffice
require_bin pdfunite

mkdir -p "$OUTPUT_DIR"

mapfile -d '' DOC_FILES < <(find "$ROOT_DIR" -maxdepth 1 -type f \( -iname '*.doc' -o -iname '*.docx' -o -iname '*.odt' \) -print0 | sort -z)

if [[ ${#DOC_FILES[@]} -gt 0 ]]; then
  echo "==> Converting office documents from $ROOT_DIR"
  soffice --headless --convert-to pdf "${DOC_FILES[@]}" --outdir "$OUTPUT_DIR"
else
  echo "==> No office documents found in $ROOT_DIR"
fi

if [[ "$INCLUDE_EXISTING_PDFS" -eq 1 ]]; then
  mapfile -d '' SOURCE_PDFS < <(find "$ROOT_DIR" -maxdepth 1 -type f -iname '*.pdf' -print0 | sort -z)
  for input_pdf in "${SOURCE_PDFS[@]}"; do
    target_pdf="$OUTPUT_DIR/$(basename "$input_pdf")"
    if [[ "$input_pdf" != "$target_pdf" ]]; then
      cp -f "$input_pdf" "$target_pdf"
      echo "==> Copied $(basename "$input_pdf")"
    fi
  done
fi

mapfile -d '' OUTPUT_PDFS < <(find "$OUTPUT_DIR" -maxdepth 1 -type f -iname '*.pdf' ! -iname "$MERGED_NAME" -print0 | sort -z)

if [[ ${#OUTPUT_PDFS[@]} -eq 0 ]]; then
  echo "No PDFs available to merge in $OUTPUT_DIR" >&2
  exit 1
fi

echo "==> Merging PDFs into $OUTPUT_DIR/$MERGED_NAME"
pdfunite "${OUTPUT_PDFS[@]}" "$OUTPUT_DIR/$MERGED_NAME"

echo "==> Done"
echo "==> Wrote $OUTPUT_DIR/$MERGED_NAME"

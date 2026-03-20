#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE_PATH" ]]; do
  LINK_DIR="$(cd -- "$(dirname -- "$SOURCE_PATH")" && pwd)"
  SOURCE_PATH="$(readlink -- "$SOURCE_PATH")"
  [[ "$SOURCE_PATH" != /* ]] && SOURCE_PATH="$LINK_DIR/$SOURCE_PATH"
done
SCRIPT_PATH="$(cd -- "$(dirname -- "$SOURCE_PATH")" && pwd)/$(basename -- "$SOURCE_PATH")"

ROOT_DIR=""
IN_PLACE=1
SUFFIX="-flat"

usage() {
  cat <<EOF
Usage: bash flatten-pdf-links.sh <root-dir> [options]
       bash flatten-pdf-links.sh --setup

Recursively walk <root-dir> and rewrite PDFs so interactive links are no longer
clickable.

Options:
  --setup           Install system prerequisites for this tool
  --copy            Write sibling files instead of overwriting originals
  --suffix TEXT     Suffix for copy mode output files (default: -flat)
  --help            Show this help text

Examples:
  bash flatten-pdf-links.sh --setup
  bash flatten-pdf-links.sh ./docs
  bash flatten-pdf-links.sh ./docs --copy
  bash flatten-pdf-links.sh ./docs --copy --suffix -print
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
  if command -v gs >/dev/null 2>&1; then
    echo "==> ghostscript already installed"
    return 0
  fi

  if is_debian_like; then
    echo "==> Installing ghostscript"
    sudo apt-get update
    sudo apt-get install -y ghostscript
    return 0
  fi

  if is_macos; then
    require_bin brew
    echo "==> Installing ghostscript"
    brew install ghostscript
    return 0
  fi

  echo "Unsupported platform for --setup. Install Ghostscript manually." >&2
  exit 1
}

flatten_pdf() {
  local input_pdf="$1"
  local output_pdf="$2"
  local temp_pdf

  temp_pdf="$(mktemp "${TMPDIR:-/tmp}/flatten-pdf.XXXXXX.pdf")"
  trap 'rm -f "$temp_pdf"' RETURN

  gs \
    -q \
    -dBATCH \
    -dNOPAUSE \
    -dSAFER \
    -sDEVICE=pdfwrite \
    -dCompatibilityLevel=1.4 \
    -o "$temp_pdf" \
    "$input_pdf"

  mv "$temp_pdf" "$output_pdf"
  trap - RETURN
}

while (($# > 0)); do
  case "$1" in
    --setup)
      setup_prereqs
      install_launcher_link
      exit 0
      ;;
    --copy)
      IN_PLACE=0
      ;;
    --suffix)
      if [[ $# -lt 2 ]]; then
        echo "--suffix requires a value" >&2
        usage >&2
        exit 1
      fi
      SUFFIX="$2"
      shift
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
      if [[ -n "$ROOT_DIR" ]]; then
        echo "Only one root directory may be provided" >&2
        usage >&2
        exit 1
      fi
      ROOT_DIR="$1"
      ;;
  esac
  shift
done

if [[ -z "$ROOT_DIR" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Directory not found: $ROOT_DIR" >&2
  exit 1
fi

require_bin gs

count=0
while IFS= read -r -d '' input_pdf; do
  if [[ "$IN_PLACE" -eq 0 ]]; then
    output_pdf="${input_pdf%.pdf}${SUFFIX}.pdf"
  else
    output_pdf="${input_pdf}.tmp-flattened.pdf"
  fi

  echo "==> Flattening $input_pdf"
  flatten_pdf "$input_pdf" "$output_pdf"

  if [[ "$IN_PLACE" -eq 0 ]]; then
    echo "==> Wrote $output_pdf"
  else
    mv "$output_pdf" "$input_pdf"
    echo "==> Replaced $input_pdf"
  fi

  count=$((count + 1))
done < <(find "$ROOT_DIR" -type f \( -iname '*.pdf' \) -print0 | sort -z)

echo "==> Done"
echo "==> Processed $count PDF(s)"

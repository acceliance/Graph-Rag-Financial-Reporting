#!/usr/bin/env bash
# Downloads the public annual reports listed in samples/real-reports/manifest.csv.
#
# Each report is fetched from the address in the manifest (the issuer's or the regulator's
# own site), checked to be a PDF, and compared with the manifest's SHA-256 checksum.
# Files land in samples/real-reports/downloads, which is git-ignored: the reports are
# third-party documents and are never committed. Upload them afterwards on the Documents
# screen of the application.
#
# Usage: scripts/fetch-reports.sh [manifest] [output folder]
#
# Environment:
#   FETCH_USER_AGENT   User-Agent header. Some sites (sec.gov among them) ask automated
#                      clients to identify themselves with a contact address: set yours here.
#   FETCH_DELAY        Pause in seconds between two downloads (default 1).

set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="${1:-$root/samples/real-reports/manifest.csv}"
outdir="${2:-$root/samples/real-reports/downloads}"
agent="${FETCH_USER_AGENT:-graph-rag-fetch-reports/1.0}"
delay="${FETCH_DELAY:-1}"

if [ ! -f "$manifest" ]; then
  echo "Manifest not found: $manifest" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  # Read from stdin: given a path with a backslash, sha256sum prefixes the hash with "\".
  sha256() { sha256sum < "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 < "$1" | cut -d' ' -f1; }
else
  echo "sha256sum or shasum is required." >&2
  exit 1
fi

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

mkdir -p "$outdir"

ok=0; unverified=0; failed=0; first=1; seen=0

while IFS=, read -r file company year rtype framework language currency url expected || [ -n "${file:-}" ]; do
  file="${file#$'\xef\xbb\xbf'}"   # byte-order mark left by some editors on the first line
  file="$(trim "${file%$'\r'}")"
  case "$file" in ''|'#'*|file) continue ;; esac
  seen=$((seen + 1))

  url="$(trim "${url:-}")"
  expected="$(trim "${expected:-}")"
  expected="$(printf '%s' "${expected%$'\r'}" | tr 'A-F' 'a-f')"

  if ! printf '%s' "$file" | grep -Eq '^[A-Za-z0-9._-]+\.pdf$'; then
    echo "FAILED  '$file': the file name must use letters, digits, dot, dash, underscore and end in .pdf"
    failed=$((failed + 1)); continue
  fi
  case "$url" in
    https://*) ;;
    *) echo "FAILED  $file : the url must start with https://"; failed=$((failed + 1)); continue ;;
  esac
  if [ -n "$expected" ] && ! printf '%s' "$expected" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "FAILED  $file : sha256 must be 64 hexadecimal characters, or empty"
    failed=$((failed + 1)); continue
  fi

  target="$outdir/$file"
  part="$target.part"

  if [ -f "$target" ]; then
    actual="$(sha256 "$target")"
    if [ -n "$expected" ] && [ "$actual" = "$expected" ]; then
      echo "OK      $file (already downloaded)"
      ok=$((ok + 1)); continue
    fi
    if [ -z "$expected" ]; then
      echo "KEPT    $file (already downloaded, no checksum in the manifest)"
      echo "        sha256 to paste: $actual"
      unverified=$((unverified + 1)); continue
    fi
    echo "        $file is present with another checksum: downloading again"
  fi

  if [ "$first" -eq 0 ] && [ "$delay" -gt 0 ]; then sleep "$delay"; fi
  first=0

  echo "GET     $file  ($company $year)"
  if ! curl --fail --silent --show-error --location --max-redirs 5 \
            --proto '=https' --proto-redir '=https' \
            --user-agent "$agent" --output "$part" "$url" </dev/null; then
    rm -f "$part"
    echo "FAILED  $file : download error"
    failed=$((failed + 1)); continue
  fi

  if [ "$(head -c 5 "$part")" != "%PDF-" ]; then
    rm -f "$part"
    echo "FAILED  $file : the address did not return a PDF (a web page or a refusal, most likely)"
    failed=$((failed + 1)); continue
  fi

  actual="$(sha256 "$part")"
  if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
    rm -f "$part"
    echo "FAILED  $file : checksum differs from the manifest; the publisher may have replaced the file"
    echo "        expected $expected"
    echo "        received $actual"
    failed=$((failed + 1)); continue
  fi

  mv -f "$part" "$target"
  if [ -n "$expected" ]; then
    echo "OK      $file"
    ok=$((ok + 1))
  else
    echo "KEPT    $file (no checksum in the manifest)"
    echo "        sha256 to paste: $actual"
    unverified=$((unverified + 1))
  fi
done < "$manifest"

if [ "$seen" -eq 0 ]; then
  echo "The manifest lists no report yet. Add lines to $manifest (see samples/real-reports/README.md)."
  exit 0
fi

echo
echo "$ok verified, $unverified without checksum, $failed failed. Folder: $outdir"
[ "$failed" -eq 0 ]

#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

aab_path="${1:-build/app/outputs/bundle/prodRelease/app-prod-release.aab}"
ephemeral_signing="${2:-false}"
expected_certificate_sha256="${3:-}"

if [ ! -f "$aab_path" ]; then
  echo "App Bundle not found: $aab_path" >&2
  exit 1
fi

find_jdk_tool() {
  local tool="$1" configured_jdk candidate
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return
  fi
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/$tool" ]; then
    printf '%s\n' "$JAVA_HOME/bin/$tool"
    return
  fi
  configured_jdk="$(
    flutter config --machine |
      sed -n 's/^[[:space:]]*"jdk-dir": "\(.*\)"[,]*$/\1/p'
  )"
  candidate="$configured_jdk/bin/$tool"
  if [ -n "$configured_jdk" ] && [ -x "$candidate" ]; then
    printf '%s\n' "$candidate"
    return
  fi
  echo "Required JDK tool not found: $tool" >&2
  return 1
}

jarsigner_path="$(find_jdk_tool jarsigner)"
keytool_path="$(find_jdk_tool keytool)"
verification_dir="$(mktemp -d)"
trap 'rm -rf -- "$verification_dir"' EXIT

unzip -tqq "$aab_path"
jarsigner_report="$verification_dir/jarsigner.txt"
if ! "$jarsigner_path" -verify "$aab_path" >"$jarsigner_report" 2>&1; then
  echo "The App Bundle JAR signature is invalid." >&2
  exit 1
fi
if ! grep -F -- "jar verified." "$jarsigner_report" >/dev/null ||
  grep -iF -- "unsigned entries" "$jarsigner_report" >/dev/null; then
  echo "The App Bundle contains unverified or unsigned entries." >&2
  exit 1
fi

certificate_path="$verification_dir/certificate.txt"
"$keytool_path" -printcert -jarfile "$aab_path" >"$certificate_path"
if grep -F -- "CN=Android Debug" "$certificate_path" >/dev/null; then
  echo "Release artifact is signed with the Android debug certificate." >&2
  exit 1
fi
if [ "$ephemeral_signing" = true ] &&
  ! grep -F -- "CN=KISOU EPHEMERAL VERIFY ONLY" \
    "$certificate_path" >/dev/null; then
  echo "Ephemeral verification certificate marker is missing." >&2
  exit 1
fi

mapfile -t actual_certificate_fingerprints < <(
  sed -n 's/^[[:space:]]*SHA256: //p' "$certificate_path"
)
if [ "${#actual_certificate_fingerprints[@]}" -ne 1 ]; then
  echo "Expected exactly one App Bundle signing certificate." >&2
  exit 1
fi
actual_certificate_sha256="$(
  printf '%s' "${actual_certificate_fingerprints[0]}" |
    tr -d '[:space:]:' |
    tr 'a-f' 'A-F'
)"
if ! [[ "$actual_certificate_sha256" =~ ^[0-9A-F]{64}$ ]]; then
  echo "Could not read the App Bundle signing certificate fingerprint." >&2
  exit 1
fi
normalized_expected_sha256="$(
  printf '%s' "$expected_certificate_sha256" |
    tr -d '[:space:]:' |
    tr 'a-f' 'A-F'
)"
if ! [[ "$normalized_expected_sha256" =~ ^[0-9A-F]{64}$ ]]; then
  echo "The pinned certificate SHA-256 must contain exactly 64 hex digits." >&2
  exit 1
fi
if [ "$actual_certificate_sha256" != "$normalized_expected_sha256" ]; then
  echo "The App Bundle signer does not match the pinned certificate." >&2
  exit 1
fi

manifest_path="$verification_dir/AndroidManifest.xml"
unzip -p "$aab_path" base/manifest/AndroidManifest.xml >"$manifest_path"
if ! grep -aF -- "cloud.znak99.kisou" "$manifest_path" >/dev/null; then
  echo "Production application ID is missing from the manifest." >&2
  exit 1
fi
if grep -aF -- "cloud.znak99.kisou.dev" "$manifest_path" >/dev/null; then
  echo "Development application ID leaked into the release manifest." >&2
  exit 1
fi

mapfile -t libraries < <(
  unzip -Z1 "$aab_path" | grep '/libapp\.so$' || true
)
if [ "${#libraries[@]}" -eq 0 ]; then
  echo "No Dart AOT libraries were found in the App Bundle." >&2
  exit 1
fi

library_index=0
for library in "${libraries[@]}"; do
  library_path="$verification_dir/libapp-$library_index.so"
  unzip -p "$aab_path" "$library" >"$library_path"
  if ! grep -aF -- "https://kisou.znak99.cloud" \
    "$library_path" >/dev/null; then
    echo "Production API URL is missing from $library." >&2
    exit 1
  fi
  for forbidden in \
    "http://127.0.0.1" \
    "http://10.0.2.2" \
    "dev-test-user" \
    "dev-user-"; do
    if grep -aF -- "$forbidden" "$library_path" >/dev/null; then
      echo "Development marker leaked into $library: $forbidden" >&2
      exit 1
    fi
  done
  library_index=$((library_index + 1))
done

echo "Android release verification passed: signed, prod-only, and intact."

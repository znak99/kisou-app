#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

aab_path="build/app/outputs/bundle/prodRelease/app-prod-release.aab"
temporary_signing_dir=""
release_build_started=false
keep_owner_artifact=false

cleanup() {
  local status="$?"
  trap - EXIT
  if [ -n "$temporary_signing_dir" ]; then
    rm -rf -- "$temporary_signing_dir"
  fi
  if [ "$release_build_started" = true ] &&
    [ "$keep_owner_artifact" != true ]; then
    rm -f -- "$aab_path"
  fi
  exit "$status"
}
trap cleanup EXIT

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

signing_environment_names=(
  KISOU_ANDROID_KEYSTORE_PATH
  KISOU_ANDROID_KEYSTORE_PASSWORD
  KISOU_ANDROID_KEY_ALIAS
  KISOU_ANDROID_KEY_PASSWORD
  KISOU_ANDROID_CERT_SHA256
)
configured_environment_count=0
for name in "${signing_environment_names[@]}"; do
  if [ -n "${!name:-}" ]; then
    configured_environment_count=$((configured_environment_count + 1))
  fi
done

if [ "$configured_environment_count" -ne 0 ] &&
  [ "$configured_environment_count" -ne "${#signing_environment_names[@]}" ]; then
  echo "Provide all five KISOU_ANDROID_* signing variables or none." >&2
  exit 1
fi

external_properties_path="${KISOU_ANDROID_KEY_PROPERTIES_PATH:-}"
local_properties_path="android/key.properties"
signing_source_count=0
if [ -n "$external_properties_path" ]; then
  signing_source_count=$((signing_source_count + 1))
fi
if [ "$configured_environment_count" -ne 0 ]; then
  signing_source_count=$((signing_source_count + 1))
fi
if [ -f "$local_properties_path" ]; then
  signing_source_count=$((signing_source_count + 1))
fi
if [ "$signing_source_count" -gt 1 ]; then
  echo "Configure exactly one Android release signing source." >&2
  exit 1
fi
if [ -n "$external_properties_path" ] &&
  [ ! -f "$external_properties_path" ]; then
  echo "The external Android signing properties file does not exist." >&2
  exit 1
fi
if [ -n "$external_properties_path" ]; then
  external_properties_path="$(
    cd "$(dirname "$external_properties_path")" &&
      printf '%s/%s\n' "$PWD" "$(basename "$external_properties_path")"
  )"
  export KISOU_ANDROID_KEY_PROPERTIES_PATH="$external_properties_path"
fi

read_certificate_fingerprint() {
  sed -n \
    's/^[[:space:]]*certificateSha256[[:space:]]*=[[:space:]]*//p' \
    "$1" |
    tail -n 1
}

owner_signing=false
expected_certificate_sha256=""
if [ -n "$external_properties_path" ]; then
  owner_signing=true
  expected_certificate_sha256="$(
    read_certificate_fingerprint "$external_properties_path"
  )"
elif [ "$configured_environment_count" -ne 0 ]; then
  owner_signing=true
  expected_certificate_sha256="$KISOU_ANDROID_CERT_SHA256"
elif [ -f "$local_properties_path" ]; then
  owner_signing=true
  expected_certificate_sha256="$(
    read_certificate_fingerprint "$local_properties_path"
  )"
fi
if [ "$owner_signing" = true ]; then
  if [ "${KISOU_ALLOW_EPHEMERAL_SIGNING:-0}" = "1" ]; then
    echo "Owner signing and ephemeral signing cannot be requested together." >&2
    exit 1
  fi
  normalized_owner_certificate_sha256="$(
    printf '%s' "$expected_certificate_sha256" |
      tr -d '[:space:]:' |
      tr 'a-f' 'A-F'
  )"
  if ! [[ "$normalized_owner_certificate_sha256" =~ ^[0-9A-F]{64}$ ]]; then
    echo "The pinned certificate SHA-256 must contain exactly 64 hex digits." >&2
    exit 1
  fi
  expected_certificate_sha256="$normalized_owner_certificate_sha256"
fi

if [ "${GITHUB_ACTIONS:-false}" = "true" ] &&
  [ "$owner_signing" = true ]; then
  echo "GitHub Actions must use an ephemeral verification key only." >&2
  exit 1
fi

ephemeral_signing=false
if [ "$owner_signing" = false ]; then
  if [ "${KISOU_ALLOW_EPHEMERAL_SIGNING:-0}" != "1" ]; then
    echo "Release signing is not configured." >&2
    echo "Create android/key.properties from key.properties.example, or set" >&2
    echo "KISOU_ALLOW_EPHEMERAL_SIGNING=1 for a non-distributable check." >&2
    exit 1
  fi

  keytool_path="$(find_jdk_tool keytool)"
  temporary_signing_dir="$(mktemp -d)"
  chmod 700 "$temporary_signing_dir"

  export KISOU_ANDROID_KEYSTORE_PATH="$temporary_signing_dir/ephemeral.p12"
  export KISOU_ANDROID_KEYSTORE_PASSWORD
  KISOU_ANDROID_KEYSTORE_PASSWORD="$(openssl rand -hex 24)"
  if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    echo "::add-mask::$KISOU_ANDROID_KEYSTORE_PASSWORD"
  fi
  export KISOU_ANDROID_KEY_ALIAS="kisou-ephemeral-verification"
  export KISOU_ANDROID_KEY_PASSWORD="$KISOU_ANDROID_KEYSTORE_PASSWORD"

  "$keytool_path" -genkeypair -noprompt \
    -storetype PKCS12 \
    -keystore "$KISOU_ANDROID_KEYSTORE_PATH" \
    -storepass:env KISOU_ANDROID_KEYSTORE_PASSWORD \
    -keypass:env KISOU_ANDROID_KEY_PASSWORD \
    -alias "$KISOU_ANDROID_KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 2 \
    -dname "CN=KISOU EPHEMERAL VERIFY ONLY,OU=CI,O=KISOU,L=Tokyo,ST=Tokyo,C=JP"
  expected_certificate_sha256="$(
    "$keytool_path" -list -v \
      -keystore "$KISOU_ANDROID_KEYSTORE_PATH" \
      -storepass:env KISOU_ANDROID_KEYSTORE_PASSWORD \
      -alias "$KISOU_ANDROID_KEY_ALIAS" |
      sed -n 's/^[[:space:]]*SHA256: //p' |
      tail -n 1
  )"
  ephemeral_signing=true
fi

echo "Building the production App Bundle with non-debug signing."
if [ "$ephemeral_signing" = true ]; then
  echo "EPHEMERAL VERIFICATION MODE: the result must never be uploaded."
fi

release_build_started=true
rm -f -- "$aab_path"
flutter pub get
flutter build appbundle \
  --release \
  --flavor prod \
  --dart-define-from-file=config/prod.json

bash scripts/verify_android_release.sh \
  "$aab_path" \
  "$ephemeral_signing" \
  "$expected_certificate_sha256"

if [ "$ephemeral_signing" = true ]; then
  if [ "${GITHUB_ACTIONS:-false}" = "true" ]; then
    rm -f -- "$aab_path"
    echo "Ephemeral CI artifact deleted after verification."
  else
    verification_dir="build/verification"
    verification_path="$verification_dir/KISOU-prod-EPHEMERAL-NOT-FOR-STORE.aab"
    mkdir -p "$verification_dir"
    mv "$aab_path" "$verification_path"
    echo "Verification artifact: $verification_path"
  fi
else
  keep_owner_artifact=true
  echo "Owner-signed artifact: $aab_path"
  echo "Play Console registration and final device checks are still required."
fi

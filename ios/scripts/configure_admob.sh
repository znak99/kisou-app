#!/bin/sh

set -eu
export LC_ALL=C

readonly google_sample_ios_app_id="ca-app-pub-3940256099942544~1458002511"
readonly google_sample_publisher_id="3940256099942544"

case "$#" in
  0) validation_only=false ;;
  1)
    if [ "$1" != "--validate-only" ]; then
      /bin/echo "error: Unexpected configure_admob.sh argument." >&2
      exit 1
    fi
    validation_only=true
    ;;
  *)
    /bin/echo "error: Unexpected configure_admob.sh arguments." >&2
    exit 1
    ;;
esac

fail() {
  /bin/echo "error: $1" >&2
  exit 1
}

decoded_file=
cleanup() {
  if [ -n "$decoded_file" ] && [ -f "$decoded_file" ]; then
    /bin/rm -f "$decoded_file"
  fi
}
trap cleanup 0
trap 'exit 1' 1 2 15

is_live_app_id() {
  candidate=$1
  if ! /bin/echo "$candidate" |
    /usr/bin/grep -Eq '^ca-app-pub-[0-9]{16}~[0-9]{10}$'; then
    return 1
  fi
  case "$candidate" in
    "ca-app-pub-${google_sample_publisher_id}"*) return 1 ;;
  esac
  return 0
}

is_live_ad_unit_id() {
  candidate=$1
  if ! /bin/echo "$candidate" |
    /usr/bin/grep -Eq '^ca-app-pub-[0-9]{16}/[0-9]{10}$'; then
    return 1
  fi
  case "$candidate" in
    "ca-app-pub-${google_sample_publisher_id}"*) return 1 ;;
  esac
  return 0
}

ads_enabled=false
app_environment=
android_app_id=
android_banner_id=
android_rewarded_id=
ios_app_id=
ios_banner_id=
ios_rewarded_id=
seen_keys="|"
raw_defines=${DART_DEFINES-}

if [ -n "$raw_defines" ]; then
  case "$raw_defines" in
    ,* | *, | *,,*) fail "DART_DEFINES contains an empty entry." ;;
  esac

  temporary_directory=${TMPDIR:-/tmp}
  decoded_file=$(
    /usr/bin/mktemp "${temporary_directory%/}/kisou-admob.XXXXXX"
  ) || fail "Unable to create a private DART_DEFINES workspace."

  previous_ifs=$IFS
  IFS=,
  set -- $raw_defines
  IFS=$previous_ifs

  for encoded_entry in "$@"; do
    if ! /bin/echo "$encoded_entry" |
      /usr/bin/grep -Eq \
        '^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$'; then
      fail "DART_DEFINES contains malformed base64."
    fi
    if ! /usr/bin/printf '%s' "$encoded_entry" |
      /usr/bin/base64 -D >"$decoded_file" 2>/dev/null; then
      fail "DART_DEFINES contains invalid base64."
    fi
    canonical_entry=$(
      /usr/bin/base64 <"$decoded_file" | /usr/bin/tr -d '\r\n'
    ) || fail "Unable to verify canonical DART_DEFINES encoding."
    if [ "$canonical_entry" != "$encoded_entry" ]; then
      fail "DART_DEFINES must use canonical base64 encoding."
    fi
    if ! /usr/bin/iconv \
      -f UTF-8 \
      -t UTF-8 \
      "$decoded_file" >/dev/null 2>&1; then
      fail "DART_DEFINES entries must use valid UTF-8."
    fi
    if /usr/bin/od -An -tx1 -v "$decoded_file" |
      /usr/bin/grep -Eq \
        '(^|[[:space:]])(0[0-9a-f]|1[0-9a-f]|7f)([[:space:]]|$)'; then
      fail "DART_DEFINES entries must not contain control characters."
    fi
    decoded_entry=$(/bin/cat "$decoded_file")
    case "$decoded_entry" in
      *=*) ;;
      *) fail "DART_DEFINES entries must use key=value." ;;
    esac

    key=${decoded_entry%%=*}
    value=${decoded_entry#*=}
    if ! /bin/echo "$key" |
      /usr/bin/grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'; then
      fail "DART_DEFINES contains an invalid key."
    fi
    case "$seen_keys" in
      *"|${key}|"*) fail "DART_DEFINES contains a duplicate key." ;;
    esac
    seen_keys="${seen_keys}${key}|"

    case "$key" in
      ADS_ENABLED) ads_enabled=$value ;;
      APP_ENV) app_environment=$value ;;
      ADMOB_ANDROID_APP_ID) android_app_id=$value ;;
      ADMOB_ANDROID_BANNER_ID) android_banner_id=$value ;;
      ADMOB_ANDROID_REWARDED_ID) android_rewarded_id=$value ;;
      ADMOB_IOS_APP_ID) ios_app_id=$value ;;
      ADMOB_IOS_BANNER_ID) ios_banner_id=$value ;;
      ADMOB_IOS_REWARDED_ID) ios_rewarded_id=$value ;;
    esac
  done
fi

case "$ads_enabled" in
  true | false) ;;
  *) fail "ADS_ENABLED must be exactly true or false." ;;
esac

configuration=${CONFIGURATION-}
case "$configuration" in
  *-dev)
    flavor=dev
    expected_environment=development
    ;;
  *-prod | Debug | Profile | Release)
    flavor=prod
    expected_environment=production
    ;;
  *) fail "Unsupported Xcode configuration for AdMob setup." ;;
esac

if [ -n "$app_environment" ] &&
  [ "$app_environment" != "$expected_environment" ]; then
  fail "APP_ENV does not match the selected iOS flavor."
fi

resolved_environment=$app_environment
if [ -z "$resolved_environment" ]; then
  case "$configuration" in
    Release*) resolved_environment=production ;;
    *) resolved_environment=development ;;
  esac
fi

selected_app_id=$google_sample_ios_app_id
if [ "$ads_enabled" = true ]; then
  if [ "$resolved_environment" != "$expected_environment" ]; then
    fail "ADS_ENABLED=true requires APP_ENV to match the iOS flavor."
  fi
  if [ "$flavor" = prod ]; then
    if ! is_live_app_id "$android_app_id"; then
      fail "ADMOB_ANDROID_APP_ID must be a live AdMob app ID."
    fi
    if ! is_live_app_id "$ios_app_id"; then
      fail "ADMOB_IOS_APP_ID must be a live AdMob app ID."
    fi
    if ! is_live_ad_unit_id "$android_banner_id"; then
      fail "ADMOB_ANDROID_BANNER_ID must be a live AdMob ad unit ID."
    fi
    if ! is_live_ad_unit_id "$android_rewarded_id"; then
      fail "ADMOB_ANDROID_REWARDED_ID must be a live AdMob ad unit ID."
    fi
    if ! is_live_ad_unit_id "$ios_banner_id"; then
      fail "ADMOB_IOS_BANNER_ID must be a live AdMob ad unit ID."
    fi
    if ! is_live_ad_unit_id "$ios_rewarded_id"; then
      fail "ADMOB_IOS_REWARDED_ID must be a live AdMob ad unit ID."
    fi
    selected_app_id=$ios_app_id
  fi
fi

if [ "$validation_only" = true ]; then
  exit 0
fi

target_build_dir=${TARGET_BUILD_DIR-}
info_plist_path=${INFOPLIST_PATH-}
if [ -z "$target_build_dir" ] || [ -z "$info_plist_path" ]; then
  fail "Xcode did not provide the built Info.plist path."
fi
built_info_plist="${target_build_dir}/${info_plist_path}"
if [ ! -f "$built_info_plist" ]; then
  fail "The built Info.plist is unavailable."
fi

/usr/bin/plutil \
  -replace GADApplicationIdentifier \
  -string "$selected_app_id" \
  "$built_info_plist" ||
  fail "Unable to configure the built AdMob app ID."

actual_app_id=$(
  /usr/bin/plutil \
    -extract GADApplicationIdentifier \
    raw \
    "$built_info_plist" 2>/dev/null
) || fail "Unable to verify the built AdMob app ID."
if [ "$actual_app_id" != "$selected_app_id" ]; then
  fail "The built AdMob app ID does not match the Dart configuration."
fi

measurement_delayed=$(
  /usr/bin/plutil \
    -extract GADDelayAppMeasurementInit \
    raw \
    "$built_info_plist" 2>/dev/null
) || fail "Unable to verify delayed AdMob measurement."
if [ "$measurement_delayed" != true ]; then
  fail "AdMob measurement must remain delayed until consent is resolved."
fi

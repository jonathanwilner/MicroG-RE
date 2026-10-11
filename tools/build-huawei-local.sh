#!/usr/bin/env bash
# Run externally through nom-tmux, for example:
# nom-tmux microg-re-huawei-build -- bash tools/build-huawei-local.sh
# Local signing does not permit updating an upstream-signed installation.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
sign_only=false
case "${1:-}" in
  '') ;;
  --sign-only) sign_only=true ;;
  *) echo "Usage: $0 [--sign-only]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || exit 2
export ANDROID_HOME=${ANDROID_HOME:-"$HOME/Android/Sdk"}
if [[ -z ${JAVA_HOME:-} ]]; then
  if command -v javac >/dev/null; then
    JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
  else
    candidates=(/nix/store/*-openjdk-21.*/lib/openjdk)
    JAVA_HOME=${candidates[0]}
  fi
fi
export JAVA_HOME
[[ -x "$JAVA_HOME/bin/javac" ]] || { echo 'Set JAVA_HOME to a full JDK 17 or 21.' >&2; exit 1; }
export PATH="$JAVA_HOME/bin:$PATH"
build_tools=${ANDROID_BUILD_TOOLS:-"$ANDROID_HOME/build-tools/35.0.0"}
key_dir=${MICROG_KEY_DIR:-"$HOME/.local/share/microg-huawei-signing"}
keystore=${MICROG_KEYSTORE:-"$key_dir/release.p12"}
password_file=${MICROG_KEY_PASSWORD_FILE:-"$key_dir/password"}
key_alias=${MICROG_KEY_ALIAS:-microg-local}
# build/ is already ignored by this repository; dist/ is not.
output=${MICROG_OUTPUT_DIR:-"$root/build/local-huawei"}
zip_bin=${ZIP_BIN:-$(command -v zip || true)}
if [[ -z "$zip_bin" ]]; then
  candidates=(/nix/store/*-zip-*/bin/zip)
  zip_bin=${candidates[0]}
fi
for executable in "$zip_bin" "$build_tools/zipalign" "$build_tools/aapt2"; do
  [[ -x "$executable" ]] || { echo "Missing executable: $executable" >&2; exit 1; }
done
[[ -r "$keystore" && -r "$password_file" ]] || {
  echo 'Provide an existing signing key and password file using MICROG_KEYSTORE and MICROG_KEY_PASSWORD_FILE.' >&2
  exit 1
}
[[ -r "$build_tools/lib/apksigner.jar" ]] || exit 1
cd "$root"
if ! "$sign_only"; then
  ./gradlew :play-services-core:assembleHuaweiRelease -Pabi=arm64-v8a \
    --no-daemon --max-workers="${MICROG_BUILD_WORKERS:-6}" --console=plain
fi
apk_dir="$root/play-services-core/build/outputs/apk/huawei/release"
input=$(python3 - "$apk_dir" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
elements = json.loads((root / 'output-metadata.json').read_text())['elements']
arm64 = [e for e in elements if any(f.get('filterType') == 'ABI' and
         f.get('value') == 'arm64-v8a' for f in e.get('filters', []))]
if len(arm64) != 1:
    raise SystemExit('Expected exactly one ARM64 output; rebuild with -Pabi=arm64-v8a.')
print(root / arm64[0]['outputFile'])
PY
)
mkdir -p "$output"
scratch=$(mktemp -d "$output/.sign-XXXXXX")
trap 'rm -rf "$scratch"' EXIT
name="$(basename "$input" .apk)-arm64-local"
apk="$scratch/$name.apk"
# Normalize malformed ZIP extra padding before alignment and signing.
"$zip_bin" -q -X "$input" --out "$scratch/normalized.apk"
"$build_tools/zipalign" -f -P 16 4 "$scratch/normalized.apk" "$apk"
java -jar "$build_tools/lib/apksigner.jar" sign --ks "$keystore" \
  --ks-key-alias "$key_alias" --ks-pass "file:$password_file" \
  --alignment-preserved true "$apk"
"$build_tools/zipalign" -c -P 16 4 "$apk"
java -jar "$build_tools/lib/apksigner.jar" verify --verbose --print-certs "$apk" > "$scratch/$name-validation.txt"
unzip -t "$apk" > "$scratch/$name-zip.txt"
"$build_tools/aapt2" dump badging "$apk" > "$scratch/$name-badging.txt"
python3 - "$scratch/$name-badging.txt" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
if "package: name='app.revanced.android.gms'" not in text:
    raise SystemExit('Unexpected package identity.')
package_line = text.splitlines()[0]
if "-hw'" not in package_line:
    raise SystemExit('Expected Huawei version suffix.')
for permission in ('RECEIVE_SMS', 'READ_SMS', 'SEND_SMS'):
    if "name='android.permission." + permission + "'" in text:
        raise SystemExit('Unexpected SMS permission: ' + permission)
abis = [line for line in text.splitlines() if line.startswith('native-code:')]
if abis != ["native-code: 'arm64-v8a'"]:
    raise SystemExit('Expected ARM64-only native libraries: ' + repr(abis))
PY
for file in "$apk" "$scratch/$name-validation.txt" "$scratch/$name-zip.txt" "$scratch/$name-badging.txt"; do
  mv "$file" "$output/"
done
[[ ! -f "$apk.idsig" ]] || mv "$apk.idsig" "$output/"
(cd "$output"; sha256sum "$name.apk" > "$name.sha256")
cat "$output/$name.sha256"
printf 'Verified local APK: %s/%s.apk\n' "$output" "$name"

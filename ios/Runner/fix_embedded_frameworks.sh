#!/bin/bash

set -euo pipefail

if [[ "${CODE_SIGNING_ALLOWED:-NO}" != "YES" ]]; then
  exit 0
fi

if [[ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  exit 0
fi

frameworks_dir="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks"
if [[ ! -d "${frameworks_dir}" ]]; then
  exit 0
fi

read -r -a target_archs <<< "${ARCHS:-}"

thin_framework_binary() {
  local binary="$1"

  if ! /usr/bin/lipo -info "${binary}" >/dev/null 2>&1; then
    return 0
  fi

  local available_archs
  available_archs="$(/usr/bin/lipo -archs "${binary}")"

  local desired_archs=()
  local arch
  for arch in "${target_archs[@]}"; do
    if [[ " ${available_archs} " == *" ${arch} "* ]]; then
      desired_archs+=("${arch}")
    fi
  done

  if [[ "${#desired_archs[@]}" -eq 0 ]]; then
    return 0
  fi

  if [[ "${available_archs}" == "${desired_archs[*]}" ]]; then
    return 0
  fi

  local output="${binary}.thin"
  local lipo_args=()
  for arch in "${desired_archs[@]}"; do
    lipo_args+=(-extract "${arch}")
  done

  /usr/bin/lipo "${lipo_args[@]}" "${binary}" -output "${output}"
  /bin/mv "${output}" "${binary}"
}

for framework in "${frameworks_dir}"/*.framework; do
  [[ -d "${framework}" ]] || continue

  executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${framework}/Info.plist" 2>/dev/null || /usr/bin/basename "${framework}" .framework)"
  binary_path="${framework}/${executable_name}"

  if [[ -f "${binary_path}" ]]; then
    thin_framework_binary "${binary_path}"
  fi

  /usr/bin/codesign \
    --force \
    --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
    --timestamp=none \
    --preserve-metadata=identifier,flags \
    "${framework}"
done

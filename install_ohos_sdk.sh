#!/usr/bin/env bash

set -eux

: "${INPUT_VERSION:?INPUT_VERSION needs to be set}"
: "${INPUT_MIRROR:?INPUT_MIRROR needs to be set}"

# https://repo.huaweicloud.com/openharmony/os/4.0-Release/ohos-sdk-windows_linux-public.tar.gz

URL_BASE="https://repo.huaweicloud.com/openharmony/os"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_FILENAME="ohos-sdk-windows_linux-public.tar.gz"
        OS=linux
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == 'arm64' ]]; then
        OS_FILENAME="L2-SDK-MAC-M1-PUBLIC.tar.gz"
    else
        OS_FILENAME="ohos-sdk-mac-public.tar.gz"
    fi
   OS=mac
elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS_FILENAME="ohos-sdk-windows_linux-public.tar.gz"
        OS=windows
else
        echo "Unknown OS type. The OHOS SDK is only available for Windows, Linux and macOS."
        exit 1
fi

WORK_DIR="${HOME}/setup-ohos-sdk"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# RESOLVED_MIRROR_VERSION_TAG is both in- and output of this function.
# If the user provides a version like `5.0`, we try to resolve the version to something more specific like `5.0.0`,
# since we can't easily have aliasing releases on Github. (e.g. 5.0 pointing to the latest 5.0.x release)
function select_version() {
  local base_tag_version="${RESOLVED_MIRROR_VERSION_TAG}"
  local available_releases
  local exact_version_res
  local latest_compatible_version
  available_releases=$(gh release list --repo openharmony-rs/ohos-sdk --json 'tagName')
  # Note: jq doesn't seem to return an error if select doesn't find anything
  exact_version_res=$(jq ".[] | select(.tagName == \"${base_tag_version}\")" <<< "${available_releases}")
  if [[ -n "${exact_version_res}" ]]; then
    # If we found an exactly matching release, then we don't need to do anything.
    return 0
  fi
  # Otherwise, get the first (== latest) release matching the start of our version tag (e.g. `5.0.3` for input `5.0`)
  latest_compatible_version=$(jq "[.[] | select(.tagName | startswith(\"${base_tag_version}.\"))][0].tagName" <<< "${available_releases}" | tr -d '"')
  if [[ -n "${latest_compatible_version}" ]]; then
    echo "Resolved version ${base_tag_version} to release ${latest_compatible_version}"
    RESOLVED_MIRROR_VERSION_TAG="${latest_compatible_version}"
  else
    echo "Couldn't find any compatible release on the mirror."
  fi
}

# Assumption: cwd contains the zipped components.
# Outputs: API_VERSION
function extract_sdk_components() {
    if [[ "${INPUT_COMPONENTS}" == "all" ]]; then
      COMPONENTS=(*.zip)
    else
      IFS=";" read -ra COMPONENTS <<< "${INPUT_COMPONENTS}"
      resolved_components=()
      for COMPONENT in "${COMPONENTS[@]}"
      do
        resolved_components+=("${COMPONENT}"-*.zip)
      done
      COMPONENTS=(${resolved_components[@]})
    fi

    for COMPONENT in "${COMPONENTS[@]}"
    do
        echo "Extracting component ${COMPONENT}"
        echo "::group::Unzipping archive"
        #shellcheck disable=SC2144
        if [[ -f "${COMPONENT}" ]]; then
          unzip "${COMPONENT}"
        else
          echo "Failed to find component ${COMPONENT}"
          ls -la
          exit 1
        fi
        echo "::endgroup::"
        # Removing everything after the first dash should give us the component dir
        component_dir=${COMPONENT%%-*}
        API_VERSION=$(jq -r '.apiVersion' < "${component_dir}/oh-uni-package.json")
        if [ "$INPUT_FIXUP_PATH" = "true" ]; then
            mkdir -p "${API_VERSION}"
            mv "${component_dir}" "${API_VERSION}/"
        fi
    done
    rm ./*.zip
}

function download_and_extract_sdk() {
    MIRROR_DOWNLOAD_SUCCESS=false
    if [[ "${INPUT_MIRROR}" == "true" || "${INPUT_MIRROR}" == "force" ]]; then
      RESOLVED_MIRROR_VERSION_TAG="v${INPUT_VERSION}"
      select_version # This will update RESOLVED_MIRROR_VERSION_TAG.
      gh release download "${RESOLVED_MIRROR_VERSION_TAG}" --pattern "${OS_FILENAME}*" --repo openharmony-rs/ohos-sdk && MIRROR_DOWNLOAD_SUCCESS=true
      if [[ "${MIRROR_DOWNLOAD_SUCCESS}" == "true" ]]; then
        # The mirror may have split the archives due to the Github releases size limits.
        # First rename the sha256 file, so we don't glob it.
        mv "${OS_FILENAME}.sha256" "sha256.${OS_FILENAME}"
        # Now get all the .aa .ab etc. output of the split command for our filename
        shopt -s nullglob
        split_files=("${OS_FILENAME}".*)
        if [ ${#split_files[@]} -ne  0 ]; then
          cat "${split_files[@]}" > "${OS_FILENAME}"
          rm "${split_files[@]}"
        fi
        # Rename the shafile back again to the original name
        mv "sha256.${OS_FILENAME}" "${OS_FILENAME}.sha256"
      elif [[ "${INPUT_MIRROR}" == "force" ]]; then
        echo "Downloading from mirror failed, and mirror=force. Failing the job."
        echo "Note: mirror=force is for internal test purposes, and should not be selected by users."
        exit 1
      else
        echo "Failed to download SDK from mirror. Falling back to downloading from upstream."
      fi
    fi
    if [[ "${MIRROR_DOWNLOAD_SUCCESS}" != "true" ]]; then
      DOWNLOAD_URL="${URL_BASE}/${INPUT_VERSION}-Release/${OS_FILENAME}"
      echo "Downloading OHOS SDK from ${DOWNLOAD_URL}"
      curl --fail -L -O "${DOWNLOAD_URL}"
      curl --fail -L -O "${DOWNLOAD_URL}.sha256"
    fi

    VERSION_MAJOR=${INPUT_VERSION%%.*}

    if [[ "${OS}" == "mac" ]]; then
        echo "$(cat "${OS_FILENAME}".sha256)  ${OS_FILENAME}" | shasum -a 256 --check --status
        tar -xf "${OS_FILENAME}" --strip-components=3
    else
        echo "$(cat "${OS_FILENAME}".sha256) ${OS_FILENAME}" | sha256sum --check --status
        if (( VERSION_MAJOR >= 5 )); then
          tar -xf "${OS_FILENAME}"
        else
          tar -xf "${OS_FILENAME}" --strip-components=1
        fi
    fi
    rm "${OS_FILENAME}" "${OS_FILENAME}.sha256"

    if [[ "${OS}" == "linux" ]]; then
        rm -rf windows
        cd linux
    elif [[ "${OS}" == "windows" ]]; then
        rm -rf linux
        cd windows
    else
        cd darwin
    fi
    OHOS_BASE_SDK_HOME="$PWD"
    extract_sdk_components
}

echo "sdk-path=$PWD" >> "${GITHUB_OUTPUT}"

if [[ "${INPUT_CACHE}" != "true" || "${INPUT_WAS_CACHED}" != "true" ]]; then
    download_and_extract_sdk
else
    if [[ "${OS}" == "linux" ]]; then
        cd linux
    elif [[ "${OS}" == "windows" ]]; then
        cd windows
    else
        cd darwin
    fi
    OHOS_BASE_SDK_HOME="$PWD"
fi

if [ "${INPUT_FIXUP_PATH}" = "true" ]; then
  # When we are restoring from cache we don't know the API version, so we glob for now.
  # In the future we should do something more robust, like copying `oh-uni-package.json` to the root.
  OHOS_NDK_HOME=$(cd "${OHOS_BASE_SDK_HOME}"/* && pwd)
  OHOS_SDK_NATIVE="${OHOS_NDK_HOME}"/native
else
  OHOS_NDK_HOME="${OHOS_BASE_SDK_HOME}"
  OHOS_SDK_NATIVE="${OHOS_BASE_SDK_HOME}/native"
fi

cd "${OHOS_SDK_NATIVE}"
SDK_VERSION="$(jq -r .version < oh-uni-package.json )"
API_VERSION="$(jq -r .apiVersion < oh-uni-package.json )"
echo "OHOS_BASE_SDK_HOME=${OHOS_BASE_SDK_HOME}" >> "$GITHUB_ENV"
echo "ohos-base-sdk-home=${OHOS_BASE_SDK_HOME}" >> "$GITHUB_OUTPUT"
echo "OHOS_NDK_HOME=${OHOS_NDK_HOME}" >> "$GITHUB_ENV"
echo "OHOS_SDK_NATIVE=${OHOS_SDK_NATIVE}" >> "$GITHUB_ENV"
echo "ohos_sdk_native=${OHOS_SDK_NATIVE}" >> "$GITHUB_OUTPUT"
echo "sdk-version=${SDK_VERSION}" >> "$GITHUB_OUTPUT"
echo "api-version=${API_VERSION}" >> "$GITHUB_OUTPUT"

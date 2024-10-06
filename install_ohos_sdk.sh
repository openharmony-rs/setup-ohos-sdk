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

cd "${HOME}"

MIRROR_DOWNLOAD_SUCCESS=false
if [[ "${INPUT_MIRROR}" == "true" || "${INPUT_MIRROR}" == "force" ]]; then
  gh release download "v${INPUT_VERSION}" --pattern "${OS_FILENAME}*" --repo openharmony-rs/ohos-sdk && MIRROR_DOWNLOAD_SUCCESS=true
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

if [[ "${OS}" == "mac" ]]; then
    echo "$(cat "${OS_FILENAME}".sha256)  ${OS_FILENAME}" | shasum -a 256 --check --status
    tar -xf "${OS_FILENAME}" --strip-components=2
else
    echo "$(cat "${OS_FILENAME}".sha256) ${OS_FILENAME}" | sha256sum --check --status
    tar -xf "${OS_FILENAME}"
fi
rm "${OS_FILENAME}" "${OS_FILENAME}.sha256"
cd ohos-sdk

if [[ "${OS}" == "linux" ]]; then
    rm -rf windows
    cd linux
elif [[ "${OS}" == "windows" ]]; then
    rm -rf linux
    cd windows
else
    cd darwin
fi

IFS=";" read -ra COMPONENTS <<< "${INPUT_COMPONENTS}"
for COMPONENT in "${COMPONENTS[@]}"
do
    echo "Extracting component ${COMPONENT}"
    unzip "${COMPONENT}"-*.zip
    API_VERSION=$(cat "${COMPONENT}/oh-uni-package.json" | jq -r '.apiVersion')
    if [ "$INPUT_FIXUP_PATH" = "true" ]; then
        mkdir -p "${API_VERSION}"
        mv "${COMPONENT}" "${API_VERSION}/"
    fi
done
rm ./*.zip

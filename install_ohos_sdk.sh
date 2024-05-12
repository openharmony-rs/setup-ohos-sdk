#!/usr/bin/env bash

set -eu

: "${INPUT_VERSION:?INPUT_VERSION needs to be set}"

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
        echo "Unknown OS type. The OHOS SDK is only available for Windows, Linux and Mqd."
fi

DOWNLOAD_URL="${URL_BASE}/${INPUT_VERSION}-Release/${OS_FILENAME}"

echo "Downloading OHOS SDK from ${DOWNLOAD_URL}"

curl --fail -L -o "${HOME}/openharmony-sdk.tar.gz" "${DOWNLOAD_URL}"
cd "${HOME}"
if [[ "${OS}" == "mac" ]]; then
    tar -xf openharmony-sdk.tar.gz --strip-components=2
else
    tar -xf openharmony-sdk.tar.gz
fi
rm openharmony-sdk.tar.gz
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

# Todo: expose available components via an input variable.
# For now just extract native, to save disk space

unzip native-*.zip
rm ./*.zip

cd native

#!/bin/bash -eu

case $(arch) in
    aarch64):
        ARCH=arm64
        ;;
    x86_64):
        ARCH=x86_64
        ;;
    *)
        echo "Unknown architecture"
        exit 1
        ;;
esac

URL=$(curl -Ls https://api.github.com/repos/chipsalliance/verible/releases/latest | jq --raw-output ".assets[] | select(.name|test(\"${ARCH}\")).browser_download_url")

curl -Lsf ${URL} -o /tmp/verible.tar.gz
tar xf /tmp/verible.tar.gz -C /tmp
mv /tmp/verible-*/bin/* /usr/local/bin
rm -rf /tmp/verible*
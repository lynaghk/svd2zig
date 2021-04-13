#!/usr/bin/env bash

set -e

cd "$( dirname $0 )"

mkdir -p vendor/
cd vendor/

wget -nc https://raw.githubusercontent.com/NordicSemiconductor/nrfx/d779b49fc59c7a165e7da1d7cd7d57b28a059f16/mdk/nrf52833.svd
wget -nc https://raw.githubusercontent.com/NordicSemiconductor/nrfx/d779b49fc59c7a165e7da1d7cd7d57b28a059f16/mdk/nrf52840.svd
# wget -nc https://stm32-rs.github.io/stm32-rs/stm32f103.svd.patched 
wget -nc https://stm32-rs.github.io/stm32-rs/stm32f0x0.svd.patched

cd ../

clojure generate_registers.clj
zig fmt target/*

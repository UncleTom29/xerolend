#!/bin/bash

echo "Building all SP1 programs..."

cd collateral-value
cargo build --release
cd ..

cd loan-amount
cargo build --release
cd ..

cd reputation
cargo build --release
cd ..

echo "All SP1 programs built successfully!"
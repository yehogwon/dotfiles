#!/bin/bash

set -e

# usage: bash retrieve_wheels.sh <pip|uv> <index_url> <package_names>

if [[ "$1" != "pip" && "$1" != "uv" ]]; then
    echo "Invalid argument. Use 'pip' or 'uv'."
    exit 1
fi

if [[ "$1" == "pip" ]]; then
    manager="pip"
elif [[ "$1" == "uv" ]]; then
    manager="uv pip"
else
    echo "Invalid package manager. Use 'pip' or 'uv'."
    exit 1
fi


if ! command -v $manager &> /dev/null; then
    echo "$manager is not found."
    exit 1
fi

index_url=$2

shift 2
package_names=("$@")

wheel_file=$(mktemp)
$manager install --dry-run "${package_names[@]}" --index-url "$index_url" --verbose \
    2>&1 | grep '.whl' | grep -v '.metadata' | grep 'Selecting' | grep -oP '\(\K[^)]*(?=\))' > "$wheel_file"

index_file=$(mktemp)
echo "$index_url" > "$index_file"

out_file=$(mktemp)
script_dir="$(dirname "$0")"
python "$script_dir/retrieve_wheels.py" \
    --index_urls "$index_file" \
    --wheels "$wheel_file" \
    --output "$out_file" \
    --url_only

wheels_dir=$(mktemp -d)
cd "$wheels_dir"

_total_nproc=$(nproc)
np=$( (( 16 <= _total_nproc )) && echo "16" || echo "$_total_nproc" )
cat "$out_file" | xargs -n 1 -P "$np" wget

$manager install *.whl
$manager install "${package_names[@]}" --index-url "$index_url"

echo "$manager list --format=freeze shows:"
$manager list --format=freeze

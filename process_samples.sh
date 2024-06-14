#!/bin/bash

url="https://android.googlesource.com/platform/frameworks/support/+archive/refs/heads/androidx-main/car/app/app-samples.tar.gz"
filename="app-samples.tar.gz"
echo "Downloading $url ..."
curl -o $filename $url
extract_dir="app-samples"
mkdir -p $extract_dir
echo "Extracting $filename ..."
tar -xzf $filename -C $extract_dir
rm $filename

# Iterate through directories to rename files starting with "github_"
# This might need to be adjusted if the upstream repo changes
find $extract_dir -type f -name "github_*" | while read -r file; do
  dir=$(dirname "$file")
  base=$(basename "$file")
  new_name="${base#github_}"
  mv "$file" "$dir/$new_name"
done

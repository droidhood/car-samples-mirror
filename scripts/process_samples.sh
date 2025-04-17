#!/bin/bash

# Iterate through directories to rename files starting with "github_"
# This might need to be adjusted if the upstream repo changes
code_dir="car/app/app-samples"
find $code_dir -type f -name "github_*" | while read -r file; do
  dir=$(dirname "$file")
  base=$(basename "$file")
  new_name="${base#github_}"
  mv "$file" "$dir/$new_name"
done

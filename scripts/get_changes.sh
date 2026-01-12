#!/bin/bash

git clone --no-tags -b androidx-main --single-branch https://android.googlesource.com/platform/frameworks/support
cd support
git filter-repo --path car/app/app-samples/
cd ..
git remote add android_temp support
git fetch android_temp
git rebase android_temp/androidx-main
git remote remove android_temp
rm -rf support
git add .
git commit -m "Weekly update from AOSP"
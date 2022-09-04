#!/usr/bin/env bash

echo "[1] Build app"
cd App
xcodebuild build -scheme Santander -configuration "Release" CODE_SIGNING_ALLOWED="NO" CODE_SIGNING_REQUIRED="NO" CODE_SIGN_IDENTITY="" BUILD_DIR=../xcodebuild
cd ..

echo "[2] Build helper"
cd Helper
make clean
make FINALPACKAGE=1

cp .theos/obj/santanderhelper ../out/ipa/Payload/Santander.app/santanderhelper
ldid -s -K../cert.p12 -Upassword ../out/ipa/Payload/Santander.app/santanderhelper

echo "[3] Package IPA"
mkdir -p out/ipa/Payload
cp -R xcodebuild/Release-iphoneos/Santander.app out/ipa/Payload
ldid -SApp/entitlements.plist out/ipa/Payload/Santander.app
cd out/ipa
zip -r ../Santander.ipa .
cd ../..
rm -rf out/ipa xcodebuild

echo "IPA is in out/Santander.ipa"

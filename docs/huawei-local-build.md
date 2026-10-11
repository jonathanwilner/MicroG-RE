# Huawei ARM64 local build

Source: https://github.com/MorpheApp/MicroG-RE, release 7.2.1.

## Findings from upstream reports

- [#174](https://github.com/MorpheApp/MicroG-RE/issues/174) reports Huawei HarmonyOS/Droitong detecting MicroG RE as malware. The maintainer attributes this to the Huawei scanner and closes it as a duplicate of [#142](https://github.com/MorpheApp/MicroG-RE/issues/142).
- #142 calls the detection a false positive. Neither ticket identifies a source-code defect that causes the scanner verdict or provides a confirmed code fix.
- [#152](https://github.com/MorpheApp/MicroG-RE/issues/152) rejects package renaming as a solution. This build preserves `app.revanced.android.gms` for patched-app compatibility.
- [#284](https://github.com/MorpheApp/MicroG-RE/issues/284) reports both a malware warning and missing certificates. Signing and ZIP validation are therefore explicit build gates. They do not prove scanner acceptance.
- Release 7.2.1 includes [#293](https://github.com/MorpheApp/MicroG-RE/pull/293), fixing notification-registration authentication. Newer affected YouTube versions also need the corresponding [Morphe patches change](https://github.com/MorpheApp/morphe-patches/pull/3481).
- Upstream already removed `RECEIVE_SMS`. The final APK must be checked for SMS permissions; no scanner bypass or package disguise is included.

## Build and verification

Run the build through the local tracking wrapper:

```sh
nom-tmux build-microg-re-huawei-local -- tools/build-huawei-local.sh
```

The script builds the Huawei release for ARM64, normalizes ZIP metadata, aligns and signs the APK, and checks its signature, ZIP integrity, package metadata, and checksum. Signing keys remain outside the checkout. Generated artifacts are not source files.

## Installation boundary

A local signing certificate differs from the upstream certificate. Android normally refuses an in-place update signed with a different key. Do not uninstall the existing MicroG RE or clear its data to test this build without a separate migration decision. Preserve Framework Services and its existing app registrations.

Successful packaging is not a confirmed fix for Huawei's malware warning. That requires the exact generated APK to pass the phone's installation/scanning path. Notification registration and delivery require separate runtime tests with a compatible patched application.

## Verified local result, 11 Oct 2026

- Upstream source commit: `66a2bbac7`, version `7.2.1-hw`, version code `255070218`.
- `assembleHuaweiRelease -Pabi=arm64-v8a` completed successfully with JDK 21. No dependency-version changes were required.
- Signed artifact: `build/local-huawei/app.revanced.android.gms-255070218-hw-arm64-local.apk`.
- SHA-256: `a9b5c1a514cb66a35c4740055ab2ef675feedcd03bdc36df3b069c993996039b`.
- Signature verification, 16 KB ZIP alignment, ZIP integrity, Huawei version suffix, original package identity, ARM64-only libraries, and absence of RECEIVE_SMS/READ_SMS/SEND_SMS permissions passed.
- Initially device installation was unverified. The user subsequently authorized removal and reinstallation.
- Pura X Max installation completed on 11 Oct 2026. The installer displayed an unverified-app caution and permitted installation; no malware block appeared in this installation flow. The separate Huawei security scan remains untested.
- Launched version 7.2.1-hw, allowed notifications, disabled battery optimization, and retried device registration. Google registration succeeded and cloud messaging showed Connected. The push list currently contains MicroG RE itself; third-party notification delivery remains unverified.
- Evidence: https://debug.thewilners.com/#shot=20261011T172535Z-armstrong-pura-microg-re-install-d41eaecd36-f4072968

## Edge and Pro in-place update, 11 Oct 2026

Both tablets had MicroG RE 6.1.4, with no accounts shown and no registered
push applications. Installing the private-key build above was rejected because
the installed signing certificate differed. No app was uninstalled and no data
was cleared.

The archived `microg-6.1.4_sign.apk` uses the public AOSP test certificate,
SHA-256 `a40da80a59d170caa950cf15c18c454d47a39b26989d8b640ecd745ba71bf5dc`.
Signing the same 7.2.1-hw build with that existing certificate allowed both
updates in place. This retains their existing test-signing identity; it is not a
private production signing key. Use this compatibility artifact only for
installations that already have this certificate. The Pura uses the private
local key and remains on the original artifact.

- Compatibility artifact: https://remote.thewilners.com/apks/microg-re-7.2.1-huawei-arm64-compat.apk
- SHA-256: `4836c745fcef3619269536d7332533e11b3da2a69612120413e0a72f0ecea6a3`.
- All 3,085 APK entries outside META-INF are byte-identical to the original
  private-key build. APK signature verification and hosted download hash passed.
- Public certificate and key sources:
  `https://android.googlesource.com/platform/build/+/refs/heads/main/target/product/security/testkey.x509.pem?format=TEXT`
  and the matching `testkey.pk8?format=TEXT`. Decode their base64 responses.
- Re-sign with SDK `apksigner sign --key testkey.pk8 --cert testkey.x509.pem
  --out microg-re-7.2.1-huawei-arm64-compat.apk ORIGINAL.apk`, then verify with
  `apksigner verify --print-certs` and compare the certificate above.

Both devices accepted the ordinary installer caution and completed installation.
A transient network-verification failure cleared on retry. On launch, device
registration succeeded and Cloud Messaging reported Connected. Battery
optimization was disabled through the app's standard prompt. Each push list
contains MicroG RE itself; third-party notification delivery remains unverified.
Canonical Framework Services was not replaced or modified.

- [Edge connected](https://debug.thewilners.com/#shot=20261011T201853Z-huawei-edge-microg-re-fleet-487fd2f913-5e8350fc)
- [Pro connected](https://debug.thewilners.com/#shot=20261011T201853Z-huawei-pro-microg-re-fleet-fc7c53d0e6-31306766)
- [Pura rechecked connected](https://debug.thewilners.com/#shot=20261011T201649Z-pura-x-max-microg-re-fleet-34c5e46c58-178451fd)

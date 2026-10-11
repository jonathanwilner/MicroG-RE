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

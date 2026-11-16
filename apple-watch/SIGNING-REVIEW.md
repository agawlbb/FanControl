# Prepared signing and encryption correction

Apple upload validation returned three errors after distribution export succeeded:
- Container CFBundlePackageType must be APPL.
- Container code signature identifier must match dev.fancontrol.watch.
- Non-exempt encryption declaration requires a matching Apple compliance code.

Package type and stricter exported-signature checks are corrected in this checkout.

Specifically approved by the owner on 2026-10-18 after automatic approval review requested explicit confirmation:
1. Import the existing IOS_DEVELOPMENT_CERT_P12 and IOS_DEVELOPMENT_CERT_PASSWORD secrets into the temporary signing keychain on the existing trusted recipe GitHub repository runner. Archive with that identity, then use Apple's distribution export signing. Delete the temporary certificate file and keychain afterward. Do not copy credentials into the new repository, publish them, or revoke/create certificates.
2. Set ITSAppUsesNonExemptEncryption=false in both bundles for OS-provided encryption. Source inspection finds only Foundation, CryptoKit and Security imports, with no external cryptography dependencies or implemented encryption primitives. The app uses AES-GCM, SHA256 and RSA-OAEP through Apple frameworks; false means exempt encryption, not no encryption.

Apple reference: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
Apple lists crypto functionality within its operating system as requiring no export compliance documentation. Future crypto dependencies require reassessment.


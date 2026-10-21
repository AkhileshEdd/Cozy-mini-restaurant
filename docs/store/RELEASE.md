# Publishing on Google Play

A checklist for the first release. Everything in this folder is ready to upload; the steps marked **you** need your accounts.

## 1. Signing key and the `.aab` (once)

Google Play takes a signed Android App Bundle (`.aab`). CI builds it when the repository has your upload key:

1. **You:** in GitHub, open **Settings → Secrets and variables → Actions → New repository secret** and add:
   - `ANDROID_KEYSTORE_BASE64`: the upload keystore, base64-encoded
   - `ANDROID_KEYSTORE_ALIAS`: `upload`
   - `ANDROID_KEYSTORE_PASSWORD`: the keystore password
2. Re-run the latest **CI** workflow (**Actions → CI → Run workflow**) or push a commit.
3. Download the `cozy-mini-restaurant-play-bundle` artifact from the run. It contains `CozyMiniRestaurant.aab`.

Every CI run numbers the bundle with the run number (`version/code`), so each upload is newer than the last. Keep the keystore file and password somewhere safe (a password manager): every update must be signed with the same upload key. With Play App Signing (the default for new apps), Google holds the real app signing key, and a lost upload key can be reset through Play support.

To make a new key yourself instead:

```sh
keytool -genkeypair -keystore cozy-upload.keystore -storetype PKCS12 -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Cozy Mini Restaurant"
base64 -w0 cozy-upload.keystore    # the value for ANDROID_KEYSTORE_BASE64 (macOS: base64 -i)
```

## 2. Real ad ids (before the public release)

The game ships with Google's test ad ids, which show "Test Ad" banners and earn nothing. For internal testing that's fine. Before production:

1. **You:** in [AdMob](https://admob.google.com), add the app (Android), then create one **Interstitial** and one **Rewarded** ad unit.
2. Put the ids in `project.godot` under `[cozy_services]` (`admob/android_app_id`, `admob/android_interstitial_unit`, `admob/android_rewarded_unit`) and push. Debug builds keep using test ads.
3. In AdMob **Privacy & messaging**, create and publish a **GDPR** message and a **US states** message.
4. Once the app is live, link it to its Play listing in AdMob and add `app-ads.txt` to your developer website.

## 3. Play Console

1. **You:** create a [Google Play developer account](https://play.google.com/console/signup) (one-time fee) and **Create app**:
   - Name: Cozy Mini Restaurant, default language English, **Game**, **Free**.
   - The package name comes from the first upload: `com.cozyminirestaurant.game`. To use your own (for example `com.yourname.cozycafe`), change `package/unique_name` in both Android presets of `export_presets.cfg` **before** the first upload; it can never change afterwards.
2. **Testing → Internal testing → Create new release**: accept Play App Signing, upload the `.aab`, add yourself as a tester, and roll out. Open the opt-in link on your phone to install from Play.
3. **Monetize → Products → One-time products → Create product**:
   - Product ID: `remove_ads` (must match `store/remove_ads_product_id`)
   - Name: Remove ads; description: "No ads between days, +300 coins and the Golden chef outfit."
   - Price: for example 2.99 USD. Activate it.
   Products can only be created after a build with the billing library has been uploaded (step 2).
4. **Setup → License testing**: add your Google account so test purchases are free.
5. **Store presence → Main store listing**: copy `listing.md`, upload `icon_512.png`, `feature_graphic.png` and `screenshots/phone_*.png`.

## 4. App content (Policy → App content)

| Section | Answer |
| --- | --- |
| Privacy policy | The URL where `privacy-policy.html` is hosted (see below). Replace `SUPPORT_EMAIL` in it first. |
| Ads | **Yes, my app contains ads** |
| App access | All functionality is available without special access |
| Target audience | **13 and over** (13–15, 16–17, 18+). Choosing under 13 brings in the Families policy: then also set `admob/child_directed=true`. |
| Content rating | Fill in the IARC questionnaire: category **Game**; no violence, fear, sexuality, language, drugs or gambling; **Yes** to in-app purchases (digital goods); no user interaction or chat; no location sharing. Expect **Everyone / PEGI 3**. |
| News app | No |
| Government app | No |
| Financial features | None |
| Health | None |

### Data safety

| Question | Answer |
| --- | --- |
| Does your app collect or share user data? | **Yes** (through the Google Mobile Ads SDK) |
| Encrypted in transit | Yes |
| Can users request that data is deleted | No. There is no account; uninstalling removes the game's data from the phone. |
| **Device or other IDs** (advertising ID) | Collected and shared · purpose: **Advertising or marketing**, **Analytics**, **Fraud prevention** · not optional where consent is not required |
| **App activity → App interactions** | Collected · purpose: Advertising, Analytics |
| **App info and performance → Crash logs, Diagnostics** | Collected by the ads SDK · purpose: Analytics |
| **Location → Approximate location** (from IP) | Collected and shared · purpose: Advertising |
| Financial info → Purchase history | Not collected by the app (Google Play handles purchases) |

Google keeps an up-to-date list for its SDKs: [Google Mobile Ads SDK data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure).

## 5. Host the privacy policy

The repository is public, so GitHub Pages can host it for free:

1. **You:** **Settings → Pages → Source: GitHub Actions**, and add a repository variable `PAGES_ENABLED` = `true` (**Settings → Secrets and variables → Actions → Variables**).
2. The next CI run on the default branch publishes the web version of the game and the policy at
   `https://<your-username>.github.io/Cozy-mini-restaurant/privacy.html`.

Any other public page works too.

## 6. Go live

Internal testing → (optional) closed testing → **Production → Create new release** with the same `.aab`, then **Send for review**. New personal developer accounts must first run a closed test with at least 12 testers for 14 days before production access is granted.

## Before each update

- Push to the default branch; CI builds a new numbered `.aab`.
- Bump `version/name` in both Android presets for user-visible versions (for example `1.1.0`).
- Upload the bundle to a testing track, check it, then promote to production.

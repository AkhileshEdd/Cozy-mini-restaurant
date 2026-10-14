package com.cozyminirestaurant.services;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;
import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.RequestConfiguration;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Ads (Google Mobile Ads), consent (Google UMP) and the one-time "remove ads"
 * purchase (Google Play Billing) for Cozy Mini Restaurant.
 *
 * Every method called from Godot hops to the UI thread, where all SDK
 * callbacks also arrive, so the state below is only touched on that thread
 * (the volatile flags are read from Godot's thread).
 *
 * Ad kinds are the strings "interstitial" and "rewarded".
 */
public class CozyServicesPlugin extends GodotPlugin implements PurchasesUpdatedListener {
    private static final String TAG = "CozyServices";
    private static final String INTERSTITIAL = "interstitial";
    private static final String REWARDED = "rewarded";
    private static final long[] RETRY_DELAYS_MS = {15_000, 30_000, 60_000, 120_000, 300_000};

    private final Handler handler = new Handler(Looper.getMainLooper());

    // -- ads --
    private final AtomicBoolean adsStarted = new AtomicBoolean(false);
    private volatile boolean adsInitialized = false;
    private volatile boolean interstitialReady = false;
    private volatile boolean rewardedReady = false;
    private String interstitialUnit = "";
    private String rewardedUnit = "";
    private InterstitialAd interstitialAd;
    private RewardedAd rewardedAd;
    private boolean interstitialLoading = false;
    private boolean rewardedLoading = false;
    private int interstitialFailures = 0;
    private int rewardedFailures = 0;
    private boolean rewardEarned = false;
    private ConsentInformation consentInformation;

    // -- billing --
    private BillingClient billingClient;
    private String productId = "";
    private ProductDetails productDetails;
    private boolean billingConnecting = false;
    private final List<Runnable> afterConnect = new ArrayList<>();

    public CozyServicesPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "CozyServices";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("consent_finished", Boolean.class, Boolean.class));
        signals.add(new SignalInfo("ad_loaded", String.class));
        signals.add(new SignalInfo("ad_load_failed", String.class, String.class));
        signals.add(new SignalInfo("ad_shown", String.class));
        signals.add(new SignalInfo("ad_show_failed", String.class, String.class));
        signals.add(new SignalInfo("ad_closed", String.class, Boolean.class));
        signals.add(new SignalInfo("privacy_options_closed", String.class));
        signals.add(new SignalInfo("billing_ready", Boolean.class, String.class));
        signals.add(new SignalInfo("product_price", String.class, String.class));
        signals.add(new SignalInfo("purchase_succeeded", String.class, Boolean.class));
        signals.add(new SignalInfo("purchase_pending", String.class));
        signals.add(new SignalInfo("purchase_failed", String.class, String.class, Boolean.class));
        signals.add(new SignalInfo("restore_finished", Boolean.class, Integer.class));
        return signals;
    }

    // ---------------------------------------------------------------------------
    // Consent and ads
    // ---------------------------------------------------------------------------

    /**
     * Gathers consent (shows Google's consent form where the law requires it),
     * then starts the Mobile Ads SDK and preloads one ad of each kind.
     * Emits consent_finished(can_request_ads, privacy_options_required).
     */
    @UsedByGodot
    public void startAds(String interstitialAdUnit, String rewardedAdUnit, boolean childDirected) {
        runOnUiThread(() -> {
            Activity activity = getActivity();
            if (activity == null || !adsStarted.compareAndSet(false, true)) {
                return;
            }
            interstitialUnit = interstitialAdUnit;
            rewardedUnit = rewardedAdUnit;
            RequestConfiguration.Builder config = MobileAds.getRequestConfiguration().toBuilder()
                    .setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_G);
            if (childDirected) {
                config.setTagForChildDirectedTreatment(RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE);
            }
            MobileAds.setRequestConfiguration(config.build());

            consentInformation = UserMessagingPlatform.getConsentInformation(activity);
            ConsentRequestParameters params = new ConsentRequestParameters.Builder()
                    .setTagForUnderAgeOfConsent(childDirected)
                    .build();
            consentInformation.requestConsentInfoUpdate(activity, params,
                    () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity, formError -> {
                        if (formError != null) {
                            Log.w(TAG, "Consent form: " + formError.getMessage());
                        }
                        finishConsent();
                    }),
                    requestError -> {
                        Log.w(TAG, "Consent info update failed: " + requestError.getMessage());
                        finishConsent();
                    });
            // Consent from an earlier session lets ads start right away.
            if (consentInformation.canRequestAds()) {
                initializeAds();
            }
        });
    }

    private void finishConsent() {
        boolean canRequest = consentInformation != null && consentInformation.canRequestAds();
        if (canRequest) {
            initializeAds();
        }
        emitSignal("consent_finished", canRequest, isPrivacyOptionsRequiredNow());
    }

    private void initializeAds() {
        if (adsInitialized) {
            return;
        }
        adsInitialized = true;
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        // The SDK asks for initialization off the main thread.
        new Thread(() -> MobileAds.initialize(activity, status -> runOnUiThread(() -> {
            loadInterstitial();
            loadRewarded();
        }))).start();
    }

    private boolean isPrivacyOptionsRequiredNow() {
        return consentInformation != null
                && consentInformation.getPrivacyOptionsRequirementStatus()
                == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
    }

    @UsedByGodot
    public boolean isPrivacyOptionsRequired() {
        return isPrivacyOptionsRequiredNow();
    }

    /** Re-opens the consent form so players can change their choice. */
    @UsedByGodot
    public void showPrivacyOptions() {
        runOnUiThread(() -> {
            Activity activity = getActivity();
            if (activity == null) {
                emitSignal("privacy_options_closed", "no activity");
                return;
            }
            UserMessagingPlatform.showPrivacyOptionsForm(activity, formError -> {
                if (consentInformation != null && consentInformation.canRequestAds()) {
                    initializeAds();
                }
                emitSignal("privacy_options_closed", formError == null ? "" : formError.getMessage());
            });
        });
    }

    @UsedByGodot
    public boolean isAdReady(String kind) {
        return INTERSTITIAL.equals(kind) ? interstitialReady : REWARDED.equals(kind) && rewardedReady;
    }

    private void loadInterstitial() {
        Activity activity = getActivity();
        if (activity == null || interstitialAd != null || interstitialLoading || interstitialUnit.isEmpty()) {
            return;
        }
        interstitialLoading = true;
        InterstitialAd.load(activity, interstitialUnit, new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
            @Override
            public void onAdLoaded(@NonNull InterstitialAd ad) {
                interstitialLoading = false;
                interstitialFailures = 0;
                interstitialAd = ad;
                interstitialReady = true;
                emitSignal("ad_loaded", INTERSTITIAL);
            }

            @Override
            public void onAdFailedToLoad(@NonNull LoadAdError error) {
                interstitialLoading = false;
                emitSignal("ad_load_failed", INTERSTITIAL, error.getMessage());
                handler.postDelayed(CozyServicesPlugin.this::loadInterstitial, retryDelay(interstitialFailures++));
            }
        });
    }

    private void loadRewarded() {
        Activity activity = getActivity();
        if (activity == null || rewardedAd != null || rewardedLoading || rewardedUnit.isEmpty()) {
            return;
        }
        rewardedLoading = true;
        RewardedAd.load(activity, rewardedUnit, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override
            public void onAdLoaded(@NonNull RewardedAd ad) {
                rewardedLoading = false;
                rewardedFailures = 0;
                rewardedAd = ad;
                rewardedReady = true;
                emitSignal("ad_loaded", REWARDED);
            }

            @Override
            public void onAdFailedToLoad(@NonNull LoadAdError error) {
                rewardedLoading = false;
                emitSignal("ad_load_failed", REWARDED, error.getMessage());
                handler.postDelayed(CozyServicesPlugin.this::loadRewarded, retryDelay(rewardedFailures++));
            }
        });
    }

    private static long retryDelay(int failures) {
        return RETRY_DELAYS_MS[Math.min(failures, RETRY_DELAYS_MS.length - 1)];
    }

    /** Shows the loaded ad. Ends with ad_closed(kind, rewarded) or ad_show_failed(kind, message). */
    @UsedByGodot
    public void showAd(String kind) {
        runOnUiThread(() -> {
            Activity activity = getActivity();
            if (activity == null) {
                emitSignal("ad_show_failed", kind, "no activity");
                return;
            }
            if (INTERSTITIAL.equals(kind) && interstitialAd != null) {
                InterstitialAd ad = interstitialAd;
                interstitialAd = null;
                interstitialReady = false;
                ad.setFullScreenContentCallback(new ShowCallback(INTERSTITIAL));
                ad.show(activity);
            } else if (REWARDED.equals(kind) && rewardedAd != null) {
                RewardedAd ad = rewardedAd;
                rewardedAd = null;
                rewardedReady = false;
                rewardEarned = false;
                ad.setFullScreenContentCallback(new ShowCallback(REWARDED));
                ad.show(activity, rewardItem -> rewardEarned = true);
            } else {
                emitSignal("ad_show_failed", kind, "not loaded");
                reload(kind);
            }
        });
    }

    private void reload(String kind) {
        if (INTERSTITIAL.equals(kind)) {
            loadInterstitial();
        } else {
            loadRewarded();
        }
    }

    private class ShowCallback extends FullScreenContentCallback {
        private final String kind;

        ShowCallback(String kind) {
            this.kind = kind;
        }

        @Override
        public void onAdShowedFullScreenContent() {
            emitSignal("ad_shown", kind);
        }

        @Override
        public void onAdDismissedFullScreenContent() {
            emitSignal("ad_closed", kind, REWARDED.equals(kind) && rewardEarned);
            reload(kind);
        }

        @Override
        public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
            emitSignal("ad_show_failed", kind, error.getMessage());
            reload(kind);
        }
    }

    // ---------------------------------------------------------------------------
    // Billing: one non-consumable product
    // ---------------------------------------------------------------------------

    /**
     * Connects to Google Play, looks up the product's price and restores it if
     * it was already bought. Emits billing_ready, product_price and, for an
     * owned product, purchase_succeeded(id, true).
     */
    @UsedByGodot
    public void startBilling(String product) {
        runOnUiThread(() -> {
            productId = product;
            whenConnected(() -> {
                queryProduct();
                queryOwned(false);
            });
        });
    }

    @UsedByGodot
    public void purchase(String product) {
        runOnUiThread(() -> whenConnected(() -> {
            Activity activity = getActivity();
            if (activity == null) {
                emitSignal("purchase_failed", product, "no activity", false);
                return;
            }
            if (productDetails == null || !productDetails.getProductId().equals(product)) {
                queryProduct();
                emitSignal("purchase_failed", product, "The store isn't ready yet. Try again in a moment.", false);
                return;
            }
            BillingFlowParams.ProductDetailsParams item = BillingFlowParams.ProductDetailsParams.newBuilder()
                    .setProductDetails(productDetails)
                    .build();
            BillingFlowParams flow = BillingFlowParams.newBuilder()
                    .setProductDetailsParamsList(Collections.singletonList(item))
                    .build();
            BillingResult result = billingClient.launchBillingFlow(activity, flow);
            if (result.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                queryOwned(true);
            } else if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                emitSignal("purchase_failed", product, describe(result), false);
            }
        }));
    }

    @UsedByGodot
    public void restorePurchases() {
        runOnUiThread(() -> whenConnected(() -> queryOwned(true)));
    }

    private void whenConnected(Runnable action) {
        if (billingClient == null) {
            billingClient = BillingClient.newBuilder(getActivity() != null ? getActivity() : getContext())
                    .setListener(this)
                    .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                    .build();
        }
        if (billingClient.isReady()) {
            action.run();
            return;
        }
        afterConnect.add(action);
        if (billingConnecting) {
            return;
        }
        billingConnecting = true;
        billingClient.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(@NonNull BillingResult result) {
                runOnUiThread(() -> {
                    billingConnecting = false;
                    boolean ok = result.getResponseCode() == BillingClient.BillingResponseCode.OK;
                    emitSignal("billing_ready", ok, ok ? "" : describe(result));
                    List<Runnable> pending = new ArrayList<>(afterConnect);
                    afterConnect.clear();
                    if (ok) {
                        for (Runnable next : pending) {
                            next.run();
                        }
                    }
                });
            }

            @Override
            public void onBillingServiceDisconnected() {
                // The next call reconnects.
                runOnUiThread(() -> billingConnecting = false);
            }
        });
    }

    private void queryProduct() {
        if (productId.isEmpty()) {
            return;
        }
        QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
                .setProductList(Collections.singletonList(QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()))
                .build();
        billingClient.queryProductDetailsAsync(params, (result, details) -> runOnUiThread(() -> {
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                Log.w(TAG, "Product query failed: " + describe(result));
                return;
            }
            for (ProductDetails pd : details.getProductDetailsList()) {
                if (pd.getProductId().equals(productId)) {
                    productDetails = pd;
                    ProductDetails.OneTimePurchaseOfferDetails offer = pd.getOneTimePurchaseOfferDetails();
                    emitSignal("product_price", productId, offer != null ? offer.getFormattedPrice() : "");
                }
            }
        }));
    }

    private void queryOwned(boolean userAsked) {
        QueryPurchasesParams params = QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build();
        billingClient.queryPurchasesAsync(params, (result, purchases) -> runOnUiThread(() -> {
            boolean ok = result.getResponseCode() == BillingClient.BillingResponseCode.OK;
            int owned = 0;
            if (ok) {
                for (Purchase p : purchases) {
                    if (handlePurchase(p, true)) {
                        owned++;
                    }
                }
            }
            if (userAsked) {
                emitSignal("restore_finished", ok, owned);
            }
        }));
    }

    @Override
    public void onPurchasesUpdated(@NonNull BillingResult result, @Nullable List<Purchase> purchases) {
        runOnUiThread(() -> {
            int code = result.getResponseCode();
            if (code == BillingClient.BillingResponseCode.OK && purchases != null) {
                for (Purchase p : purchases) {
                    handlePurchase(p, false);
                }
            } else if (code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                queryOwned(false);
            } else if (code == BillingClient.BillingResponseCode.USER_CANCELED) {
                emitSignal("purchase_failed", productId, "Purchase canceled.", true);
            } else {
                emitSignal("purchase_failed", productId, describe(result), false);
            }
        });
    }

    /** Grants (and acknowledges) a purchase. Returns true when it counts as owned. */
    private boolean handlePurchase(Purchase purchase, boolean restored) {
        if (purchase.getPurchaseState() == Purchase.PurchaseState.PENDING) {
            for (String id : purchase.getProducts()) {
                emitSignal("purchase_pending", id);
            }
            return false;
        }
        if (purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED) {
            return false;
        }
        // Unacknowledged purchases are refunded by Google Play after three days.
        if (!purchase.isAcknowledged()) {
            AcknowledgePurchaseParams ack = AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.getPurchaseToken())
                    .build();
            billingClient.acknowledgePurchase(ack, ackResult -> {
                if (ackResult.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                    Log.w(TAG, "Acknowledge failed: " + describe(ackResult));
                }
            });
        }
        for (String id : purchase.getProducts()) {
            emitSignal("purchase_succeeded", id, restored);
        }
        return true;
    }

    private static String describe(BillingResult result) {
        String message = result.getDebugMessage();
        switch (result.getResponseCode()) {
            case BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE:
            case BillingClient.BillingResponseCode.SERVICE_DISCONNECTED:
            case BillingClient.BillingResponseCode.NETWORK_ERROR:
                return "Google Play can't be reached. Check your connection.";
            case BillingClient.BillingResponseCode.BILLING_UNAVAILABLE:
                return "Purchases aren't available on this device.";
            case BillingClient.BillingResponseCode.ITEM_UNAVAILABLE:
                return "This item isn't available right now.";
            default:
                return message == null || message.isEmpty()
                        ? "Something went wrong (code " + result.getResponseCode() + ")."
                        : message;
        }
    }
}

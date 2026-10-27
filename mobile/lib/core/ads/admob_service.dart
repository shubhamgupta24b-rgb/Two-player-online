import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob for the Android app: an interstitial between matches and an opt-in rewarded
/// interstitial. Every entry point is safe to call when ads are off, still loading, or
/// failed: the game carries on and nothing waits for an ad that isn't ready.
///
/// Debug and profile builds, and release builds without --dart-define=ADMOB_LIVE_ADS=true,
/// use Google's test ad units. The Gradle build picks the matching AdMob app ID
/// (android/app/build.gradle.kts), so production units never pair with the test app ID.
class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  static const bool _liveAds = kReleaseMode && bool.fromEnvironment('ADMOB_LIVE_ADS');

  static const String productionInterstitial = 'ca-app-pub-2273708482671832/3168825409';
  static const String productionRewardedInterstitial = 'ca-app-pub-2273708482671832/4842753743';

  // Google's official Android test ad units.
  static const String testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedInterstitial = 'ca-app-pub-3940256099942544/5354046379';

  /// At most one interstitial in this window, and never on the first result of a session.
  static const Duration interstitialGap = Duration(minutes: 3);
  static const int _transitionsBeforeFirstInterstitial = 2;

  /// Google discards loaded full-screen ads after an hour; reload before that.
  static const Duration _adMaxAge = Duration(minutes: 55);

  /// If the SDK never reports the ad closed, carry on anyway after this long.
  static const Duration _showFallback = Duration(seconds: 90);

  static const Duration _consentUpdateTimeout = Duration(seconds: 12);
  static const Duration _sdkInitTimeout = Duration(seconds: 10);

  static String get interstitialUnit => _liveAds ? productionInterstitial : testInterstitial;
  static String get rewardedInterstitialUnit => _liveAds ? productionRewardedInterstitial : testRewardedInterstitial;

  @visibleForTesting
  static bool get usesTestAds => !_liveAds;

  /// The plugin only runs on Android and iOS, and this project ships Android only
  /// (an iOS build would also need GADApplicationIdentifier in Info.plist).
  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void>? _starting;
  bool _ready = false; // consent allows ads and the SDK has started
  bool _disposed = false;

  InterstitialAd? _interstitial;
  DateTime? _interstitialLoadedAt;
  bool _interstitialLoading = false;
  DateTime? _lastInterstitialShown;
  int _transitions = 0;
  VoidCallback? _afterInterstitial;
  Timer? _interstitialFallback;

  RewardedInterstitialAd? _rewarded;
  DateTime? _rewardedLoadedAt;
  bool _rewardedLoading = false;
  bool _rewardedShowing = false;

  /// Starts consent and the SDK in the background. Safe to call more than once; never
  /// throws. Call it after runApp without awaiting so start-up never waits on ads.
  Future<void> initialize() => _starting ??= _start();

  Future<void> _start() async {
    if (!_supported) return;
    try {
      if (!await _gatherConsent()) {
        debugPrint('AdMob: consent does not allow ad requests yet; continuing without ads.');
        return;
      }
      // Ad loads made before the SDK reports ready are queued by the SDK, so a slow start
      // only delays the first ad; it doesn't need to block anything.
      await MobileAds.instance.initialize().timeout(_sdkInitTimeout, onTimeout: () {
        debugPrint('AdMob: SDK start is slow; loading ads anyway.');
        return InitializationStatus(const {});
      });
      if (_disposed) return;
      _ready = true;
      _loadInterstitial();
    } catch (error, stack) {
      debugPrint('AdMob: start failed; continuing without ads: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Google's User Messaging Platform: shows the GDPR/US-states message configured in
  /// AdMob (Privacy & messaging) when the user needs one. Returns whether ads may be
  /// requested. Offline or slow networks fall back to the consent stored last time.
  Future<bool> _gatherConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        // The form, if any, waits for the user: no timeout on this part.
        ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) debugPrint('AdMob: consent form error ${formError.errorCode}: ${formError.message}');
          if (!updated.isCompleted) updated.complete();
        }).catchError((Object error) {
          debugPrint('AdMob: consent form failed: $error');
          if (!updated.isCompleted) updated.complete();
        });
      },
      (error) {
        debugPrint('AdMob: consent info update failed ${error.errorCode}: ${error.message}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    // Only the network request is bounded: once a form is showing, the listener above
    // completes when the user closes it.
    await updated.future.timeout(_consentUpdateTimeout, onTimeout: () {});
    return ConsentInformation.instance.canRequestAds();
  }

  /// Whether a privacy options entry point must be offered (GDPR regions).
  Future<bool> privacyOptionsRequired() async {
    if (!_supported) return false;
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Lets the user review or change their ad consent choices.
  Future<void> showPrivacyOptions() async {
    if (!_supported) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) debugPrint('AdMob: privacy options error ${formError.errorCode}: ${formError.message}');
      });
    } catch (error) {
      debugPrint('AdMob: privacy options failed: $error');
    }
  }

  static bool _fresh(DateTime? loadedAt) => loadedAt != null && DateTime.now().difference(loadedAt) < _adMaxAge;

  void _loadInterstitial() {
    if (!_ready || _disposed || _interstitialLoading || _interstitial != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
            onAdDismissedFullScreenContent: (ad) => _interstitialClosed(ad),
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('AdMob: interstitial failed to show: $error');
              _interstitialClosed(ad);
            },
          );
          _interstitial = ad;
          _interstitialLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          // No fill or a network error: try again at the next transition, not in a loop.
          _interstitialLoading = false;
          debugPrint('AdMob: interstitial failed to load: $error');
        },
      ),
    );
  }

  void _interstitialClosed(InterstitialAd ad) {
    ad.dispose();
    _runAfterInterstitial();
    _loadInterstitial();
  }

  void _runAfterInterstitial() {
    _interstitialFallback?.cancel();
    _interstitialFallback = null;
    final next = _afterInterstitial;
    _afterInterstitial = null;
    next?.call();
  }

  /// For a natural break the player chose (leaving a results screen): shows an
  /// interstitial if one is ready and allowed, then runs [next] once it closes.
  /// Without an ad, [next] runs straight away.
  void showInterstitialThen(VoidCallback next) {
    // An ad is already opening for an earlier tap; that tap's action runs when it closes.
    if (_afterInterstitial != null) return;
    _transitions++;
    final ad = _interstitial;
    final last = _lastInterstitialShown;
    final allowed = _ready &&
        _transitions >= _transitionsBeforeFirstInterstitial &&
        (last == null || DateTime.now().difference(last) >= interstitialGap);
    if (ad != null && !_fresh(_interstitialLoadedAt)) {
      ad.dispose();
      _interstitial = null;
    }
    if (!allowed || _interstitial == null) {
      _loadInterstitial();
      next();
      return;
    }
    _interstitial = null;
    _lastInterstitialShown = DateTime.now();
    _afterInterstitial = next;
    _interstitialFallback = Timer(_showFallback, _runAfterInterstitial);
    ad!.show();
  }

  /// Loads a rewarded interstitial ahead of an opt-in offer. Call when the offer screen
  /// appears; [rewardedInterstitialReady] says when it can be shown.
  void loadRewardedInterstitial() {
    if (!_ready || _disposed || _rewardedLoading || _rewardedShowing) return;
    if (_rewarded != null) {
      if (_fresh(_rewardedLoadedAt)) return;
      _rewarded!.dispose();
      _rewarded = null;
    }
    _rewardedLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialUnit,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _rewarded = ad;
          _rewardedLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          debugPrint('AdMob: rewarded interstitial failed to load: $error');
        },
      ),
    );
  }

  bool get rewardedInterstitialReady => _ready && !_rewardedShowing && _rewarded != null && _fresh(_rewardedLoadedAt);

  /// Shows the rewarded interstitial. Google policy requires an intro screen first that
  /// names the reward and lets the player skip it. [onRewardEarned] runs only from the
  /// SDK's earned-reward callback, never because the ad was shown or closed. [onClosed]
  /// runs once when the ad is gone (closed or failed to show). Returns false, without
  /// calling either callback, when no ad is ready.
  bool showRewardedInterstitial({
    required void Function(int amount, String type) onRewardEarned,
    VoidCallback? onClosed,
  }) {
    if (!rewardedInterstitialReady) {
      loadRewardedInterstitial();
      return false;
    }
    final ad = _rewarded!;
    _rewarded = null;
    _rewardedShowing = true;
    var closed = false;
    void close(RewardedInterstitialAd ad) {
      ad.dispose();
      _rewardedShowing = false;
      if (closed) return;
      closed = true;
      onClosed?.call();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedInterstitialAd>(
      onAdDismissedFullScreenContent: close,
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: rewarded interstitial failed to show: $error');
        close(ad);
      },
    );
    ad.show(onUserEarnedReward: (_, reward) => onRewardEarned(reward.amount.toInt(), reward.type));
    return true;
  }

  /// Releases loaded ads (e.g. in tests or if the app turns ads off).
  void dispose() {
    _disposed = true;
    _ready = false;
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
    _runAfterInterstitial();
  }
}

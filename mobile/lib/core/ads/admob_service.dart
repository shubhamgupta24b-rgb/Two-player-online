import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob integration for the Clay Flutter app.
///
/// Development builds use Google's official test ad units by default. To opt into
/// the configured production units for a release, build with
/// --dart-define=ADMOB_LIVE_ADS=true after verifying the app in test mode.
class AdMobService {
  AdMobService._();
  static final AdMobService instance = AdMobService._();

  static const bool _liveAds =
      kReleaseMode && bool.fromEnvironment('ADMOB_LIVE_ADS', defaultValue: false);

  static const String _productionInterstitial =
      'ca-app-pub-2273708482671832/3168825409';
  static const String _productionRewardedInterstitial =
      'ca-app-pub-2273708482671832/4842753743';

  // Google's official Android test ad units.
  static const String _testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedInterstitial =
      'ca-app-pub-3940256099942544/5354046379';

  InterstitialAd? _interstitial;
  RewardedInterstitialAd? _rewardedInterstitial;
  bool _initialized = false;
  bool _interstitialLoading = false;
  bool _rewardedLoading = false;
  DateTime? _lastInterstitialShown;

  String get _interstitialUnit =>
      _liveAds ? _productionInterstitial : _testInterstitial;
  String get _rewardedUnit =>
      _liveAds ? _productionRewardedInterstitial : _testRewardedInterstitial;

  /// Call without awaiting from app startup so ads never block navigation.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 8),
      );
      _initialized = true;
      _preloadInterstitial();
      _preloadRewardedInterstitial();
    } catch (error, stack) {
      debugPrint('AdMob initialization failed; continuing without ads: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  void _preloadInterstitial() {
    if (!_initialized || _interstitialLoading || _interstitial != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (identical(_interstitial, ad)) _interstitial = null;
              _preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial failed to show: $error');
              ad.dispose();
              if (identical(_interstitial, ad)) _interstitial = null;
              _preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Called only on a natural game-results transition. If no ad is ready,
  /// the results screen remains usable and no blocking wait occurs.
  void showInterstitialIfReady() {
    final now = DateTime.now();
    final last = _lastInterstitialShown;
    if (!_initialized ||
        _interstitial == null ||
        (last != null && now.difference(last) < const Duration(minutes: 3))) {
      _preloadInterstitial();
      return;
    }
    final ad = _interstitial!;
    _interstitial = null;
    _lastInterstitialShown = now;
    ad.show();
  }

  void _preloadRewardedInterstitial() {
    if (!_initialized || _rewardedLoading || _rewardedInterstitial != null) return;
    _rewardedLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: _rewardedUnit,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback:
          RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewardedInterstitial = ad;
          ad.fullScreenContentCallback =
              FullScreenContentCallback<RewardedInterstitialAd>(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (identical(_rewardedInterstitial, ad)) {
                _rewardedInterstitial = null;
              }
              _preloadRewardedInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Rewarded interstitial failed to show: $error');
              ad.dispose();
              if (identical(_rewardedInterstitial, ad)) {
                _rewardedInterstitial = null;
              }
              _preloadRewardedInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          debugPrint('Rewarded interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Optional rewards must be explained before this is called. The callback
  /// fires only from Google's earned-reward callback; never grant a reward just
  /// because an ad was displayed or dismissed.
  bool showRewardedInterstitial({
    required void Function(int amount, String type) onRewardEarned,
  }) {
    if (!_initialized || _rewardedInterstitial == null) {
      _preloadRewardedInterstitial();
      return false;
    }
    final ad = _rewardedInterstitial!;
    _rewardedInterstitial = null;
    ad.show(
      onUserEarnedReward: (ad, reward) {
        onRewardEarned(reward.amount.toInt(), reward.type);
      },
    );
    return true;
  }

  @visibleForTesting
  static bool get usesTestAds => !_liveAds;
}

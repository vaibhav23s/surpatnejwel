import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Har exception ko customer ke liye saaf message me badalta hai.
class AppErrors {
  AppErrors._();

  static const String noInternet =
      'No internet connection. Please check your network and try again.';
  static const String slow =
      'This is taking longer than usual. Please check your internet and try again.';
  static const String generic = 'Something went wrong. Please try again.';

  /// Sirf debug me console me asli error dikhata hai (developer ke liye).
  static void log(Object e, [StackTrace? s]) {
    if (kDebugMode) debugPrint('SJ_ERROR: $e${s != null ? '\n$s' : ''}');
  }

  static bool isNetwork(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    if (e is FirebaseException) {
      return const {
        'unavailable',
        'network-request-failed',
        'deadline-exceeded',
        'retry-limit-exceeded',
      }.contains(e.code);
    }
    if (e is PlatformException) return e.code == 'network_error';
    return false;
  }

  static String message(Object e) {
    log(e);
    if (e is TimeoutException) return slow;
    if (e is SocketException) return noInternet;
    if (e is FirebaseAuthException) return _auth(e.code);
    if (e is FirebaseException) return _firebase(e.code);
    if (e is PlatformException) return _platform(e.code);
    return generic;
  }

  static String _firebase(String code) {
    switch (code) {
      case 'unavailable':
      case 'network-request-failed':
        return noInternet;
      case 'deadline-exceeded':
      case 'retry-limit-exceeded':
        return slow;
      case 'permission-denied':
      case 'unauthorized':
        return 'You do not have permission to do this. If you think this is a mistake, please contact the shop.';
      case 'unauthenticated':
        return 'Your session has expired. Please log in again.';
      case 'not-found':
      case 'object-not-found':
        return 'We could not find that record.';
      case 'already-exists':
        return 'This record already exists.';
      case 'resource-exhausted':
      case 'quota-exceeded':
        return 'The service is busy right now. Please try again in a few minutes.';
      case 'failed-precondition':
        return 'This feature is not ready yet. Please try again later or contact the shop.';
      case 'cancelled':
      case 'canceled':
      case 'aborted':
        return 'The request was interrupted. Please try again.';
      default:
        return generic;
    }
  }

  static String _auth(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact the shop.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in instead.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return noInternet;
      case 'operation-not-allowed':
        return 'This sign-in method is not available right now.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in method.';
      case 'requires-recent-login':
        return 'For your security, please log in again and retry.';
      default:
        return 'Could not sign you in. Please try again.';
    }
  }

  static String _platform(String code) {
    switch (code) {
      case 'network_error':
        return noInternet;
      case 'sign_in_canceled':
        return 'Sign-in was cancelled.';
      case 'sign_in_failed':
        return 'Google sign-in failed. Please try again.';
      case 'photo_access_denied':
      case 'camera_access_denied':
        return 'Permission denied. Please allow camera and photo access in your phone settings.';
      default:
        return generic;
    }
  }

  /// Razorpay payment fail hone par.
  static String razorpay(PaymentFailureResponse r) {
    final c = r.code;
    if (c == Razorpay.PAYMENT_CANCELLED) {
      return 'You cancelled the payment.';
    }
    if (c == Razorpay.NETWORK_ERROR) {
      return 'There was a network problem during the payment. If any amount was deducted, '
          'it is usually returned by your bank within a few working days. Please try again.';
    }
    if (c == Razorpay.INVALID_OPTIONS) {
      return 'Payment could not be started. Please contact the shop.';
    }
    return 'Payment failed. Please try again. If any amount was deducted, please contact the shop.';
  }
}

class Net {
  Net._();

  /// Asli internet hai ya nahi (sirf network on hona kaafi nahi hota).
  static Future<bool> isOnline() async {
    try {
      final r = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Firebase me net band ho to write kabhi khatam nahi hota, app latak jata hai.
  /// Isse time limit lag jati hai.
  static Future<T> withTimeout<T>(
      Future<T> future, [
        Duration limit = const Duration(seconds: 20),
      ]) {
    return future.timeout(limit);
  }
}
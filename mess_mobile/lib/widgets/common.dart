import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found for this email. Try signing up first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in.';
      case 'weak-password':
        return 'Use at least 8 characters with upper, lower, number, and symbol.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase. Enable it in Authentication → Sign-in method.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Try signing in with email/password.';
      case 'popup-closed-by-user':
        return 'Sign-in popup was closed. Please try again.';
      default:
        return error.message ?? 'Sign-in failed (${error.code}).';
    }
  }
  if (error is PlatformException) {
    final code = error.code;
    if (code == 'sign_in_failed' || code == '10') {
      return 'Google sign-in is not configured for this Android build. '
          'Install the latest app release from GitHub and try again.';
    }
    if (code == 'network_error') {
      return 'Network error. Check your connection and try again.';
    }
    return error.message ?? 'Sign-in failed ($code).';
  }
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Permission denied by Firestore. Sign out and back in, or ask your mess admin to refresh the invite code.';
    }
    if (error.code == 'failed-precondition') {
      return 'Database index missing. Run: firebase deploy --only firestore';
    }
    return error.message ?? 'Firebase error (${error.code}).';
  }
  if (error is StateError) return error.message;
  return error.toString();
}

void showSnackError(BuildContext context, Object error) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(authErrorMessage(error))),
  );
}

InputDecoration borderedField({
  required String label,
  String? hint,
  Widget? prefix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 14, right: 6),
      child: SizedBox(height: 24, width: 24, child: prefix),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 52, maxHeight: 48),
    alignLabelWithHint: false,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.onSurfaceVariant,
    ),
  );
}

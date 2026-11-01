import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/app_errors.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5),
    );
  }
}

/// Error screen. [dark] = true admin ki kaali screens ke liye.
class ErrorView extends StatelessWidget {
  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final bool dark;

  const ErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final net = error != null && AppErrors.isNetwork(error!);
    final text = message ??
        (error != null ? AppErrors.message(error!) : AppErrors.generic);
    final fg = dark ? AppColors.cream : AppColors.charcoal;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              net ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 48,
              color: AppColors.gold,
            ),
            const SizedBox(height: 14),
            Text(
              net ? 'No connection' : 'Something went wrong',
              style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: fg.withOpacity(0.7), fontSize: 13, height: 1.45),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gold),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: AppColors.gold, size: 18),
                label: const Text('Retry', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// StreamBuilder ka safe version: loading, error aur Retry apne aap sambhalta hai.
///
///   SafeStream<List<Foo>>(
///     create: () => service.watchFoos(),
///     builder: (context, list) => ...,
///   )
class SafeStream<T> extends StatefulWidget {
  final Stream<T> Function() create;
  final Widget Function(BuildContext context, T data) builder;
  final bool dark;

  const SafeStream({
    super.key,
    required this.create,
    required this.builder,
    this.dark = false,
  });

  @override
  State<SafeStream<T>> createState() => _SafeStreamState<T>();
}

class _SafeStreamState<T> extends State<SafeStream<T>> {
  late Stream<T> _stream = widget.create();

  void _retry() => setState(() => _stream = widget.create());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorView(error: snap.error, onRetry: _retry, dark: widget.dark);
        }
        if (!snap.hasData) return const LoadingView();
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

/// Payment ho gayi par hamare record me save nahi ho payi.
Future<void> showPaidNotSavedDialog(
    BuildContext context, {
      required String paymentId,
      int? amount,
      required bool mayAutoUpdate,
    }) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Payment received',
        style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your payment${amount != null ? ' of Rs. $amount' : ''} was successful, but we could '
                  'not update your account right now.'
                  '${mayAutoUpdate ? ' Please keep your internet on, it may update automatically.' : ''}',
              style: const TextStyle(color: Colors.black87, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 10),
            const Text(
              'If it does not show in your account within a day, please call the shop with this Payment ID. '
                  'We will update it for you.',
              style: TextStyle(color: Colors.black87, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            const Text('Payment ID', style: TextStyle(color: Colors.black54, fontSize: 11.5)),
            const SizedBox(height: 3),
            SelectableText(
              paymentId.isEmpty ? 'Not available' : paymentId,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK', style: TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

/// Release build me kisi screen ke crash par laal screen ki jagah ye dikhta hai.
class FriendlyErrorWidget extends StatelessWidget {
  const FriendlyErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.cream,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 46, color: AppColors.gold),
                SizedBox(height: 12),
                Text(
                  'Something went wrong on this screen.\nPlease go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.charcoal, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
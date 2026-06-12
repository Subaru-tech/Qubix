import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      setState(() {
        _errorDetails = details;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined, size: 64, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please restart the app. If this persists, check your server connection.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorDetails = null;
                    });
                  },
                  child: const Text('Restart App'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

import 'package:flutter/material.dart';

class HandlingFutureBuilder<T> extends StatelessWidget {
  final Widget Function(T) builder;
  final T? initialData;
  final Future<T> future;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const HandlingFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.initialData,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorWidget ??
              const Center(
                child: Text(
                  'An error occurred',
                  style: TextStyle(color: Colors.red),
                ),
              );
        }

        if (!snapshot.hasData) {
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        }

        return builder(snapshot.data as T);
      },
    );
  }
}

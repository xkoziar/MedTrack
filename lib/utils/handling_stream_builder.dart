import 'package:flutter/material.dart';

class HandlingStreamBuilder<T> extends StatelessWidget {
  final Widget Function(T) builder;
  final T? initialData;
  final Stream<T> stream;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const HandlingStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.initialData,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
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

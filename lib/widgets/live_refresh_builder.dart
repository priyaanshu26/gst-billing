import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Loads live data with a full-body spinner, then builds the screen layout.
/// After the first successful fetch, [listen] keeps the layout in sync.
class LiveRefreshBuilder<T> extends StatefulWidget {
  const LiveRefreshBuilder({
    super.key,
    required this.load,
    required this.builder,
    this.listen,
    this.errorTitle = 'Could not load data.',
  });

  final Future<T> Function() load;
  final Stream<T> Function()? listen;
  final Widget Function(BuildContext context, T data) builder;
  final String errorTitle;

  @override
  State<LiveRefreshBuilder<T>> createState() => _LiveRefreshBuilderState<T>();
}

class _LiveRefreshBuilderState<T> extends State<LiveRefreshBuilder<T>> {
  var _loading = true;
  T? _data;
  Object? _error;
  StreamSubscription<T>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
      _subscribe();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _subscribe() {
    final listen = widget.listen;
    if (listen == null) return;
    var skipFirstSnapshot = true;
    _subscription = listen().listen((value) {
      if (!mounted) return;
      // The first snapshot is often a stale cache after a server fetch.
      if (skipFirstSnapshot) {
        skipFirstSnapshot = false;
        return;
      }
      setState(() => _data = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$_errorTitle\n${_error ?? ''}'.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
        ),
      );
    }

    return widget.builder(context, data);
  }
}

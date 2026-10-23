import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/providers.dart';

/// The field starts empty, the entered value is obscured by default, and the
/// token is only written through [TokenSource.write]. Nothing is logged and
/// the current token is never read back into the field.
Future<void> showTokenDialog(BuildContext context, WidgetRef ref) {
  final TokenSource tokenSource = ref.read(tokenSourceProvider);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(dialogContext).pop(),
      },
      child: Focus(
        autofocus: true,
        child: _TokenDialog(tokenSource: tokenSource),
      ),
    ),
  );
}

class _TokenDialog extends StatefulWidget {
  const _TokenDialog({required this.tokenSource});

  final TokenSource tokenSource;

  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final String token = _controller.text.trim();
    if (token.isEmpty) {
      setState(() => _errorText = 'Token tidak boleh kosong.');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );

    try {
      await widget.tokenSource.write(token);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = 'Token gagal disimpan. Coba lagi.';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    _controller.clear();
    Navigator.of(context).pop();
    messenger?.showSnackBar(const SnackBar(content: Text('Token disimpan')));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      scrollable: true,
      icon: Icon(Icons.key_outlined, color: theme.colorScheme.primary),
      title: const Text('Perbarui token akses'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Tempel token API SynCare untuk melanjutkan. Token tidak akan '
              'ditampilkan di layar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) {
                if (!_saving) {
                  _save();
                }
              },
              decoration: InputDecoration(
                labelText: 'Token API',
                hintText: 'Tempel token di sini',
                errorText: _errorText,
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Tampilkan token' : 'Sembunyikan token',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Token hanya dikirim sebagai header Authorization.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

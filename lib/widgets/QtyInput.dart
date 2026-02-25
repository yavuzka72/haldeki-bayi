import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QtyInput extends StatefulWidget {
  final double value;
  final double step;
  final double min;
  final ValueChanged<double> onChanged;
  const QtyInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
  });

  @override
  State<QtyInput> createState() => _QtyInputState();
}

class _QtyInputState extends State<QtyInput> {
  late final _c = TextEditingController(text: _fmt(widget.value));
  final _focus = FocusNode();

  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  double _parse(String s) => double.tryParse(s.replaceAll(',', '.')) ?? widget.min;

  void _emit(double v) {
    final val = v < widget.min ? widget.min : v;
    if (_parse(_c.text) != val) {
      _c.text = _fmt(val);
      _c.selection = TextSelection.fromPosition(TextPosition(offset: _c.text.length));
    }
    widget.onChanged(val);
  }

  @override
  void didUpdateWidget(covariant QtyInput oldWidget) {
    // dışarıdan gelen value değiştiyse kutuyu senkronla
    final ext = _fmt(widget.value);
    if (_c.text != ext) {
      _c.text = ext;
      _c.selection = TextSelection.fromPosition(TextPosition(offset: _c.text.length));
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _emit(_parse(_c.text)); // odak kaybında commit
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _emit(_parse(_c.text) - widget.step),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 64,
          child: TextField(
            controller: _c,
            focusNode: _focus,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'))],
            onChanged: (s) => widget.onChanged(_parse(s)), // <-- anında yay
            onEditingComplete: () => _emit(_parse(_c.text)),
            onTapOutside: (_) => _emit(_parse(_c.text)),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _emit(_parse(_c.text) + widget.step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

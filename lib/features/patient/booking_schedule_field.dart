import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingScheduleField extends StatefulWidget {
  const BookingScheduleField({
    super.key,
    required this.label,
    required this.controller,
    required this.isDate,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool isDate, enabled;
  final ValueChanged<String> onChanged;

  @override
  State<BookingScheduleField> createState() => _BookingScheduleFieldState();
}

class _BookingScheduleFieldState extends State<BookingScheduleField> {
  late String _displayValue;

  @override
  void initState() {
    super.initState();
    _readValue();
    widget.controller.addListener(_valueChanged);
  }

  @override
  void didUpdateWidget(BookingScheduleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_valueChanged);
      widget.controller.addListener(_valueChanged);
    }
    _readValue();
  }

  void _readValue() {
    final value = widget.controller.text;
    final date = widget.isDate ? DateTime.tryParse(value) : null;
    _displayValue = value.isEmpty
        ? (widget.isDate ? 'Pilih tanggal' : 'Pilih jam')
        : date != null
        ? DateFormat('dd/MM/yyyy').format(date)
        : value;
  }

  void _valueChanged() => setState(_readValue);

  @override
  void dispose() {
    widget.controller.removeListener(_valueChanged);
    super.dispose();
  }

  Future<void> _choose() async {
    final wib = DateTime.now().toUtc().add(const Duration(hours: 7));
    String? value;
    if (widget.isDate) {
      final today = DateTime(wib.year, wib.month, wib.day);
      final previous = DateTime.tryParse(widget.controller.text);
      final selected = await showDatePicker(
        context: context,
        initialDate: previous != null && !previous.isBefore(today)
            ? previous
            : today,
        firstDate: today,
        lastDate: DateTime(9999, 12, 31),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
        helpText: widget.label,
        cancelText: 'Batal',
        confirmText: 'Pilih tanggal',
      );
      if (selected != null) value = DateFormat('yyyy-MM-dd').format(selected);
    } else {
      final parts = widget.controller.text.split(':');
      final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
      final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
      final selected = await showTimePicker(
        context: context,
        initialTime:
            hour != null &&
                minute != null &&
                hour >= 0 &&
                hour < 24 &&
                minute >= 0 &&
                minute < 60
            ? TimeOfDay(hour: hour, minute: minute)
            : TimeOfDay(hour: wib.hour, minute: wib.minute),
        initialEntryMode: TimePickerEntryMode.dialOnly,
        helpText: widget.label,
        cancelText: 'Batal',
        confirmText: 'Pilih jam',
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (selected != null) {
        value =
            '${selected.hour.toString().padLeft(2, '0')}:'
            '${selected.minute.toString().padLeft(2, '0')}';
      }
    }
    if (!mounted || !widget.enabled || value == null) return;
    widget.controller.text = value;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: widget.enabled ? _choose : null,
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(widget.isDate ? Icons.calendar_month_outlined : Icons.schedule),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text(widget.label), Text(_displayValue)],
            ),
          ),
        ],
      ),
    ),
  );
}

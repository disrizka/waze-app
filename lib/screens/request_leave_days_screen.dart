import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/hr_provider.dart';

class RequestLeaveDayScreen extends StatefulWidget {
  const RequestLeaveDayScreen({super.key, required this.index});
  final int index;

  @override
  State<RequestLeaveDayScreen> createState() => _RequestLeaveDayScreenState();
}

class _RequestLeaveDayScreenState extends State<RequestLeaveDayScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _start = DateTime.now();
  late DateTime _end = DateTime.now().add(const Duration(days: 2));
  String _reason = 'Sick leave';
  String? _attachmentName; // dummy

  final _reasons = const [
    'Sick leave',
    'Annual leave',
    'Personal leave',
    'Family matters',
    'Other',
  ];

  String _fmt(DateTime d) => DateFormat('dd MMMM, yyyy').format(d);

  Future<void> _pickDate({required bool isStart}) async {
    final base = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          if (_end.isBefore(_start)) {
            _end = _start;
          }
        } else {
          _end = picked.isBefore(_start) ? _start : picked;
        }
      });
    }
  }

  void _mockPickAttachment() async {
    // dummy: cukup simulasikan nama file
    setState(
      () => _attachmentName =
          'sick-note-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachment selected (dummy)')),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final hr = context.read<HrProvider>();
    final emp = hr.getByIndex(widget.index);
    if (emp == null) return;

    hr.requestLeave(
      employeeName: emp.name,
      start: _start,
      end: _end,
      reason: _reason,
      attachmentName: _attachmentName,
    );

    // kembali ke Leave Days screen
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Leave request submitted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Request Leave Days',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _FieldLabel('Start Leave Days'),
            _DateField(
              value: _fmt(_start),
              onTap: () => _pickDate(isStart: true),
            ),
            const SizedBox(height: 12),
            const _FieldLabel('End Leave Days'),
            _DateField(
              value: _fmt(_end),
              onTap: () => _pickDate(isStart: false),
            ),
            const SizedBox(height: 12),
            const _FieldLabel('Reason Leave Days'),
            DropdownButtonFormField<String>(
              value: _reason,
              items: _reasons
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 16),
            // Attachment box (dummy)
            InkWell(
              onTap: _mockPickAttachment,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4463FF).withOpacity(.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.upload_rounded,
                        color: Color(0xFF4463FF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachmentName == null
                                ? 'Upload Attachment'
                                : _attachmentName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF3B82F6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Format JPG, PNG',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B5BDB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                child: const Text('Request Form'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return const InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF4C6EF5), width: 1.6),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      decoration: const InputDecoration(
        suffixIcon: Icon(Icons.calendar_month_rounded),
      ).copyWith(hintText: value),
      validator: (_) => null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/school.dart';
import '../shared/location_picker.dart';

/// Add or edit a school: its details and where it is on the map (drivers and families rely on the pin).
class SchoolFormScreen extends ConsumerStatefulWidget {
  const SchoolFormScreen({super.key, this.school});

  final School? school;

  @override
  ConsumerState<SchoolFormScreen> createState() => _SchoolFormScreenState();
}

class _SchoolFormScreenState extends ConsumerState<SchoolFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.school?.name);
  late final _address = TextEditingController(text: widget.school?.address);
  late final _city = TextEditingController(text: widget.school?.city ?? 'Gaborone');
  late final _reg = TextEditingController(text: widget.school?.registrationNumber);
  late final _phone = TextEditingController(text: widget.school?.phone);
  late final _email = TextEditingController(text: widget.school?.email);
  late LatLng? _pin = widget.school?.latitude != null && widget.school?.longitude != null
      ? LatLng(widget.school!.latitude!, widget.school!.longitude!)
      : null;

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_pin == null) {
      showMessage(context, 'Tap the school on the map to pin it', error: true);
      return;
    }
    final ok = await runAction(
      context,
      () => ref.read(adminApiProvider).saveSchool(widget.school?.id, {
        'name': _v(_name),
        'address': _v(_address),
        'city': _v(_city),
        'registrationNumber': _v(_reg),
        'phone': _v(_phone),
        'email': _v(_email),
        'latitude': _pin!.latitude,
        'longitude': _pin!.longitude,
      }),
      success: widget.school == null ? 'School added' : 'Saved',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final fields = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(controller: _name, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'School name', prefixIcon: Icon(Icons.school_outlined)), validator: requiredField),
      const SizedBox(height: 12),
      TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Street address / plot',
          prefixIcon: Icon(Icons.place_outlined)), validator: requiredField),
      const SizedBox(height: 12),
      TextFormField(controller: _city, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'City or town', prefixIcon: Icon(Icons.location_city_outlined)),
          validator: requiredField),
      const SizedBox(height: 12),
      TextFormField(controller: _reg, decoration: const InputDecoration(labelText: 'Ministry registration number (optional)')),
      const SizedBox(height: 12),
      TextFormField(controller: _phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'School phone (optional)', prefixIcon: Icon(Icons.phone_outlined))),
      const SizedBox(height: 12),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'School email (optional)', prefixIcon: Icon(Icons.mail_outline_rounded))),
    ]);
    final map = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Location', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      LocationPicker(value: _pin, onChanged: (p) => setState(() => _pin = p), height: wide ? 420 : 300),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(widget.school == null ? 'Add a school' : 'Edit ${widget.school!.name}')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Constrained(
            maxWidth: 1100,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: fields),
                  const SizedBox(width: 24),
                  Expanded(child: map),
                ])
              else ...[fields, const SizedBox(height: 20), map],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: BusyButton(onPressed: _save, child: Text(widget.school == null ? 'Add school' : 'Save')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/school.dart';

/// Searchable list of verified schools. Returns the chosen school, or null.
Future<School?> pickSchool(BuildContext context) =>
    showDialog<School>(context: context, builder: (_) => const _SchoolPickerDialog());

class _SchoolPickerDialog extends ConsumerStatefulWidget {
  const _SchoolPickerDialog();

  @override
  ConsumerState<_SchoolPickerDialog> createState() => _SchoolPickerDialogState();
}

class _SchoolPickerDialogState extends ConsumerState<_SchoolPickerDialog> {
  Timer? _debounce;
  late Future<List<School>> _results = ref.read(commonApiProvider).schools();

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _results = ref.read(commonApiProvider).schools(query: query));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose a school'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'School name or town'),
            onChanged: _search,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<School>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.hasError) return ErrorState(message: snapshot.error.toString());
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final schools = snapshot.data!;
                if (schools.isEmpty) {
                  return const EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No schools found',
                    message: "Your school may not be on SchoolDrop yet — ask them to register.",
                  );
                }
                return ListView(children: [
                  for (final s in schools)
                    ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(s.name),
                      subtitle: Text('${s.address}, ${s.city}'),
                      onTap: () => Navigator.pop(context, s),
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}

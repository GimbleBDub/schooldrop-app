import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';

/// Report a problem, or raise an SOS. SOS goes straight to SchoolDrop support (and to parents, if relevant).
Future<void> showIncidentSheet(BuildContext context, {String? tripId, bool sos = false}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _IncidentSheet(tripId: tripId, sos: sos),
  );
}

class _IncidentSheet extends ConsumerStatefulWidget {
  const _IncidentSheet({this.tripId, required this.sos});

  final String? tripId;
  final bool sos;

  @override
  ConsumerState<_IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends ConsumerState<_IncidentSheet> {
  late String _type = widget.sos ? 'SOS' : 'SAFETY_CONCERN';
  final _description = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.sos ? 'Emergency (SOS)' : 'Report a problem', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (widget.sos)
          Text('SchoolDrop support will be alerted immediately. If anyone is in danger, also call 999 (police) '
              'or 997 (ambulance).', style: TextStyle(color: theme.colorScheme.error)),
        if (!widget.sos) ...[
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'SAFETY_CONCERN', label: Text('Safety')),
              ButtonSegment(value: 'COMPLAINT', label: Text('Complaint')),
              ButtonSegment(value: 'OTHER', label: Text('Other')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _description,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'What happened?'),
        ),
        const SizedBox(height: 16),
        BusyButton(
          style: widget.sos ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error) : null,
          icon: widget.sos ? Icons.sos : Icons.send,
          onPressed: () async {
            final description = _description.text.trim().isEmpty && widget.sos ? 'SOS pressed' : _description.text.trim();
            if (description.isEmpty) return;
            final ok = await runAction(
              context,
              () => ref.read(commonApiProvider)
                  .reportIncident(type: _type, description: description, tripId: widget.tripId),
              success: widget.sos ? 'Help is on the way — support has been alerted' : 'Thanks, our team will look into it',
            );
            if (ok && context.mounted) Navigator.pop(context);
          },
          child: Text(widget.sos ? 'Send SOS' : 'Send report'),
        ),
      ]),
    );
  }
}

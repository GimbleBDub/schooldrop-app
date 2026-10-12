import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/trip.dart';

/// One handover step with both sides: what the driver did, and who on the other side confirmed it.
class _Step {
  const _Step(this.title, this.driverAt, this.driverText, this.confirmedAt, this.confirmedBy, this.waitingFor);

  final String title;
  final DateTime? driverAt;
  final String driverText;
  final DateTime? confirmedAt;
  final String? confirmedBy;

  /// Who should confirm, e.g. "the family", "the school"
  final String waitingFor;
}

/// The handover record for one child on one trip:
///   morning   — family hands over → driver picks up → driver drops at school → school confirms arrival
///   afternoon — school releases → driver collects → driver drops home (handed to …) → family confirms
class HandoverTimeline extends StatelessWidget {
  const HandoverTimeline({super.key, required this.passenger, required this.toSchool, this.compact = false});

  final Passenger passenger;
  final bool toSchool;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = passenger;
    final steps = toSchool
        ? [
            _Step('Picked up from home', p.pickedUpAt, 'Driver picked up', p.pickupConfirmedAt, p.pickupConfirmedBy, 'the family'),
            _Step('Arrived at school', p.droppedOffAt, 'Driver dropped off', p.dropoffConfirmedAt, p.dropoffConfirmedBy, 'the school'),
          ]
        : [
            _Step('Collected from school', p.pickedUpAt, 'Driver collected', p.pickupConfirmedAt, p.pickupConfirmedBy, 'the school'),
            _Step('Home', p.droppedOffAt, p.handedTo != null ? 'Handed to ${p.handedTo}' : 'Driver dropped off',
                p.dropoffConfirmedAt, p.dropoffConfirmedBy, 'the family'),
          ];
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < steps.length; i++) _StepRow(step: steps[i], last: i == steps.length - 1, compact: compact),
      if (p.disputedAt != null)
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.report_rounded, size: 18, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Problem reported ${formatTime(p.disputedAt)}${p.disputeNote != null ? ': ${p.disputeNote}' : ''}',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
          ]),
        ),
      if (!compact && (p.kidConfirmedPickupAt != null || p.kidConfirmedDropoffAt != null))
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 30),
          child: Text(
            [
              if (p.kidConfirmedPickupAt != null) '${p.firstName} confirmed pickup ${formatTime(p.kidConfirmedPickupAt)}',
              if (p.kidConfirmedDropoffAt != null) '${p.firstName} confirmed arrival ${formatTime(p.kidConfirmedDropoffAt)}',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
    ]);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last, required this.compact});

  final _Step step;
  final bool last;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driverDone = step.driverAt != null;
    final confirmed = step.confirmedAt != null;
    final (Color color, IconData icon) = driverDone && confirmed
        ? (const Color(0xFF15803D), Icons.check_circle_rounded)
        : driverDone || confirmed
            ? (const Color(0xFFB45309), Icons.timelapse_rounded)
            : (theme.colorScheme.outline, Icons.radio_button_unchecked_rounded);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Icon(icon, size: 20, color: color),
          if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: theme.colorScheme.outlineVariant)),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (driverDone) Text('${step.driverText} · ${formatTime(step.driverAt)}', style: muted),
              Text(
                confirmed
                    ? 'Confirmed by ${step.confirmedBy ?? step.waitingFor} · ${formatTime(step.confirmedAt)}'
                    : driverDone
                        ? 'Waiting for ${step.waitingFor} to confirm'
                        : 'Not yet',
                style: muted?.copyWith(color: confirmed ? const Color(0xFF15803D) : null),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

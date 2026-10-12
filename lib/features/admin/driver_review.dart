import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../models/common.dart';
import '../../models/driver.dart';
import '../driver/onboarding_screen.dart' show documentLabels;
import 'file_opener.dart';

void openDriverReview(BuildContext context, String driverId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DriverReviewScreen(driverId: driverId)));

final _driverProvider = FutureProvider.autoDispose.family<DriverProfile, String>(
    (ref, id) => ref.watch(adminApiProvider).driver(id));

/// A verifier's view of one driver: identity, vehicles, every document with approve/reject, and the decision.
class DriverReviewScreen extends ConsumerWidget {
  const DriverReviewScreen({super.key, required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(_driverProvider(driverId));
    final canVerify = ref.watch(sessionProvider).user?.can('VERIFIER') ?? false;
    void refresh() => ref.invalidate(_driverProvider(driverId));

    return Scaffold(
      appBar: AppBar(title: Text(driver.value?.fullName ?? 'Driver')),
      body: AsyncBody<DriverProfile>(
        value: driver,
        onRetry: refresh,
        builder: (d) => Constrained(
          maxWidth: 1000,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(d.fullName, style: Theme.of(context).textTheme.headlineSmall)),
                    StatusChip(d.status),
                  ]),
                  if (d.statusReason != null) Text(d.statusReason!),
                  const SizedBox(height: 8),
                  InfoRow('Email', d.email),
                  InfoRow('Phone', d.phone),
                  InfoRow('Omang', d.omangNumber),
                  InfoRow('Date of birth', formatDate(d.dateOfBirth)),
                  InfoRow('Licence', '${d.licenceNumber ?? '—'} · code ${d.licenceCode ?? '—'} · expires ${formatDate(d.licenceExpiry)}'),
                  InfoRow('Home area', d.homeArea),
                  InfoRow('Payouts', '${label(d.payoutMethod)} ${d.payoutAccount ?? ''}'),
                  InfoRow('Schools', d.schools.map((s) => s.name).join(', ')),
                  InfoRow('Submitted', dateTime(d.submittedAt)),
                ]),
              ),
            ),
            if (d.missingRequirements.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.checklist),
                  title: const Text('Before approval'),
                  subtitle: Text(d.missingRequirements.join('\n')),
                ),
              ),
            const SectionTitle('Checklist for verifiers'),
            const Text('• Selfie matches the Omang photo  • Names and Omang number match across documents\n'
                '• Police clearance issued within 90 days; certificate number recorded  • Licence code allows the vehicle type\n'
                '• Plate on registration, roadworthy and insurance matches the vehicle photo'),
            const SectionTitle('Vehicles'),
            for (final v in d.vehicles)
              ListTile(
                leading: const Icon(Icons.airport_shuttle),
                title: Text(v.displayName),
                subtitle: Text('${label(v.type)} · ${v.seatCapacity} seats · year ${v.year ?? '—'}'),
                trailing: v.verified ? const Icon(Icons.verified, color: Colors.green) : const StatusChip('PENDING'),
              ),
            const SectionTitle('Documents'),
            for (final doc in d.documents)
              Card(
                child: ListTile(
                  leading: Icon(doc.isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined),
                  title: Text('${documentLabels[doc.type] ?? doc.type}${doc.vehiclePlate != null ? ' — ${doc.vehiclePlate}' : ''}'),
                  subtitle: Text([
                    'Uploaded ${dateTime(doc.uploadedAt)}',
                    if (doc.referenceNumber != null) 'No. ${doc.referenceNumber}',
                    if (doc.issuedOn != null) 'issued ${formatDate(doc.issuedOn)}',
                    if (doc.expiresOn != null) 'expires ${formatDate(doc.expiresOn)}',
                    if (doc.reviewNote != null) doc.reviewNote!,
                  ].join(' · ')),
                  trailing: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusChip(doc.status),
                    IconButton(
                      tooltip: 'View',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _view(context, ref, doc),
                    ),
                    if (canVerify && doc.status == 'PENDING') ...[
                      IconButton(
                        tooltip: 'Reject',
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          final note = await askText(context, 'Reject ${documentLabels[doc.type]}?',
                              label: 'What should the driver fix?');
                          if (note == null || !context.mounted) return;
                          await runAction(context, () => ref.read(adminApiProvider).reviewDocument(doc.id, false, note));
                          refresh();
                        },
                      ),
                      IconButton(
                        tooltip: 'Approve',
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          await runAction(context, () => ref.read(adminApiProvider).reviewDocument(doc.id, true, null));
                          refresh();
                        },
                      ),
                    ],
                  ]),
                ),
              ),
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, children: [
              if (canVerify && (d.status == 'UNDER_REVIEW' || d.status == 'SUSPENDED'))
                BusyButton(
                  icon: Icons.verified,
                  onPressed: () async {
                    await runAction(context, () => ref.read(adminApiProvider).driverAction(d.id, 'approve'),
                        success: '${d.fullName} approved');
                    refresh();
                  },
                  child: Text(d.status == 'SUSPENDED' ? 'Reinstate driver' : 'Approve driver'),
                ),
              if (canVerify && d.status == 'UNDER_REVIEW')
                OutlinedButton.icon(
                  icon: const Icon(Icons.block),
                  label: const Text('Reject application'),
                  onPressed: () async {
                    final reason = await askText(context, 'Reject ${d.fullName}?', label: 'Reason (sent to the driver)');
                    if (reason == null || !context.mounted) return;
                    await runAction(context, () => ref.read(adminApiProvider).driverAction(d.id, 'reject', reason: reason));
                    refresh();
                  },
                ),
              if (d.status == 'APPROVED')
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Suspend driver'),
                  onPressed: () async {
                    final reason = await askText(context, 'Suspend ${d.fullName}?',
                        label: 'Reason — their offers stop immediately');
                    if (reason == null || !context.mounted) return;
                    await runAction(context, () => ref.read(adminApiProvider).driverAction(d.id, 'suspend', reason: reason));
                    refresh();
                  },
                ),
            ]),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Future<void> _view(BuildContext context, WidgetRef ref, DriverDocument doc) async {
    List<int>? bytes;
    final ok = await runAction(context, () async => bytes = await ref.read(adminApiProvider).documentFile(doc.id));
    if (!ok || !context.mounted) return;
    if (doc.isImage) {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(documentLabels[doc.type] ?? doc.type),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 900,
                maxHeight: MediaQuery.of(context).size.height * 0.75,
                minHeight: 200,
              ),
              child: InteractiveViewer(
                child: Image.memory(
                  Uint8List.fromList(bytes!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text("This file isn't a readable image. Reject it and ask the driver to upload again."),
                    ),
                  ),
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open full size in a new tab'),
              onPressed: () => openBytesInBrowser(bytes!, doc.contentType),
            ),
          ]),
        ),
      );
    } else {
      openBytesInBrowser(bytes!, doc.contentType);
    }
  }
}

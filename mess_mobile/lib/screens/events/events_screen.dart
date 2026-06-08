import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/common.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CreateEventScreen(repo: repo, messId: messId, profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Mess?>(
      stream: repo.messStream(messId),
      builder: (context, messSnap) {
        final currency = messSnap.data?.currency;
        return StreamBuilder<List<MessEvent>>(
          stream: repo.eventsStream(messId),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load events: ${snap.error}'),
                ),
              );
            }
            final events = snap.data ?? const <MessEvent>[];
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  title: const Text('Events'),
                  actions: [
                    IconButton(
                      tooltip: 'Create event',
                      onPressed: () => _openCreate(context),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Create an event for trips, weekend cooks, or shared utilities. '
                      'Expenses tagged to an event are split only among joiners.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                if (events.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_outlined,
                                size: 56, color: AppColors.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No events yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap + to create an event.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = events[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _EventCard(
                          event: e,
                          currencyCode: currency,
                          isJoined: e.isJoiner(profile.uid),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EventDetailScreen(
                                  repo: repo,
                                  messId: messId,
                                  profile: profile,
                                  eventId: e.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.currencyCode,
    required this.isJoined,
    required this.onTap,
  });

  final MessEvent event;
  final String? currencyCode;
  final bool isJoined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd().add_jm();
    final whenLabel = event.startsAt > 0
        ? dateFmt.format(DateTime.fromMillisecondsSinceEpoch(event.startsAt))
        : 'TBD';
    final closed = event.status == EventStatuses.closed;
    final hasEstimate = event.estimatedCost != null && event.estimatedCost! > 0;
    final joiners = event.joinerUids.length;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(closed
                        ? 'Closed'
                        : isJoined
                            ? 'Joined'
                            : '$joiners joining'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: closed
                        ? Colors.grey.shade300
                        : isJoined
                            ? AppColors.secondaryContainerTint
                            : AppColors.warningSurface,
                  ),
                ],
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  event.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    whenLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              if (hasEstimate) ...[
                const SizedBox(height: 8),
                Text(
                  joiners > 0
                      ? 'Est. ${formatMessMoney(event.estimatedCost!, currencyCode: currencyCode)} total · '
                          '${formatMessMoney(event.estimatedPerPerson, currencyCode: currencyCode)} per joiner'
                      : 'Est. ${formatMessMoney(event.estimatedCost!, currencyCode: currencyCode)} total',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateEventScreen extends StatefulWidget {
  const _CreateEventScreen({
    required this.repo,
    required this.messId,
    required this.profile,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  @override
  State<_CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<_CreateEventScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _estimate = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 4));
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _estimate.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _date,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showSnackError(context, StateError('Enter an event title.'));
      return;
    }
    final estimateParsed = double.tryParse(_estimate.text.trim());
    setState(() => _busy = true);
    try {
      await widget.repo.createEvent(
        messId: widget.messId,
        title: title,
        description: _desc.text.trim(),
        startsAt: _date.millisecondsSinceEpoch,
        createdBy: widget.profile.uid,
        createdByName: widget.profile.displayName,
        estimatedCost: estimateParsed,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd().add_jm();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Create event'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            decoration: borderedField(
              label: 'Event title',
              hint: 'Beach trip, group dinner…',
              prefix: Icon(Icons.event_rounded, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: borderedField(
              label: 'Description (optional)',
              prefix: Icon(Icons.notes_rounded, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _estimate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: borderedField(
              label: 'Estimated total cost (optional)',
              hint: '500',
              prefix: Icon(Icons.payments_outlined, color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Per-person estimate is calculated from joiners when members join.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Icon(Icons.schedule_rounded, color: AppColors.primaryDark),
            title: const Text('Starts at'),
            subtitle: Text(dateFmt.format(_date)),
            trailing: const Icon(Icons.edit_rounded),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create event'),
          ),
        ],
      ),
    );
  }
}

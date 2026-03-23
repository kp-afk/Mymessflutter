import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/rebate_data.dart';
import '../providers/rebate_provider.dart';

class RebateScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const RebateScreen({super.key, required this.onBack});

  @override
  ConsumerState<RebateScreen> createState() => _RebateScreenState();
}

class _RebateScreenState extends ConsumerState<RebateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rebateProvider);
    final cs = Theme.of(context).colorScheme;

    // Sync controller with provider state after submission
    ref.listen<RebateState>(rebateProvider, (prev, next) {
      if (next.submitSuccess && !(prev?.submitSuccess ?? false)) {
        _reasonController.clear();
        _tabController.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Rebate application submitted successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        ref.read(rebateProvider.notifier).clearSuccessMessage();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Mess Rebates'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Apply'),
            Tab(text: 'My Applications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplyTab(state, cs),
          _buildHistoryTab(state, cs),
        ],
      ),
    );
  }

  // ─── Apply Tab ──────────────────────────────────────────────────────────

  Widget _buildApplyTab(RebateState state, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          _InfoBanner(cs: cs),

          const SizedBox(height: 24),

          Text(
            'Application Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Date pickers
          Row(
            children: [
              Expanded(
                child: _DatePickerCard(
                  label: 'From',
                  icon: Icons.flight_takeoff_rounded,
                  date: state.startDate,
                  firstDate: DateTime.now(),
                  lastDate:
                  DateTime.now().add(const Duration(days: 365)),
                  onPicked: (date) =>
                      ref.read(rebateProvider.notifier).updateStartDate(date),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DatePickerCard(
                  label: 'To',
                  icon: Icons.flight_land_rounded,
                  date: state.endDate,
                  firstDate: state.startDate ?? DateTime.now(),
                  lastDate:
                  DateTime.now().add(const Duration(days: 365)),
                  onPicked: (date) =>
                      ref.read(rebateProvider.notifier).updateEndDate(date),
                ),
              ),
            ],
          ),

          // Day count chip
          if (state.startDate != null && state.endDate != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '${state.totalDays} day${state.totalDays == 1 ? '' : 's'} away',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Reason field
          Text(
            'Reason for leave',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            maxLength: 300,
            onChanged: (v) =>
                ref.read(rebateProvider.notifier).updateReason(v),
            decoration: InputDecoration(
              hintText: 'e.g. Going home for Diwali holidays',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
            ),
          ),

          // Error message
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline, color: cs.error, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
              state.isSubmitting ? null : _handleSubmit,
              icon: state.isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.send_rounded),
              label: Text(
                  state.isSubmitting ? 'Submitting...' : 'Submit Application'),
            ),
          ),

          const SizedBox(height: 24),

          // Note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: cs.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your application will be reviewed by the mess manager. You\'ll see the status update in "My Applications".',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── History Tab ─────────────────────────────────────────────────────────

  Widget _buildHistoryTab(RebateState state, ColorScheme cs) {
    if (state.isLoadingRebates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.userRebates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 64, color: cs.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'No applications yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apply for a rebate when you\'re going home and won\'t be eating in the mess.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withOpacity(0.4)),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () => _tabController.animateTo(0),
                child: const Text('Apply Now'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(rebateProvider.notifier).loadUserRebates(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.userRebates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _RebateCard(rebate: state.userRebates[index]),
      ),
    );
  }

  void _handleSubmit() {
    ref.read(rebateProvider.notifier).submitRebate();
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final ColorScheme cs;
  const _InfoBanner({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer,
            cs.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.onPrimaryContainer.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.home_outlined,
                color: cs.onPrimaryContainer, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Going home?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Apply for a mess rebate and get a refund for the days you\'re away.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? date;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPicked;

  const _DatePickerCard({
    required this.label,
    required this.icon,
    required this.date,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = date != null;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? firstDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? cs.primary.withOpacity(0.4)
                : cs.outline.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: isSelected
                        ? cs.onPrimaryContainer
                        : cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? cs.onPrimaryContainer.withOpacity(0.7)
                        : cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isSelected
                  ? DateFormat('d MMM yyyy').format(date!)
                  : 'Select date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? cs.onPrimaryContainer
                    : cs.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RebateCard extends StatelessWidget {
  final Rebate rebate;
  const _RebateCard({required this.rebate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _statusConfig(rebate.status, cs);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: dates + status badge
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.date_range_rounded,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('d MMM').format(rebate.startDate)} – ${DateFormat('d MMM yyyy').format(rebate.endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(label: rebate.status, config: status),
              ],
            ),

            const SizedBox(height: 10),

            // Days count
            Row(
              children: [
                _MetaChip(
                  icon: Icons.nights_stay_outlined,
                  label: '${rebate.totalDays} day${rebate.totalDays == 1 ? '' : 's'}',
                  cs: cs,
                ),
                const SizedBox(width: 8),
                if (rebate.timestamp != null)
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: 'Applied ${DateFormat('d MMM').format(rebate.timestamp!)}',
                    cs: cs,
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Reason
            Text(
              rebate.reason,
              style: TextStyle(
                  fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
            ),

            // Manager note (if any)
            if (rebate.managerNote != null &&
                rebate.managerNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: status.containerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment_outlined,
                        size: 14, color: status.textColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rebate.managerNote!,
                        style: TextStyle(
                            fontSize: 12, color: status.textColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StatusConfig _statusConfig(String status, ColorScheme cs) {
    switch (status) {
      case 'Approved':
        return _StatusConfig(
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade600,
          containerColor: Colors.green.shade50,
          textColor: Colors.green.shade800,
        );
      case 'Rejected':
        return _StatusConfig(
          icon: Icons.cancel_rounded,
          color: Colors.red.shade600,
          containerColor: Colors.red.shade50,
          textColor: Colors.red.shade800,
        );
      default:
        return _StatusConfig(
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange.shade600,
          containerColor: Colors.orange.shade50,
          textColor: Colors.orange.shade800,
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final Color containerColor;
  final Color textColor;
  const _StatusConfig({
    required this.icon,
    required this.color,
    required this.containerColor,
    required this.textColor,
  });
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final _StatusConfig config;
  const _StatusBadge({required this.label, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.containerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  const _MetaChip(
      {required this.icon, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
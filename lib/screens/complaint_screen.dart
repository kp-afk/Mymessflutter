import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/complaint_provider.dart';

class ComplaintScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ComplaintScreen({
    super.key,
    required this.onBack,
  });

  @override
  ConsumerState<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends ConsumerState<ComplaintScreen> {
  final _complaintController = TextEditingController();

  final List<String> _categories = [
    'Food Quality',
    'Service',
    'Hygiene',
    'Other',
  ];

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaintState = ref.watch(complaintProvider);

    // Listen for success - no need to listen for auth changes anymore
    ref.listen(complaintProvider, (previous, next) {
      if (next.submitSuccess && !(previous?.submitSuccess ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(complaintProvider.notifier).clearSuccessMessage();
      }
    });

    // Sync text field with state
    if (_complaintController.text != complaintState.complaintText) {
      _complaintController.text = complaintState.complaintText;
      _complaintController.selection = TextSelection.fromPosition(
        TextPosition(offset: complaintState.complaintText.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints & Feedback'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Submit New Complaint Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submit a Complaint',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: complaintState.selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(complaintProvider.notifier).updateCategory(value);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Complaint Text Field
                  TextField(
                    controller: _complaintController,
                    decoration: InputDecoration(
                      labelText: 'Describe your complaint',
                      hintText: 'Please provide details...',
                      border: const OutlineInputBorder(),
                      errorText: complaintState.errorMessage,
                    ),
                    maxLines: 5,
                    onChanged: (text) {
                      ref.read(complaintProvider.notifier).updateComplaintText(text);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: complaintState.isSubmitting
                          ? null
                          : () {
                        ref.read(complaintProvider.notifier).submitComplaint();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: complaintState.isSubmitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text('Submit Complaint'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Previous Complaints Section
          Text(
            'Your Previous Complaints',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (complaintState.isLoadingComplaints)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (complaintState.userComplaints.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No complaints submitted yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            )
          else
            ...complaintState.userComplaints.map((complaint) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(complaint.status, context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              complaint.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              complaint.category,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (complaint.timestamp != null)
                            Text(
                              DateFormat('MMM dd, yyyy').format(complaint.timestamp!),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        complaint.complaintText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
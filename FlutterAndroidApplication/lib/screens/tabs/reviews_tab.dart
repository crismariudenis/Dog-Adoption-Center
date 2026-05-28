import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ReviewsTab extends StatefulWidget {
  const ReviewsTab({super.key});

  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  static const String demoShelterId = '00000000-0000-0000-0000-000000000001';
  static const String demoUserId = '00000000-0000-0000-0000-000000000002';

  List<dynamic> _reviews = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  // Form State
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final reviewsData = await ApiService.getReviewsByShelter(demoShelterId);
      final summaryData = await ApiService.getShelterSummary(demoShelterId);

      setState(() {
        _reviews = reviewsData;
        _summary = summaryData;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _submitReview() async {
    if (_nameController.text.trim().isEmpty || _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      await ApiService.createReview({
        'shelterId': demoShelterId,
        'userId': auth.user?['id'] ?? demoUserId,
        'userName': _nameController.text.trim(),
        'rating': _rating,
        'comment': _commentController.text.trim(),
      });

      _nameController.clear();
      _commentController.clear();
      _rating = 5;

      await _fetchReviews();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted! Thanks for sharing.')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit review: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  Future<void> _deleteReview(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteReview(id);
      setState(() {
        _reviews.removeWhere((r) => r['id'].toString() == id);
      });
      // Refresh summary
      final summaryData = await ApiService.getShelterSummary(demoShelterId);
      setState(() {
        _summary = summaryData;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete review: $e')),
      );
    }
  }

  Widget _buildStars(double rating, {double size = 16}) {
    final intRating = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < intRating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  Widget _buildInteractiveStars() {
    return Row(
      children: List.generate(5, (index) {
        return IconButton(
          onPressed: () {
            setState(() {
              _rating = index + 1;
            });
          },
          icon: Icon(
            index < _rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final averageRating = double.tryParse(_summary?['averageRating']?.toString() ?? '') ?? 0.0;
    final totalReviews = int.tryParse(_summary?['totalReviews']?.toString() ?? '') ?? 0;

    return RefreshIndicator(
      onRefresh: _fetchReviews,
      color: const Color(0xFFB45309),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rating Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shelter Reviews',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 4),
                    if (_summary != null)
                      Row(
                        children: [
                          _buildStars(averageRating, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${averageRating.toStringAsFixed(1)} • $totalReviews review${totalReviews != 1 ? 's' : ''}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchReviews,
                  color: const Color(0xFFB45309),
                )
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            // Leave a review card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave a Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF92400E))),
                    const SizedBox(height: 12),
                    const Text('Your name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: 'John Doe'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    _buildInteractiveStars(),
                    const SizedBox(height: 12),
                    const Text('Comment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Share your experience with the shelter...'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitReview,
                        child: _submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Submit Review'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Reviews List
            const Text(
              'Recent Reviews',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFFB45309)),
                ),
              )
            else if (_reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No reviews yet. Be the first to write one!',
                  style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                itemBuilder: (ctx, index) {
                  final review = _reviews[index];
                  final reviewId = review['id']?.toString() ?? '';
                  final userName = review['userName'] as String? ?? 'Anonymous';
                  final rating = double.tryParse(review['rating']?.toString() ?? '') ?? 5.0;
                  final comment = review['comment'] as String? ?? '';
                  final createdAtStr = review['createdAt'] as String? ?? '';

                  String dateStr = '';
                  if (createdAtStr.isNotEmpty) {
                    try {
                      final date = DateTime.parse(createdAtStr);
                      dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    } catch (_) {}
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    _buildStars(rating, size: 14),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                    onPressed: () => _deleteReview(reviewId),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Text(
                            comment,
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

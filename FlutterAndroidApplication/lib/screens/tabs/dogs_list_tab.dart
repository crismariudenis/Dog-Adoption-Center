import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../dialogs/adopt_dialog.dart';

class DogsListTab extends StatefulWidget {
  const DogsListTab({super.key});

  @override
  State<DogsListTab> createState() => _DogsListTabState();
}

class _DogsListTabState extends State<DogsListTab> {
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _dogs = [
    {
      'id': 1,
      'name': 'Buddy',
      'breed': 'Golden Retriever',
      'age': '2 years',
      'status': 'Available',
      'breedSlug': 'retriever/golden',
    },
    {
      'id': 2,
      'name': 'Max',
      'breed': 'Doberman',
      'age': '3 years',
      'status': 'Available',
      'breedSlug': 'doberman',
    },
    {
      'id': 3,
      'name': 'Bella',
      'breed': 'Labrador',
      'age': '1 year',
      'status': 'Pending',
      'breedSlug': 'labrador',
    },
    {
      'id': 4,
      'name': 'Charlie',
      'breed': 'Beagle',
      'age': '4 years',
      'status': 'Available',
      'breedSlug': 'beagle',
    },
    {
      'id': 5,
      'name': 'Luna',
      'breed': 'Husky',
      'age': '2 years',
      'status': 'Available',
      'breedSlug': 'husky',
    },
    {
      'id': 6,
      'name': 'Rocky',
      'breed': 'Bulldog',
      'age': '5 years',
      'status': 'Adopted',
      'breedSlug': 'bulldog/english',
    },
  ];

  final Map<int, String> _dogImages = {};

  @override
  void initState() {
    super.initState();
    _fetchDogImages();
    _trackPetViews();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDogImages() async {
    for (var dog in _dogs) {
      final id = dog['id'] as int;
      final breedSlug = dog['breedSlug'] as String;
      try {
        final res = await http.get(Uri.parse('https://dog.ceo/api/breed/$breedSlug/images/random'));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == 'success') {
            if (mounted) {
              setState(() {
                _dogImages[id] = data['message'] as String;
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _trackPetViews() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    for (var dog in _dogs) {
      final id = dog['id'] as int;
      final petUuid = '00000000-0000-0000-0000-00000000000${id.toString().padLeft(1, '0')}';
      try {
        await ApiService.trackEvent({
          'petId': petUuid,
          'userId': auth.user?['id'] ?? '00000000-0000-0000-0000-000000000002',
          'shelterId': '00000000-0000-0000-0000-000000000001',
          'eventType': 'pet.viewed',
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
          'metadata': {'petName': dog['name']},
        });
      } catch (_) {}
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green[50]!;
      case 'Pending':
        return Colors.amber[50]!;
      case 'Adopted':
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Available':
        return Colors.green[700]!;
      case 'Pending':
        return Colors.amber[800]!;
      case 'Adopted':
      default:
        return Colors.grey[600]!;
    }
  }

  void _scrollToDogs() {
    _scrollController.animateTo(
      280.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Banner
          Container(
            color: const Color(0xFFB45309), // Amber-700
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              children: [
                const Text(
                  'Find Your Perfect Companion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every dog deserves a loving home. Browse our available dogs and start your adoption journey today.',
                  style: TextStyle(
                    color: Color(0xFFFDE68A), // Amber-200
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _scrollToDogs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB45309),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Start Adopting', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main List Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dogs Available for Adoption',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E), // Amber-800
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _dogs.length,
                  itemBuilder: (ctx, index) {
                    final dog = _dogs[index];
                    final id = dog['id'] as int;
                    final imageUrl = _dogImages[id];
                    final status = dog['status'] as String;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Dog Image Container
                          Container(
                            height: 180,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: imageUrl != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Center(child: Text('🐕', style: TextStyle(fontSize: 48))),
                                    ),
                                  )
                                : const Center(child: Text('🐕', style: TextStyle(fontSize: 48))),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dog['name'] as String,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusBgColor(status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: _getStatusTextColor(status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${dog['breed']} • ${dog['age']}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: status == 'Available'
                                        ? () async {
                                            final result = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AdoptDialog(dog: dog),
                                            );
                                            if (result == true) {
                                              setState(() {
                                                dog['status'] = 'Pending';
                                              });
                                            }
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: status == 'Available'
                                          ? const Color(0xFFB45309)
                                          : Colors.grey[300],
                                      foregroundColor: status == 'Available'
                                          ? Colors.white
                                          : Colors.grey[600],
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    child: Text(status == 'Available' ? 'Adopt Me' : status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

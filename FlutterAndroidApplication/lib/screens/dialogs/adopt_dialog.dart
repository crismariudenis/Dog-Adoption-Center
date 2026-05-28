import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdoptDialog extends StatefulWidget {
  final Map<String, dynamic> dog;

  const AdoptDialog({super.key, required this.dog});

  @override
  State<AdoptDialog> createState() => _AdoptDialogState();
}

class _AdoptDialogState extends State<AdoptDialog> {
  final _messageController = TextEditingController();
  bool _requiresLandlordConsent = false;
  bool _submitting = false;
  bool _success = false;
  String? _errorMessage;

  // Documents state
  final Map<String, XFile?> _files = {
    'GovernmentId': null,
    'ProofOfResidence': null,
    'LandlordConsent': null,
  };

  // Predefined demo template mock files (so developers can test without real images)
  final Map<String, Map<String, dynamic>> _demoTemplates = {
    'GovernmentId': {
      'name': 'demo_id.jpg',
      'bytes': [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82], // Mock PNG bytes
      'type': 'image/jpeg',
    },
    'ProofOfResidence': {
      'name': 'demo_bank_statement.jpg',
      'bytes': [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82],
      'type': 'image/jpeg',
    },
    'LandlordConsent': {
      'name': 'demo_consent.jpg',
      'bytes': [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82],
      'type': 'image/jpeg',
    },
  };

  // API outputs
  Map<String, dynamic>? _validationResult;
  Map<String, dynamic>? _extractionResult;
  bool _validating = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _getPetUuid(int id) {
    return '00000000-0000-0000-0000-00000000000${id.toString().padLeft(1, '0')}';
  }

  Future<void> _pickFile(String documentType) async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        setState(() {
          _files[documentType] = file;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  void _useDemoTemplate(String documentType) {
    // Generate a simulated XFile using data URI or basic path
    // In our app, we can just flag that this document is using a template.
    // For scanDocuments to work, we need real bytes. We can create a mock XFile by writing dummy bytes.
    setState(() {
      _files[documentType] = XFile.fromData(
        Uint8List.fromList(List<int>.from(_demoTemplates[documentType]!['bytes'])),
        name: _demoTemplates[documentType]!['name'],
        mimeType: _demoTemplates[documentType]!['type'],
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using demo template for $documentType')),
    );
  }

  Map<String, dynamic>? _toDocumentPayload(String docType) {
    final file = _files[docType];
    if (file == null) return null;

    // Simulate sizes if we use fromData
    return {
      'documentType': docType,
      'fileName': file.name,
      'contentType': file.mimeType ?? 'image/jpeg',
      'sizeBytes': 12345, // default mockup size
    };
  }

  Future<void> _validateDocuments() async {
    setState(() {
      _validating = true;
      _errorMessage = null;
      _validationResult = null;
      _extractionResult = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final username = auth.user?['username'] ?? auth.user?['email'] ?? 'Anonymous';
    final email = auth.user?['email'] ?? 'anonymous@example.com';

    try {
      final documents = <Map<String, dynamic>>[];
      final idPayload = _toDocumentPayload('GovernmentId');
      final resPayload = _toDocumentPayload('ProofOfResidence');
      final consentPayload = _requiresLandlordConsent ? _toDocumentPayload('LandlordConsent') : null;

      if (idPayload != null) documents.add(idPayload);
      if (resPayload != null) documents.add(resPayload);
      if (consentPayload != null) documents.add(consentPayload);

      // Validate Application schema
      final valRes = await ApiService.validateApplication({
        'petId': _getPetUuid(widget.dog['id']),
        'userId': auth.user?['id'] ?? '00000000-0000-0000-0000-000000000002',
        'applicantName': username,
        'applicantEmail': email,
        'justification': _messageController.text,
        'requiresLandlordConsent': _requiresLandlordConsent,
        'documents': documents,
      }, token ?? '');

      setState(() {
        _validationResult = valRes;
      });

      final isValid = valRes['isValid'] as bool? ?? false;
      if (!isValid) {
        final errors = List<String>.from(valRes['errors'] ?? []);
        throw Exception(errors.isNotEmpty ? errors.join(' ') : 'Document schema validation failed.');
      }

      // Check if both GovernmentId and ProofOfResidence are uploaded
      final idDoc = _files['GovernmentId'];
      final bankDoc = _files['ProofOfResidence'];

      if (idDoc == null || bankDoc == null) {
        throw Exception('Please select or upload both GovernmentId and ProofOfResidence files to run scan extraction.');
      }

      // Perform OCR Extraction
      final idBytes = await idDoc.readAsBytes();
      final bankBytes = await bankDoc.readAsBytes();

      final extRes = await ApiService.scanDocuments(
        idBytes: idBytes,
        idFileName: idDoc.name,
        bankBytes: bankBytes,
        bankFileName: bankDoc.name,
        expectedFullName: username,
        token: token,
      );

      setState(() {
        _extractionResult = extRes;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _validating = false;
      });
    }
  }

  Future<void> _submitApplication() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    final username = auth.user?['username'] ?? auth.user?['email'] ?? 'Anonymous';
    final email = auth.user?['email'] ?? 'anonymous@example.com';

    try {
      final documents = <Map<String, dynamic>>[];
      final idPayload = _toDocumentPayload('GovernmentId');
      final resPayload = _toDocumentPayload('ProofOfResidence');
      final consentPayload = _requiresLandlordConsent ? _toDocumentPayload('LandlordConsent') : null;

      if (idPayload != null) documents.add(idPayload);
      if (resPayload != null) documents.add(resPayload);
      if (consentPayload != null) documents.add(consentPayload);

      // Submit application
      await ApiService.submitApplication({
        'petId': _getPetUuid(widget.dog['id']),
        'userId': auth.user?['id'] ?? '00000000-0000-0000-0000-000000000002',
        'applicantName': username,
        'applicantEmail': email,
        'justification': _messageController.text,
        'requiresLandlordConsent': _requiresLandlordConsent,
        'documents': documents,
      }, token ?? '');

      // Telemetry: Track Event
      await ApiService.trackEvent({
        'petId': _getPetUuid(widget.dog['id']),
        'userId': auth.user?['id'] ?? '00000000-0000-0000-0000-000000000002',
        'shelterId': '00000000-0000-0000-0000-000000000001',
        'eventType': 'application.submitted',
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'metadata': {'petName': widget.dog['name'], 'applicantName': username},
      });

      setState(() {
        _success = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit application: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  Widget _buildDocRow(String label, String docType) {
    final file = _files[docType];
    return Card(
      color: Colors.amber[50]!.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    file != null ? 'Selected: ${file.name}' : 'No document selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: file != null ? Colors.green[700] : Colors.grey[600],
                      fontWeight: file != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _pickFile(docType),
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Pick Image', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
                TextButton(
                  onPressed: () => _useDemoTemplate(docType),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Use Demo', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('🐾', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Application Submitted!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "We'll review your details and get in touch about ${widget.dog['name']} shortly.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    final isValid = _validationResult?['isValid'] as bool? ?? false;

    return AlertDialog(
      title: Text('Adopt ${widget.dog['name']}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text(
                'Tell us why you want to adopt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Share a bit about your living space, background, and experience with pets...',
                ),
              ),
              const SizedBox(height: 16),

              // Checklist Checkbox
              CheckboxListTile(
                value: _requiresLandlordConsent,
                onChanged: (val) {
                  setState(() {
                    _requiresLandlordConsent = val ?? false;
                  });
                },
                title: const Text('Requires landlord consent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFFB45309),
              ),

              const SizedBox(height: 8),
              const Text(
                'Document Checklist (OCR Verification)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Text(
                'Provide clear mock documents or photos to validate locally.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),

              _buildDocRow('1. Government ID', 'GovernmentId'),
              _buildDocRow('2. Proof of Residence (Bank Statement)', 'ProofOfResidence'),
              if (_requiresLandlordConsent)
                _buildDocRow('3. Landlord Consent Letter', 'LandlordConsent'),

              const SizedBox(height: 16),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[100]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),

              if (_validationResult != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isValid ? Colors.green[50] : Colors.red[50],
                    border: Border.all(color: isValid ? Colors.green[100]! : Colors.red[100]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isValid ? '✓ Schema verification passed.' : '✗ Schema verification failed.',
                        style: TextStyle(
                          color: isValid ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (!isValid && _validationResult?['errors'] != null)
                        ...List<String>.from(_validationResult?['errors'] ?? []).map((err) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('• $err', style: TextStyle(color: Colors.red[700], fontSize: 11)),
                        )),
                    ],
                  ),
                ),

              if (_extractionResult != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[100]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extracted Document Data:',
                        style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text('• ID Name: ${_extractionResult?['extractedIdName'] ?? "Not found"}', style: const TextStyle(fontSize: 11)),
                      Text('• Bank Balance: ${_extractionResult?['extractedBankBalance'] ?? "Not found"} ${_extractionResult?['extractedBankCurrency'] ?? ""}', style: const TextStyle(fontSize: 11)),
                      Text('• Bank Country: ${_extractionResult?['extractedBankCountry'] ?? "Not found"}', style: const TextStyle(fontSize: 11)),
                      if (_extractionResult?['idImagePreviewBase64'] != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            base64.decode(_extractionResult?['idImagePreviewBase64'].toString().split(',').last ?? ''),
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      if (_extractionResult?['warnings'] != null && List.from(_extractionResult?['warnings']).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Warnings:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                              ...List<String>.from(_extractionResult?['warnings']).map((w) => Text('• $w', style: const TextStyle(fontSize: 10, color: Colors.orange))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              // Validation Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _validating ? null : _validateDocuments,
                  icon: _validating
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.verified_user_outlined, size: 18),
                  label: const Text('Validate Documents'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_submitting || _validating) ? null : _submitApplication,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB45309),
          ),
          child: _submitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Application'),
        ),
      ],
    );
  }
}

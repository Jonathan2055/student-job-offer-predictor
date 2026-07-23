import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const JobOfferPredictorApp());

class JobOfferPredictorApp extends StatelessWidget {
  const JobOfferPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Offer Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B5BFD),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: const PredictorPage(),
    );
  }
}

class PredictorPage extends StatefulWidget {
  const PredictorPage({super.key});

  @override
  State<PredictorPage> createState() => _PredictorPageState();
}

class _PredictorPageState extends State<PredictorPage> {
  final _formKey = GlobalKey<FormState>();

  // The api for the deployed model.
  static const String apiBaseUrl = 'http://10.0.2.2:8000'; 

  // Controllers for numeric text fields
  final _highSchoolGpaCtrl = TextEditingController();
  final _satScoreCtrl = TextEditingController();
  final _universityGpaCtrl = TextEditingController();
  final _internshipsCtrl = TextEditingController();
  final _projectsCtrl = TextEditingController();
  final _certificationsCtrl = TextEditingController();
  final _softSkillsCtrl = TextEditingController();

  String _gender = 'Male';
  String _fieldOfStudy = 'Computer Science';

  bool _loading = false;
  String? _errorMessage;
  double? _predictedOffers;
  int? _roundedOffers;

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _fields = [
    'Arts', 'Business', 'Computer Science', 'Education', 'Engineering',
    'Finance', 'Law', 'Marketing', 'Medicine', 'Nursing', 'Psychology',
  ];

  @override
  void dispose() {
    _highSchoolGpaCtrl.dispose();
    _satScoreCtrl.dispose();
    _universityGpaCtrl.dispose();
    _internshipsCtrl.dispose();
    _projectsCtrl.dispose();
    _certificationsCtrl.dispose();
    _softSkillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    setState(() {
      _errorMessage = null;
      _predictedOffers = null;
      _roundedOffers = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final payload = {
      'gender': _gender,
      'high_school_gpa': double.parse(_highSchoolGpaCtrl.text),
      'sat_score': int.parse(_satScoreCtrl.text),
      'university_gpa': double.parse(_universityGpaCtrl.text),
      'internships_completed': int.parse(_internshipsCtrl.text),
      'projects_completed': int.parse(_projectsCtrl.text),
      'certifications': int.parse(_certificationsCtrl.text),
      'soft_skills_score': double.parse(_softSkillsCtrl.text),
      'field_of_study': _fieldOfStudy,
    };

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _predictedOffers = (data['predicted_job_offers'] as num).toDouble();
          _roundedOffers = data['rounded_job_offers'] as int;
        });
      } else {
        // Handles both 422 (validation errors from Pydantic) and 500 (server errors)
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = _formatApiError(data);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not reach the server. Check your connection and API URL.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatApiError(dynamic data) {
    if (data is Map && data['detail'] is List) {
      // FastAPI/Pydantic validation error format
      final firstError = data['detail'][0];
      final field = (firstError['loc'] as List).last;
      final msg = firstError['msg'];
      return '$field: $msg';
    } else if (data is Map && data['detail'] is String) {
      return data['detail'];
    }
    return 'Prediction failed. Please check your inputs.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Offer Predictor'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Estimate your expected number of job offers based on your '
                  'academic and extracurricular profile.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 20),

                _SectionCard(
                  title: 'Background',
                  icon: Icons.person_outline,
                  children: [
                    _buildDropdown(
                      label: 'Gender',
                      value: _gender,
                      items: _genders,
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Field of Study',
                      value: _fieldOfStudy,
                      items: _fields,
                      onChanged: (v) => setState(() => _fieldOfStudy = v!),
                    ),
                  ],
                ),

                _SectionCard(
                  title: 'Academic Performance',
                  icon: Icons.school_outlined,
                  children: [
                    _buildNumberField(
                      controller: _highSchoolGpaCtrl,
                      label: 'High School GPA',
                      hint: '0 - 4.0',
                      isDecimal: true,
                      min: 0,
                      max: 4.0,
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: _satScoreCtrl,
                      label: 'SAT Score',
                      hint: '400 - 1600',
                      isDecimal: false,
                      min: 400,
                      max: 1600,
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: _universityGpaCtrl,
                      label: 'University GPA',
                      hint: '0 - 4.0',
                      isDecimal: true,
                      min: 0,
                      max: 4.0,
                    ),
                  ],
                ),

                _SectionCard(
                  title: 'Experience & Skills',
                  icon: Icons.workspace_premium_outlined,
                  children: [
                    _buildNumberField(
                      controller: _internshipsCtrl,
                      label: 'Internships Completed',
                      hint: '0 - 4',
                      isDecimal: false,
                      min: 0,
                      max: 4,
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: _projectsCtrl,
                      label: 'Projects Completed',
                      hint: '0 - 9',
                      isDecimal: false,
                      min: 0,
                      max: 9,
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: _certificationsCtrl,
                      label: 'Certifications',
                      hint: '0 - 5',
                      isDecimal: false,
                      min: 0,
                      max: 5,
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: _softSkillsCtrl,
                      label: 'Soft Skills Score',
                      hint: '1 - 10',
                      isDecimal: true,
                      min: 1,
                      max: 10,
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _predict,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Predict', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) _buildErrorCard(),
                if (_predictedOffers != null) _buildResultCard(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDecimal,
    required num min,
    required num max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        final parsed = num.tryParse(value);
        if (parsed == null) {
          return 'Enter a valid number';
        }
        if (parsed < min || parsed > max) {
          return 'Must be between $min and $max';
        }
        return null;
      },
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Predicted Job Offers',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '$_roundedOffers',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Raw model output: ${_predictedOffers!.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
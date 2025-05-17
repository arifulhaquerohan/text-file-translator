import 'dart:convert'; // For jsonEncode and utf8.encode
import 'dart:typed_data'; // For Uint8List

import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:file_picker/file_picker.dart' as picker;
import 'package:file_selector/file_selector.dart'; // For XFile, XTypeGroup, openFile
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException AND Clipboard
import 'package:flutter_tts/flutter_tts.dart'; // For Text-to-Speech
import 'package:google_fonts/google_fonts.dart'; // For Custom Fonts
import 'package:http/http.dart' as http; // Import with 'as http'
import 'package:provider/provider.dart'; // For accessing ThemeNotifier
import 'package:share_plus/share_plus.dart'; // For Share Functionality
import 'package:shimmer/shimmer.dart'; // For Shimmer Effect
// Ensure your ThemeNotifier is correctly imported if it's in a separate file
// For example, if it's in main.dart, and your project is 'text_file_translator':
import 'package:text_file_translator/main.dart';

// IMPORTANT SECURITY NOTE:
// The API key is hardcoded below. This is a SIGNIFICANT SECURITY RISK.
// PLEASE USE A SECURE METHOD like environment variables.

// --- Helper class for Language ---
// Ensure this class definition is exactly as follows:
class Language {
  final String code;
  final String name;

  Language({required this.code, required this.name});

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      code: json['language'] as String, // Added 'as String' for type safety
      name: (json['name'] ?? json['language']) as String, // Added 'as String'
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

// --- Helper class for Translation History ---
// Ensure this class definition is exactly as follows:
class TranslationHistoryEntry {
  final String originalText;
  final String translatedText;
  final Language sourceLanguage;
  final Language targetLanguage;
  final DateTime timestamp;

  TranslationHistoryEntry({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });
}

class FileTranslatorPage extends StatefulWidget {
  const FileTranslatorPage({Key? key}) : super(key: key);

  @override
  _FileTranslatorPageState createState() => _FileTranslatorPageState();
}

class _FileTranslatorPageState extends State<FileTranslatorPage> {
  // TODO: SECURE THIS API KEY! Replace with a secure method like flutter_dotenv.
  final String _googleTranslateApiKey =
      'AIzaSyAMXR-FYq11iXmboOtoVAysZZfo0EWr0HM';

  final List<String> _apiKeyPlaceholders = const [
    'YOUR_API_KEY',
    'YOUR_API_KEY_NOT_FOUND_IN_ENV',
    'YOUR_API_KEY_PLACEHOLDER',
    '',
  ];

  final TextEditingController _originalTextController = TextEditingController();
  final TextEditingController _translatedTextController =
      TextEditingController();
  String _fileName = '';
  String _errorMessage = '';

  List<Language> _allSupportedLanguages = [];
  Language? _selectedSourceLanguage;
  Language? _detectedSourceLanguage;
  Language? _selectedTargetLanguage;
  Language? _defaultTargetLanguage;

  bool _isLoadingLanguages = true;
  bool _isLoadingTranslation = false;
  bool _isDetectingLanguage = false;
  bool _isSavingFile = false;

  List<TranslationHistoryEntry> _history = [];

  FlutterTts _flutterTts = FlutterTts();
  bool _isSpeakingOriginal = false;
  bool _isSpeakingTranslated = false;

  ThemeData get theme => Theme.of(context);
  // TextTheme will be inherited from MaterialApp if defined there with GoogleFonts
  TextTheme get textTheme => Theme.of(context).textTheme;
  ColorScheme get colorScheme => theme.colorScheme;

  bool _isApiKeyConfigured() {
    return !_apiKeyPlaceholders.contains(_googleTranslateApiKey);
  }

  @override
  void initState() {
    super.initState();
    _initializeTts();
    if (!_isApiKeyConfigured()) {
      _errorMessage =
          "API Key is not configured correctly. Features will be limited.";
      _isLoadingLanguages = false;
    } else {
      _fetchSupportedLanguages();
    }
  }

  Future<void> _initializeTts() async {
    _flutterTts.setCompletionHandler(() {
      if (mounted)
        setState(() {
          _isSpeakingOriginal = false;
          _isSpeakingTranslated = false;
        });
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeakingOriginal = false;
          _isSpeakingTranslated = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("TTS Error: $msg", style: textTheme.bodySmall),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _originalTextController.dispose();
    _translatedTextController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _fetchSupportedLanguages() async {
    if (!_isApiKeyConfigured()) {
      if (mounted)
        setState(() {
          _errorMessage = 'API Key not configured. Cannot fetch languages.';
          _isLoadingLanguages = false;
        });
      return;
    }
    if (mounted) setState(() => _isLoadingLanguages = true);
    try {
      // Ensure http calls use the 'http.' prefix
      final response = await http.get(
        Uri.parse(
          'https://translation.googleapis.com/language/translate/v2/languages?key=$_googleTranslateApiKey&target=en',
        ),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> languagesJson = data['data']['languages'];
        setState(() {
          _allSupportedLanguages =
              languagesJson
                  .map(
                    (langJson) =>
                        Language.fromJson(langJson as Map<String, dynamic>),
                  )
                  .toList(); // Added cast
          _allSupportedLanguages.sort((a, b) => a.name.compareTo(b.name));
          _allSupportedLanguages.insert(
            0,
            Language(code: 'und', name: 'Detect Language'),
          );
          _selectedSourceLanguage =
              _allSupportedLanguages.firstWhereOrNull(
                (lang) => lang.code == 'und',
              ) ??
              (_allSupportedLanguages.isNotEmpty
                  ? _allSupportedLanguages.first
                  : null);
          _defaultTargetLanguage =
              _allSupportedLanguages.firstWhereOrNull(
                (lang) => lang.code == 'en' && lang.code != 'und',
              ) ??
              _allSupportedLanguages.firstWhereOrNull(
                (lang) => lang.code != 'und',
              );
          _selectedTargetLanguage = _defaultTargetLanguage;
          _isLoadingLanguages = false;
        });
      } else {
        if (mounted)
          setState(() {
            _errorMessage =
                'Failed to load languages: ${response.statusCode} ${response.reasonPhrase}.';
            _isLoadingLanguages = false;
          });
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted)
        setState(() {
          _errorMessage = 'Error fetching languages: $e';
          _isLoadingLanguages = false;
        });
    }
  }

  Future<void> _pickFile() async {
    if (mounted) {
      setState(() {
        _errorMessage = '';
        _fileName = '';
        _originalTextController.clear();
        _translatedTextController.clear();
        _detectedSourceLanguage = null;
        if (_allSupportedLanguages.isNotEmpty) {
          _selectedSourceLanguage =
              _allSupportedLanguages.firstWhereOrNull(
                (lang) => lang.code == 'und',
              ) ??
              _allSupportedLanguages.first;
        } else {
          _selectedSourceLanguage = null;
        }
      });
    }
    try {
      // XTypeGroup and XFile come from file_selector package
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Text Files',
        extensions: <String>['txt'],
      );
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      ); // openFile from file_selector
      if (file != null) {
        final String content = await file.readAsString();
        if (!mounted) return;
        setState(() {
          _originalTextController.text = content;
          _fileName = file.name;
          if (_selectedSourceLanguage?.code == 'und' && content.isNotEmpty)
            _detectLanguage(content);
        });
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file selected.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } on PlatformException catch (e) {
      if (mounted)
        setState(
          () =>
              _errorMessage =
                  'File picking error: ${e.message ?? e.toString()}',
        );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error picking file: $e');
    }
  }

  Future<void> _detectLanguage(String text) async {
    if (text.isEmpty) {
      if (mounted) setState(() => _isDetectingLanguage = false);
      return;
    }
    if (!_isApiKeyConfigured()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API Key not configured for language detection.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isDetectingLanguage = false);
      }
      return;
    }
    if (mounted)
      setState(() {
        _isDetectingLanguage = true;
        _errorMessage = '';
      });
    try {
      // Ensure http calls use the 'http.' prefix
      final response = await http.post(
        Uri.parse(
          'https://translation.googleapis.com/language/translate/v2/detect?key=$_googleTranslateApiKey',
        ),
        body: {'q': text},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']?['detections'] != null &&
            data['data']['detections'].isNotEmpty &&
            data['data']['detections'][0].isNotEmpty) {
          final String languageCode =
              data['data']['detections'][0][0]['language'];
          final detectedLang = _allSupportedLanguages.firstWhereOrNull(
            (lang) => lang.code == languageCode,
          );
          if (mounted)
            setState(() {
              _detectedSourceLanguage =
                  detectedLang ??
                  Language(
                    code: languageCode,
                    name: "${languageCode.toUpperCase()} (Unknown)",
                  );
              _isDetectingLanguage = false;
            });
        } else {
          if (mounted)
            setState(() {
              _errorMessage =
                  'Language detection failed: Could not parse detection from API.';
              _isDetectingLanguage = false;
            });
        }
      } else {
        if (mounted)
          setState(() {
            _errorMessage =
                'Language detection failed: ${response.statusCode} ${response.reasonPhrase}.';
            _isDetectingLanguage = false;
          });
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted)
        setState(() {
          _errorMessage = 'Error detecting language: $e';
          _isDetectingLanguage = false;
        });
    }
  }

  Future<void> _translateText() async {
    final String originalText = _originalTextController.text;
    if (originalText.isEmpty ||
        _selectedTargetLanguage == null ||
        _selectedTargetLanguage!.code == 'und' ||
        !_isApiKeyConfigured()) {
      if (!_isApiKeyConfigured() && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API Key not configured for translation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      else if (originalText.isEmpty && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text to translate.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      else if ((_selectedTargetLanguage == null ||
              _selectedTargetLanguage!.code == 'und') &&
          mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid target language.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      if (mounted) setState(() => _isLoadingTranslation = false);
      return;
    }

    Language? effectiveSourceLang =
        _selectedSourceLanguage?.code == 'und'
            ? _detectedSourceLanguage
            : _selectedSourceLanguage;
    if (effectiveSourceLang == null || effectiveSourceLang.code == 'und') {
      if (_selectedSourceLanguage?.code == 'und' &&
          originalText.isNotEmpty &&
          _detectedSourceLanguage == null) {
        await _detectLanguage(originalText);
        effectiveSourceLang = _detectedSourceLanguage;
        if (effectiveSourceLang == null || effectiveSourceLang.code == 'und') {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not determine source language. Try selecting manually.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          if (mounted) setState(() => _isLoadingTranslation = false);
          return;
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select or detect a valid source language.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        if (mounted) setState(() => _isLoadingTranslation = false);
        return;
      }
    }
    final String sourceLangCode = effectiveSourceLang.code;
    final Language sourceLanguageForHistory = effectiveSourceLang;

    if (mounted)
      setState(() {
        _isLoadingTranslation = true;
        _translatedTextController.clear();
        _errorMessage = '';
      });

    try {
      // Ensure http calls use the 'http.' prefix
      final response = await http.post(
        Uri.parse(
          'https://translation.googleapis.com/language/translate/v2?key=$_googleTranslateApiKey',
        ),
        body: {
          'q': originalText,
          'source': sourceLangCode,
          'target': _selectedTargetLanguage!.code,
          'format': 'text',
        },
      );
      if (!mounted) {
        _isLoadingTranslation = false;
        return;
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String translatedText =
            data['data']['translations'][0]['translatedText'];
        if (mounted)
          setState(() {
            _translatedTextController.text = translatedText;
            _history.insert(
              0,
              TranslationHistoryEntry(
                originalText: originalText,
                translatedText: translatedText,
                sourceLanguage: sourceLanguageForHistory,
                targetLanguage: _selectedTargetLanguage!,
                timestamp: DateTime.now(),
              ),
            );
          });
      } else {
        if (mounted)
          setState(
            () =>
                _errorMessage =
                    'Translation failed: ${response.statusCode} ${response.reasonPhrase}.',
          );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error translating text: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTranslation = false);
    }
  }

  Future<void> _saveTranslatedFile() async {
    String translatedText = _translatedTextController.text;
    if (translatedText.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No translated text to save.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (mounted)
      setState(() {
        _isSavingFile = true;
        _errorMessage = '';
      });
    try {
      String defaultFileName =
          _fileName.isNotEmpty
              ? '${_fileName.split('.').first}_translated_to_${_selectedTargetLanguage?.code ?? "target"}.txt'
              : 'translated_text_to_${_selectedTargetLanguage?.code ?? "target"}.txt';
      // file_picker aliased as 'picker'
      String? outputPath = await picker.FilePicker.platform.saveFile(
        dialogTitle: 'Save As:',
        fileName: defaultFileName,
        type: picker.FileType.custom,
        allowedExtensions: ['txt'],
        bytes: Uint8List.fromList(utf8.encode(translatedText)),
      );
      if (!mounted) return;
      if (outputPath != null ||
          picker.FilePicker.platform.toString().contains('web')) {
        // Check for web platform
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                picker.FilePicker.platform.toString().contains('web')
                    ? 'Download for $defaultFileName initiated.'
                    : 'Saving to $defaultFileName initiated.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        if (_errorMessage == "No translated text to save.") _errorMessage = '';
      } else {
        if (_isSavingFile && mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File save canceled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (mounted) _errorMessage = 'Error saving file: $e';
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSavingFile = false);
    }
  }

  void _copyToClipboard(String text, String fieldName) {
    if (text.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No $fieldName text to copy.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fieldName text copied!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  void _swapLanguages() {
    if (_selectedSourceLanguage == null ||
        _selectedTargetLanguage == null ||
        !_isApiKeyConfigured())
      return;
    final Language? tempSource = _selectedSourceLanguage;
    final Language? newSource = _selectedTargetLanguage;
    final Language? newTarget = tempSource;
    setState(() {
      _selectedSourceLanguage = newSource;
      _selectedTargetLanguage = newTarget;
      if (_selectedTargetLanguage?.code == 'und')
        _selectedTargetLanguage =
            _defaultTargetLanguage ??
            _allSupportedLanguages.firstWhereOrNull(
              (l) => l.code == 'en' && l.code != 'und',
            ) ??
            _allSupportedLanguages.firstWhereOrNull((l) => l.code != 'und');
      _detectedSourceLanguage = null;
      if (_selectedSourceLanguage?.code == 'und' &&
          _originalTextController.text.isNotEmpty)
        _detectLanguage(_originalTextController.text);
      if (_originalTextController.text.isNotEmpty &&
          _translatedTextController.text.isNotEmpty)
        _translateText();
    });
  }

  Future<void> _speak(
    String text,
    String langCode, {
    required bool isOriginalText,
  }) async {
    if (text.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to speak.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    bool currentlySpeakingThis =
        (isOriginalText && _isSpeakingOriginal) ||
        (!isOriginalText && _isSpeakingTranslated);
    await _flutterTts.stop();
    if (currentlySpeakingThis) {
      if (mounted)
        setState(() {
          _isSpeakingOriginal = false;
          _isSpeakingTranslated = false;
        });
      return;
    }

    try {
      String ttsLangCode = langCode;
      // Basic attempt to make langCode more specific for TTS (e.g., 'en' to 'en-US')
      // This might need to be more robust based on available TTS languages
      if (langCode.length == 2) {
        final List<dynamic>? languages = await _flutterTts.getLanguages;
        if (languages != null) {
          final foundLang = languages.firstWhereOrNull(
            (l) => l.toString().toLowerCase().startsWith(
              langCode.toLowerCase() + "-",
            ),
          );
          if (foundLang != null) ttsLangCode = foundLang.toString();
        }
      }
      await _flutterTts.setLanguage(ttsLangCode);
      if (mounted) {
        setState(() {
          if (isOriginalText) {
            _isSpeakingOriginal = true;
            _isSpeakingTranslated = false;
          } else {
            _isSpeakingTranslated = true;
            _isSpeakingOriginal = false;
          }
        });
      }
      await _flutterTts.speak(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("TTS Error: $e"),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isSpeakingOriginal = false;
          _isSpeakingTranslated = false;
        });
      }
    }
  }

  void _shareText(String text, String subject) {
    if (text.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to share.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    Share.share(text, subject: subject); // From share_plus package
  }

  // --- UI Helper Widgets ---
  Widget _buildInfoMessage({
    String? message,
    bool isError = true,
    IconData? icon,
  }) {
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: BoxDecoration(
        color:
            isError
                ? colorScheme.errorContainer.withOpacity(0.8)
                : colorScheme.tertiaryContainer.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isError ? colorScheme.error : colorScheme.tertiary,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon ??
                (isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded),
            color:
                isError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onTertiaryContainer,
            size: 20,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color:
                    isError
                        ? colorScheme.onErrorContainer
                        : colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerPlaceholder({int minLines = 5}) {
    return Shimmer.fromColors(
      // From shimmer package
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            minLines,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == minLines - 1 ? 0 : 10.0,
              ),
              child: Container(
                height: 14.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        title,
        style: textTheme.titleLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCardSection({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: colorScheme.surfaceVariant.withOpacity(
        0.3,
      ), // Updated for better theme adaptability
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildFilePickerSection() {
    return _buildCardSection(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '1. Select Your Text File',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed:
                _isLoadingLanguages ||
                        _isLoadingTranslation ||
                        _isSavingFile ||
                        _isDetectingLanguage
                    ? null
                    : _pickFile,
            icon: Icon(Icons.attach_file_rounded, color: colorScheme.onPrimary),
            label: Text(
              'Pick .txt File',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ), // Using labelLarge for button text
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
          if (_fileName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Selected: $_fileName',
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required String label,
    required Language? selectedLanguage,
    required List<Language> languages,
    required ValueChanged<Language?> onChanged,
    bool isSource = false,
  }) {
    String displayLabel = label;
    if (isSource) {
      if (_isDetectingLanguage)
        displayLabel = 'From: Detecting...';
      else if (selectedLanguage?.code == 'und' &&
          _detectedSourceLanguage != null)
        displayLabel = 'From: ${_detectedSourceLanguage!.name} (Detected)';
      else if (selectedLanguage?.code == 'und')
        displayLabel = 'From: Detect Language';
      else if (selectedLanguage != null)
        displayLabel = 'From: ${selectedLanguage.name}';
    } else {
      displayLabel = 'To: ${selectedLanguage?.name ?? 'Select Target'}';
    }

    return DropdownButtonFormField<Language>(
      decoration: InputDecoration(
        labelText: displayLabel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        filled: true,
        fillColor: colorScheme.surface.withOpacity(0.9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
      ),
      isExpanded: true,
      value: selectedLanguage,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      items:
          languages
              .map<DropdownMenuItem<Language>>(
                (Language lang) => DropdownMenuItem<Language>(
                  value: lang,
                  child: Text(lang.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged:
          _isLoadingLanguages ||
                  _isLoadingTranslation ||
                  _isDetectingLanguage ||
                  languages.isEmpty
              ? null
              : onChanged,
      validator:
          (value) =>
              (!isSource && (value == null || value.code == 'und'))
                  ? 'Please select a target language.'
                  : null,
    );
  }

  Widget _buildTranslationControlsSection() {
    return _buildCardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '2. Configure & Translate',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_isLoadingLanguages && _isApiKeyConfigured())
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_allSupportedLanguages.isEmpty &&
              _isApiKeyConfigured() &&
              _errorMessage.isNotEmpty)
            _buildInfoMessage(
              message: 'Could not load languages. $_errorMessage',
              isError: true,
            )
          else if (_allSupportedLanguages.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildLanguageDropdown(
                    label: 'From:',
                    selectedLanguage: _selectedSourceLanguage,
                    languages: _allSupportedLanguages,
                    isSource: true,
                    onChanged: (Language? newValue) {
                      if (newValue != null && mounted)
                        setState(() {
                          _selectedSourceLanguage = newValue;
                          if (newValue.code == 'und' &&
                              _originalTextController.text.isNotEmpty)
                            _detectLanguage(_originalTextController.text);
                          else if (newValue.code != 'und')
                            _detectedSourceLanguage = null;
                        });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.swap_horiz_rounded,
                      color: colorScheme.primary,
                      size: 30,
                    ),
                    tooltip: 'Swap Languages',
                    onPressed:
                        _isLoadingLanguages ||
                                _isLoadingTranslation ||
                                _isDetectingLanguage ||
                                !_isApiKeyConfigured() ||
                                _allSupportedLanguages.length < 2
                            ? null
                            : _swapLanguages,
                  ),
                ),
                Expanded(
                  child: _buildLanguageDropdown(
                    label: 'To:',
                    selectedLanguage: _selectedTargetLanguage,
                    languages:
                        _allSupportedLanguages
                            .where((lang) => lang.code != 'und')
                            .toList(),
                    onChanged: (Language? newValue) {
                      if (newValue != null && mounted)
                        setState(() => _selectedTargetLanguage = newValue);
                    },
                  ),
                ),
              ],
            )
          else if (!_isApiKeyConfigured())
            const SizedBox.shrink()
          else
            const SizedBox.shrink(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed:
                !_isApiKeyConfigured() ||
                        _isLoadingTranslation ||
                        _isLoadingLanguages ||
                        _isSavingFile ||
                        _isDetectingLanguage ||
                        _originalTextController.text.isEmpty ||
                        _selectedTargetLanguage == null ||
                        _selectedTargetLanguage!.code == 'und' ||
                        _allSupportedLanguages.isEmpty
                    ? null
                    : _translateText,
            icon:
                _isLoadingTranslation
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                    : Icon(
                      Icons.translate_rounded,
                      color: colorScheme.onPrimary,
                    ),
            label: Text(
              _isLoadingTranslation ? 'Translating...' : 'Translate Text',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldSection(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    int minLines = 5,
    int maxLines = 10,
    String hintText = '',
    required String copyLabelForSnackbar,
  }) {
    bool isOriginalField = label.contains("Original");
    String currentText = controller.text;
    Language? currentLang =
        isOriginalField
            ? (_selectedSourceLanguage?.code == 'und'
                ? _detectedSourceLanguage
                : _selectedSourceLanguage)
            : _selectedTargetLanguage;

    return _buildCardSection(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isApiKeyConfigured() &&
                      currentText.isNotEmpty &&
                      currentLang != null &&
                      currentLang.code != 'und')
                    IconButton(
                      icon: Icon(
                        (isOriginalField
                                ? _isSpeakingOriginal
                                : _isSpeakingTranslated)
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_rounded,
                        color: colorScheme.secondary,
                        size: 22,
                      ),
                      tooltip:
                          (isOriginalField
                                  ? _isSpeakingOriginal
                                  : _isSpeakingTranslated)
                              ? 'Stop speaking'
                              : 'Speak ${copyLabelForSnackbar.toLowerCase()}',
                      onPressed:
                          () => _speak(
                            currentText,
                            currentLang.code,
                            isOriginalText: isOriginalField,
                          ),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.copy_all_rounded,
                      color: colorScheme.secondary,
                      size: 22,
                    ),
                    tooltip: 'Copy ${copyLabelForSnackbar.toLowerCase()}',
                    onPressed:
                        () =>
                            _copyToClipboard(currentText, copyLabelForSnackbar),
                  ),
                  if (!isOriginalField &&
                      _isApiKeyConfigured() &&
                      currentText.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.share_rounded,
                        color: colorScheme.secondary,
                        size: 22,
                      ),
                      tooltip: 'Share translated text',
                      onPressed:
                          () => _shareText(
                            currentText,
                            'Translated Text from App',
                          ),
                    ), // Use 'App name' or similar for subject
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (label.contains("Translated") && _isLoadingTranslation)
            _buildShimmerPlaceholder(minLines: minLines)
          else
            TextField(
              controller: controller,
              readOnly: readOnly,
              minLines: minLines,
              maxLines: maxLines,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[500],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.all(14.0),
                suffixIcon:
                    (!readOnly && controller == _originalTextController)
                        ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Colors.grey[600],
                          ),
                          tooltip: 'Clear text',
                          onPressed: () {
                            if (mounted)
                              setState(() {
                                _originalTextController.clear();
                                _translatedTextController.clear();
                                if (_selectedSourceLanguage?.code == 'und')
                                  _detectedSourceLanguage = null;
                              });
                          },
                        )
                        : null,
              ),
              onChanged: (text) {
                if (!readOnly && controller == _originalTextController) {
                  if (_selectedSourceLanguage?.code == 'und' &&
                      text.isNotEmpty) {
                    if (_isApiKeyConfigured()) _detectLanguage(text);
                  } else if (text.isEmpty && mounted)
                    setState(() => _detectedSourceLanguage = null);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryEntryCard(TranslationHistoryEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.sourceLanguage.name} → ${entry.targetLanguage.name}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Original:',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            Text(
              entry.originalText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Translated:',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            Text(
              entry.translatedText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${entry.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${entry.timestamp.toLocal().minute.toString().padLeft(2, '0')} - ${entry.timestamp.toLocal().day.toString().padLeft(2, '0')}/${entry.timestamp.toLocal().month.toString().padLeft(2, '0')}/${entry.timestamp.toLocal().year}',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(
      context,
    ); // Access ThemeNotifier
    final Brightness platformBrightness = MediaQuery.platformBrightnessOf(
      context,
    );
    final bool isEffectivelyDarkMode =
        themeNotifier.currentThemeMode == ThemeMode.dark ||
        (themeNotifier.currentThemeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Text File Translator',
          style: textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ), // Adjusted color for better theme adaptability
        centerTitle: true,
        elevation: 0, // Flatter look
        backgroundColor: Colors.transparent, // Use scaffold background
        foregroundColor:
            colorScheme.onSurface, // For back button and other icons
        actions: [
          IconButton(
            icon: Icon(
              isEffectivelyDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              themeNotifier.toggleTheme(isEffectivelyDarkMode);
            },
          ),
        ],
      ),
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!_isApiKeyConfigured())
                _buildInfoMessage(
                  message:
                      _errorMessage.isNotEmpty
                          ? _errorMessage
                          : "API Key is not configured. Translation features are disabled.",
                  isError: true,
                  icon: Icons.key_off_rounded,
                ),
              _buildFilePickerSection(),
              _buildTranslationControlsSection(),
              _buildTextFieldSection(
                'Original Text:',
                _originalTextController,
                hintText: 'File content or type text here...',
                minLines: 6,
                maxLines: 12,
                copyLabelForSnackbar: 'Original',
              ),
              _buildTextFieldSection(
                'Translated Text:',
                _translatedTextController,
                readOnly: true,
                hintText: 'Translation will appear here...',
                minLines: 6,
                maxLines: 12,
                copyLabelForSnackbar: 'Translated',
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed:
                    !_isApiKeyConfigured() ||
                            _translatedTextController.text.isEmpty ||
                            _isLoadingTranslation ||
                            _isLoadingLanguages ||
                            _isSavingFile ||
                            _isDetectingLanguage
                        ? null
                        : _saveTranslatedFile,
                icon:
                    _isSavingFile
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onSecondary,
                          ),
                        )
                        : Icon(
                          Icons.download_done_rounded,
                          color: colorScheme.onSecondary,
                        ),
                label: Text(
                  _isSavingFile ? 'Saving...' : 'Download Translated File',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSecondary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              if (_errorMessage.isNotEmpty &&
                  _isApiKeyConfigured() &&
                  !_isLoadingLanguages &&
                  !_isLoadingTranslation)
                _buildInfoMessage(message: _errorMessage, isError: true),
              const SizedBox(height: 24),
              _buildSectionTitle('Recent Translations (Last 5)'),
              if (_history.isEmpty)
                _buildInfoMessage(
                  message:
                      _isApiKeyConfigured()
                          ? 'No translation history yet. Start translating!'
                          : 'History unavailable (API Key not configured).',
                  isError: !_isApiKeyConfigured(),
                  icon:
                      _isApiKeyConfigured()
                          ? Icons.history_toggle_off_rounded
                          : Icons.key_off_rounded,
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _history.length > 5 ? 5 : _history.length,
                  itemBuilder:
                      (context, index) =>
                          _buildHistoryEntryCard(_history[index]),
                ),
              const SizedBox(height: 32),
              Text(
                'Developed by Rohan',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

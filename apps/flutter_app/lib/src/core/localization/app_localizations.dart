import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

enum AppLanguage {
  english('en', 'English', 'English'),
  kannada('kn', 'Kannada', 'ಕನ್ನಡ'),
  hindi('hi', 'Hindi', 'हिन्दी');

  const AppLanguage(this.code, this.englishName, this.nativeName);

  final String code;
  final String englishName;
  final String nativeName;

  Locale get locale => Locale(code);
}

class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  static const Map<String, Map<AppLanguage, String>> _localizedValues = {
    // App & Header
    'appName': {
      AppLanguage.english: 'Schoolic',
      AppLanguage.kannada: 'ಸ್ಕೂಲಿಕ್',
      AppLanguage.hindi: 'स्कूलिक',
    },
    'schoolManagement': {
      AppLanguage.english: 'School Management & Academics',
      AppLanguage.kannada: 'ಶಾಲಾ ನಿರ್ವಹಣೆ ಮತ್ತು ಶೈಕ್ಷಣಿಕ',
      AppLanguage.hindi: 'स्कूल प्रबंधन और शैक्षणिक',
    },
    'welcome': {
      AppLanguage.english: 'Welcome',
      AppLanguage.kannada: 'ಸ್ವಾಗತ',
      AppLanguage.hindi: 'स्वागत है',
    },
    'changeLanguage': {
      AppLanguage.english: 'Language',
      AppLanguage.kannada: 'ಭಾಷೆ',
      AppLanguage.hindi: 'भाषा',
    },

    // Navigation
    'overview': {
      AppLanguage.english: 'Overview',
      AppLanguage.kannada: 'ಅವಲೋಕನ',
      AppLanguage.hindi: 'अवलोकन',
    },
    'attendance': {
      AppLanguage.english: 'Attendance',
      AppLanguage.kannada: 'ಹಾಜರಾತಿ',
      AppLanguage.hindi: 'उपस्थिति',
    },
    'academics': {
      AppLanguage.english: 'Academics & Exams',
      AppLanguage.kannada: 'ಶೈಕ್ಷಣಿಕ ಮತ್ತು ಪರೀಕ್ಷೆಗಳು',
      AppLanguage.hindi: 'शैक्षणिक और परीक्षा',
    },
    'gradingSchemes': {
      AppLanguage.english: 'Grading Schemes',
      AppLanguage.kannada: 'ಶ್ರೇಣೀಕರಣ ವ್ಯವಸ್ಥೆಗಳು',
      AppLanguage.hindi: 'ग्रेडिंग योजनाएं',
    },
    'reportCards': {
      AppLanguage.english: 'Report Cards',
      AppLanguage.kannada: 'ಪ್ರಗತಿ ಪತ್ರಗಳು',
      AppLanguage.hindi: 'प्रगति पत्र (रिपोर्ट कार्ड)',
    },
    'fees': {
      AppLanguage.english: 'Fees & Finance',
      AppLanguage.kannada: 'ಶುಲ್ಕ ಮತ್ತು ಹಣಕಾಸು',
      AppLanguage.hindi: 'शुल्क और वित्त',
    },
    'timetable': {
      AppLanguage.english: 'Timetable',
      AppLanguage.kannada: 'ವೇಳಾಪಟ್ಟಿ',
      AppLanguage.hindi: 'समय सारणी (टाइमटेबल)',
    },
    'operations': {
      AppLanguage.english: 'Operations & Fleet',
      AppLanguage.kannada: 'ಕಾರ್ಯಾಚರಣೆ ಮತ್ತು ಸಾರಿಗೆ',
      AppLanguage.hindi: 'संचालन और परिवहन',
    },
    'settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.kannada: 'ಸಂಯೋಜನೆಗಳು',
      AppLanguage.hindi: 'सेटिंग्स',
    },

    // Actions
    'save': {
      AppLanguage.english: 'Save',
      AppLanguage.kannada: 'ಉಳಿಸು',
      AppLanguage.hindi: 'सहेजें',
    },
    'cancel': {
      AppLanguage.english: 'Cancel',
      AppLanguage.kannada: 'ರದ್ದುಮಾಡು',
      AppLanguage.hindi: 'रद्द करें',
    },
    'filter': {
      AppLanguage.english: 'Filter',
      AppLanguage.kannada: 'ಶೋಧಿಸು',
      AppLanguage.hindi: 'फ़िल्टर',
    },
    'refresh': {
      AppLanguage.english: 'Refresh',
      AppLanguage.kannada: 'ನವೀಕರಿಸು',
      AppLanguage.hindi: 'रीफ्रेश',
    },
    'generate': {
      AppLanguage.english: 'Generate',
      AppLanguage.kannada: 'ರಚಿಸು',
      AppLanguage.hindi: 'उत्पन्न करें',
    },
    'print': {
      AppLanguage.english: 'Print',
      AppLanguage.kannada: 'ಮುದ್ರಿಸು',
      AppLanguage.hindi: 'प्रिंट करें',
    },
    'exportPdf': {
      AppLanguage.english: 'Export PDF',
      AppLanguage.kannada: 'ಪಿಡಿಎಫ್ ರಫ್ತು',
      AppLanguage.hindi: 'पीडीएफ निर्यात',
    },
    'sync': {
      AppLanguage.english: 'Synchronize',
      AppLanguage.kannada: 'ಸಿಂಕ್ ಮಾಡಿ',
      AppLanguage.hindi: 'सिंक करें',
    },
    'syncNow': {
      AppLanguage.english: 'Sync Now',
      AppLanguage.kannada: 'ಈಗಲೇ ಸಿಂಕ್ ಮಾಡಿ',
      AppLanguage.hindi: 'अभी सिंक करें',
    },

    // Attendance & Statuses
    'present': {
      AppLanguage.english: 'Present',
      AppLanguage.kannada: 'ಹಾಜರು',
      AppLanguage.hindi: 'उपस्थित',
    },
    'absent': {
      AppLanguage.english: 'Absent',
      AppLanguage.kannada: 'ಗೈರುಹಾಜರು',
      AppLanguage.hindi: 'अनुपस्थित',
    },
    'late': {
      AppLanguage.english: 'Late',
      AppLanguage.kannada: 'ತಡವಾಗಿ',
      AppLanguage.hindi: 'देरी से',
    },
    'excused': {
      AppLanguage.english: 'Excused',
      AppLanguage.kannada: 'ಕ್ಷಮಿಸಲಾಗಿದೆ',
      AppLanguage.hindi: 'स्वीकृत अवकाश',
    },
    'online': {
      AppLanguage.english: 'Online',
      AppLanguage.kannada: 'ಆನ್‌ಲೈನ್',
      AppLanguage.hindi: 'ऑनलाइन',
    },
    'offlineMode': {
      AppLanguage.english: 'Offline Mode',
      AppLanguage.kannada: 'ಆಫ್‌ಲೈನ್ ಮೋಡ್',
      AppLanguage.hindi: 'ऑफ़लाइन मोड',
    },
    'pendingSync': {
      AppLanguage.english: 'Pending Sync',
      AppLanguage.kannada: 'ಸಿಂಕ್ ಬಾಕಿ ಇದೆ',
      AppLanguage.hindi: 'सिंक लंबित',
    },

    // Academics & Report Cards
    'overallScore': {
      AppLanguage.english: 'Overall Score',
      AppLanguage.kannada: 'ಒಟ್ಟಾರೆ ಅಂಕ',
      AppLanguage.hindi: 'कुल प्राप्तांक',
    },
    'grade': {
      AppLanguage.english: 'Grade',
      AppLanguage.kannada: 'ಶ್ರೇಣಿ',
      AppLanguage.hindi: 'ग्रेड',
    },
    'gradePoint': {
      AppLanguage.english: 'Grade Point',
      AppLanguage.kannada: 'ಗ್ರೇಡ್ ಪಾಯಿಂಟ್',
      AppLanguage.hindi: 'ग्रेड पॉइंट',
    },
    'percentage': {
      AppLanguage.english: 'Percentage',
      AppLanguage.kannada: 'ಶೇಕಡಾವಾರು',
      AppLanguage.hindi: 'प्रतिशत',
    },
    'scholastic': {
      AppLanguage.english: 'Scholastic Performance',
      AppLanguage.kannada: 'ಪಾಂಡಿತ್ಯಪೂರ್ಣ ಪ್ರದರ್ಶನ',
      AppLanguage.hindi: 'शैक्षिक प्रदर्शन',
    },
    'coScholastic': {
      AppLanguage.english: 'Co-Scholastic Activities',
      AppLanguage.kannada: 'ಸಹ-ಪಠ್ಯ ಚಟುವಟಿಕೆಗಳು',
      AppLanguage.hindi: 'सह-शैक्षिक गतिविधियाँ',
    },
    'promoted': {
      AppLanguage.english: 'Promoted',
      AppLanguage.kannada: 'ತೇರ್ಗಡೆ ಹೊಂದಿದ್ದಾರೆ',
      AppLanguage.hindi: 'उत्तीर्ण एवं प्रोन्नत',
    },
    'passed': {
      AppLanguage.english: 'Passed',
      AppLanguage.kannada: 'ಪಾಸಾಗಿದ್ದಾರೆ',
      AppLanguage.hindi: 'उत्तीर्ण',
    },
    'compartment': {
      AppLanguage.english: 'Compartment',
      AppLanguage.kannada: 'ಪೂರಕ ಪರೀಕ್ಷೆ',
      AppLanguage.hindi: 'पूरक परीक्षा (कंपार्टमेंट)',
    },
    'failed': {
      AppLanguage.english: 'Needs Improvement',
      AppLanguage.kannada: 'ಸುಧಾರಣೆ ಅಗತ್ಯವಿದೆ',
      AppLanguage.hindi: 'सुधार की आवश्यकता',
    },
    'teacherRemarks': {
      AppLanguage.english: 'Teacher Remarks',
      AppLanguage.kannada: 'ಶಿಕ್ಷಕರ ಅಭಿಪ್ರಾಯ',
      AppLanguage.hindi: 'शिक्षक की टिप्पणी',
    },
    'attendancePercentage': {
      AppLanguage.english: 'Attendance Rate',
      AppLanguage.kannada: 'ಹಾಜರಾತಿ ದರ',
      AppLanguage.hindi: 'उपस्थिति दर',
    },
  };

  String text(String key) {
    final entry = _localizedValues[key];
    if (entry == null) return key;
    return entry[language] ?? entry[AppLanguage.english] ?? key;
  }
}

class AppLanguageNotifier extends Notifier<AppLanguage> {
  static const _storageKey = 'schoolic_app_language';

  @override
  AppLanguage build() {
    _loadSavedLanguage();
    return AppLanguage.english;
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_storageKey);
      if (code != null) {
        final match = AppLanguage.values.firstWhere(
          (lang) => lang.code == code,
          orElse: () => AppLanguage.english,
        );
        state = match;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, language.code);
    } catch (_) {}
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageNotifier, AppLanguage>(AppLanguageNotifier.new);

final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final lang = ref.watch(appLanguageProvider);
  return AppLocalizations(lang);
});

class LanguagePickerDropdown extends ConsumerWidget {
  const LanguagePickerDropdown({this.isCompact = false, super.key});

  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    if (isCompact) {
      return PopupMenuButton<AppLanguage>(
        tooltip: 'Change Language / ಭಾಷೆ / भाषा',
        initialValue: currentLang,
        icon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 16, color: AppColors.primaryText),
              const SizedBox(width: 4),
              Text(
                currentLang.nativeName,
                style: const TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
        onSelected: (lang) => ref.read(appLanguageProvider.notifier).setLanguage(lang),
        itemBuilder: (context) => AppLanguage.values.map((lang) {
          final isSelected = lang == currentLang;
          return PopupMenuItem<AppLanguage>(
            value: lang,
            child: Row(
              children: [
                Text(
                  lang.nativeName,
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? AppColors.accent : AppColors.primaryText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${lang.englishName})',
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16, color: AppColors.accent),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: currentLang,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
          onChanged: (lang) {
            if (lang != null) {
              ref.read(appLanguageProvider.notifier).setLanguage(lang);
            }
          },
          items: AppLanguage.values.map((lang) {
            return DropdownMenuItem<AppLanguage>(
              value: lang,
              child: Row(
                children: [
                  const Icon(Icons.language, size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    '${lang.nativeName} (${lang.englishName})',
                    style: const TextStyle(
                      fontFamily: 'Switzer',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

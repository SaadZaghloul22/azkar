import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../widgets/common.dart';

const appVersion = '2.0.2';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HeroCard(
            child: Column(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 44),
                const SizedBox(height: 8),
                const Text('أذكار المسلم',
                    style: TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                Text('الإصدار ${arNum(appVersion)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'تطبيق مجاني بالكامل وبدون إعلانات، يجمع أذكار اليوم والليلة والأدعية من القرآن الكريم والسنة الصحيحة، مع مسبحة إلكترونية ومواقيت الصلاة واتجاه القبلة، ويعمل دون اتصال بالإنترنت.',
                style: TextStyle(height: 1.8, fontSize: 15),
              ),
            ),
          ),
          const SectionTitle('مصادر المحتوى'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'نصوص الأذكار مأخوذة من كتاب «حصن المسلم» للشيخ سعيد بن علي القحطاني ومن كتب السنة (الصحيحين والسنن)، والآيات من المصحف الشريف. يُذكر مع كل ذكر مصدره. يُذكر فضل الذكر فقط عند وروده في حديث، مع تخريجه.\n\nإن وجدت خطأً في أي نص فنرجو إبلاغنا لتصحيحه.',
                style: TextStyle(height: 1.8, color: cs.onSurface.withValues(alpha: 0.8)),
              ),
            ),
          ),
          const SectionTitle('حساب المواقيت'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'تُحسب مواقيت الصلاة فلكيًا على جهازك باستخدام مكتبة Adhan المفتوحة المصدر، حسب طريقة الحساب التي تختارها.',
                style: TextStyle(height: 1.8, color: cs.onSurface.withValues(alpha: 0.8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const text = '''
آخر تحديث: نوفمبر ٢٠٢٦

تطبيق «أذكار المسلم» مجاني وبدون إعلانات، ولا يجمع أي بيانات شخصية ولا يرسلها إلى أي خادم.

١. البيانات المحفوظة على جهازك فقط
المفضلة، وأذكارك الخاصة، وعدّاد المسبحة وسجلها، والإعدادات — كلها تُحفظ داخل التطبيق على هاتفك، وتُحذف عند حذف التطبيق.

٢. الموقع
يُطلب إذن الموقع فقط إذا اخترت تحديد موقعك لحساب مواقيت الصلاة واتجاه القبلة. يُحفظ الموقع على جهازك ولا يُرسل لأي جهة. يمكنك رفض الإذن واستخدام باقي التطبيق.

٣. الإشعارات
تُستخدم لتذكيرك بالأذكار وأوقات الصلاة حسب ما تفعّله أنت، ويمكنك إيقافها في أي وقت.

٤. الظهور فوق التطبيقات
يُطلب هذا الإذن فقط عند تفعيل «الأذكار التلقائية»، ويُستخدم لعرض ذكر قصير فوق التطبيقات الأخرى. لا يقرأ التطبيق محتوى شاشتك أو التطبيقات الأخرى.

٥. الإنترنت
لا يحتاج التطبيق إلى الإنترنت لعمله. لا توجد أدوات تتبّع أو تحليلات أو إعلانات.

٦. المشاركة
عند مشاركة ذكر كصورة، تُنشأ الصورة على جهازك وتُرسل عبر التطبيق الذي تختاره أنت.

للتواصل بخصوص الخصوصية: عبر صفحة التطبيق على متجر Google Play.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(text, style: TextStyle(height: 1.9, fontSize: 15)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';
import 'ui.dart';
import 'icons.dart';

/// (titre FR, texte FR, titre AR, texte AR)
const _terms = [
  (
    '1. Objet',
    'Nqata Pro est l\'application destinée aux commerçants : elle permet de scanner les clients, de leur attribuer des points de fidélité, de gérer des offres et de suivre l\'activité du commerce.',
    '1. الهدف',
    'نقطة برو هو تطبيق موجّه للتجار: يتيح مسح رموز الزبائن ومنحهم نقاط الولاء وإدارة العروض ومتابعة نشاط المتجر.',
  ),
  (
    '2. Compte et accès',
    'Chaque utilisateur est responsable de la confidentialité de son e-mail et de son mot de passe. Le propriétaire du commerce peut inviter des gérants et des employés ; chacun agit selon son rôle et reste responsable des actions faites depuis son compte.',
    '2. الحساب والدخول',
    'كل مستخدم مسؤول عن سرّية بريده وكلمة سره. يمكن لمالك المتجر دعوة مديرين وموظفين؛ ويتصرف كلٌّ حسب دوره ويتحمل مسؤولية ما يتم من حسابه.',
  ),
  (
    '3. Scan et attribution des points',
    'Les points sont attribués lors du scan du QR du client. Pour valider les points, le commerçant doit obligatoirement indiquer le montant réellement payé par le client. Un scan sans montant reste « en attente » et n\'est pas compté comme validé. Un scan fait par erreur peut être annulé depuis l\'application.',
    '3. المسح ومنح النقاط',
    'تُمنح النقاط عند مسح رمز الزبون. ولتأكيد النقاط يجب على التاجر إدخال المبلغ الذي دفعه الزبون فعلاً. المسح بدون مبلغ يبقى «قيد الانتظار» ولا يُحتسب مؤكَّدًا. يمكن إلغاء أي مسح تم بالخطأ من التطبيق.',
  ),
  (
    '4. Exactitude des montants',
    'Le montant saisi doit correspondre à l\'achat réel. Il sert à calculer les statistiques (dépenses, panier moyen). Saisir de faux montants ou de faux scans est interdit.',
    '4. صحة المبالغ',
    'يجب أن يطابق المبلغ المُدخل عملية الشراء الفعلية، فهو يُستعمل لحساب الإحصائيات (المشتريات ومتوسط السلة). يُمنع إدخال مبالغ أو عمليات مسح مزيفة.',
  ),
  (
    '5. Offres et récompenses',
    'Le commerçant est seul responsable des offres qu\'il publie et s\'engage à honorer les récompenses et les offres validées pour ses clients.',
    '5. العروض والمكافآت',
    'التاجر وحده مسؤول عن العروض التي ينشرها، ويلتزم بتقديم المكافآت والعروض التي تم تأكيدها لزبائنه.',
  ),
  (
    '6. Données des clients',
    'Les informations des clients (nom, code, historique de visites) ne doivent être utilisées que pour le programme de fidélité. Il est interdit de les revendre, de les publier ou de les utiliser à d\'autres fins.',
    '6. بيانات الزبائن',
    'يجب استعمال معلومات الزبائن (الاسم، الرمز، سجل الزيارات) فقط لبرنامج الولاء. يُمنع بيعها أو نشرها أو استعمالها لأغراض أخرى.',
  ),
  (
    '7. Usages interdits',
    'Il est interdit de contourner les protections de l\'application, de multiplier les scans pour un même achat, ou de tenter d\'accéder aux données d\'un autre commerce.',
    '7. الاستعمالات الممنوعة',
    'يُمنع التحايل على حمايات التطبيق، أو تكرار المسح لنفس الشراء، أو محاولة الوصول إلى بيانات متجر آخر.',
  ),
  (
    '8. Suspension et suppression',
    'Un compte ou un commerce peut être suspendu en cas de non-respect de ces conditions. Vous pouvez supprimer votre compte à tout moment depuis Paramètres > Sécurité.',
    '8. التعليق والحذف',
    'قد يتم تعليق حساب أو متجر عند مخالفة هذه الشروط. يمكنك حذف حسابك في أي وقت من الإعدادات > الأمان.',
  ),
  (
    '9. Modifications',
    'Ces conditions peuvent évoluer avec l\'application. La version en vigueur est toujours celle affichée ici.',
    '9. التعديلات',
    'قد تتغير هذه الشروط مع تطوّر التطبيق، والنسخة السارية هي دائمًا المعروضة هنا.',
  ),
];

/// Page « Conditions d'utilisation », ouverte depuis le Profil.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: NqScreen(
          title: tr('Conditions', 'الشروط'),
          action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => Navigator.pop(context)),
          header: [
            Text(tr('Conditions d\'utilisation de Nqata Pro', 'شروط استعمال نقطة برو'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            for (final t in _terms)
              SectionCard(
                title: tr(t.$1, t.$3),
                icon: NI.info,
                children: [Text(tr(t.$2, t.$4), style: const TextStyle(fontSize: 14.5, height: 1.45))],
              ),
            const SizedBox(height: 16),
            Center(child: Text(tr('Dernière mise à jour : 22/10/2026', 'آخر تحديث: 22/10/2026'), style: const TextStyle(color: kMuted, fontSize: 12.5))),
            const SizedBox(height: 8),
          ]),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Phase 16B-2, Workstream 1 — pure, config-driven rendering of the
/// onboarding copy deck returned by `getAssociateOnboardingConfig`
/// (`functions/src/employee/onboardingConfig.ts`'s `OnboardingCopy` shape).
///
/// Every widget below reads ONLY from the `copy` map passed in — none
/// hardcodes the fee, a benefit item, a journey step, or any marketing
/// sentence (1b). Every widget also handles its OWN section being absent or
/// structurally empty by rendering nothing (`SizedBox.shrink()`) rather than
/// crashing or substituting placeholder text (1b's edge case).

Map<String, dynamic>? _asMap(dynamic v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _asList(dynamic v) => v is List ? v : const [];
String _asString(dynamic v) => v is String ? v : '';

class OnboardingHeaderSection extends StatelessWidget {
  final Map<String, dynamic> copy;
  const OnboardingHeaderSection({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    final headline = _asString(copy['headline']);
    final feeLabel = _asString(copy['feeLabel']);
    final supportingStatement = _asString(copy['supportingStatement']);
    if (headline.isEmpty && feeLabel.isEmpty && supportingStatement.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headline.isNotEmpty)
            Text(
              headline,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2),
            ),
          if (feeLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                feeLabel,
                style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
          if (supportingStatement.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              supportingStatement,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class OnboardingWhyFeeSection extends StatelessWidget {
  final Map<String, dynamic> copy;
  const OnboardingWhyFeeSection({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    final section = _asMap(copy['whyTheFeeExists']);
    if (section == null) return const SizedBox.shrink();
    final title = _asString(section['title']);
    final body = _asList(section['body']).map(_asString).where((s) => s.isNotEmpty).toList();
    if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: title.isNotEmpty ? title : 'Why this fee exists',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in body) ...[
            Text(paragraph, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF374151))),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class OnboardingBenefitGroupsSection extends StatelessWidget {
  final Map<String, dynamic> copy;
  const OnboardingBenefitGroupsSection({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    final groups = _asList(copy['benefitGroups']);
    if (groups.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: 'What your registration includes',
      icon: Icons.card_giftcard_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final raw in groups) ..._buildGroup(_asMap(raw)),
        ],
      ),
    );
  }

  List<Widget> _buildGroup(Map<String, dynamic>? group) {
    if (group == null) return const [];
    final title = _asString(group['title']);
    final items = _asList(group['items']).map(_asString).where((s) => s.isNotEmpty).toList();
    // Edge case (1b): a benefit group with an empty items list — omit the
    // whole group rather than showing an empty heading.
    if (items.isEmpty) return const [];
    return [
      if (title.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryDark)),
        ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4))),
            ],
          ),
        ),
    ];
  }
}

class OnboardingEarningsExplainerSection extends StatelessWidget {
  final Map<String, dynamic> copy;
  const OnboardingEarningsExplainerSection({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    final section = _asMap(copy['earningsExplainer']);
    if (section == null) return const SizedBox.shrink();
    final title = _asString(section['title']);
    final body = _asList(section['body']).map(_asString).where((s) => s.isNotEmpty).toList();
    final flowSteps = _asList(section['flowSteps']).map(_asString).where((s) => s.isNotEmpty).toList();
    final variabilityFactors =
        _asList(section['variabilityFactors']).map(_asString).where((s) => s.isNotEmpty).toList();
    if (title.isEmpty && body.isEmpty && flowSteps.isEmpty && variabilityFactors.isEmpty) {
      return const SizedBox.shrink();
    }
    return _Card(
      title: title.isNotEmpty ? title : 'How commission works',
      icon: Icons.trending_up_rounded,
      accent: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in body) ...[
            Text(paragraph, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF374151))),
            const SizedBox(height: 8),
          ],
          if (flowSteps.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < flowSteps.length; i++) ...[
                  _FlowChip(label: flowSteps[i]),
                  if (i != flowSteps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF9CA3AF)),
                    ),
                ],
              ],
            ),
          ],
          if (variabilityFactors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Depends on:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final factor in variabilityFactors)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(factor, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FlowChip extends StatelessWidget {
  final String label;
  const _FlowChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
    );
  }
}

class OnboardingJourneyStepsSection extends StatelessWidget {
  final Map<String, dynamic> copy;
  const OnboardingJourneyStepsSection({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    final steps = _asList(copy['journeySteps']);
    if (steps.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: 'Your journey',
      icon: Icons.route_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final raw in steps) ..._buildStep(_asMap(raw)),
        ],
      ),
    );
  }

  List<Widget> _buildStep(Map<String, dynamic>? step) {
    if (step == null) return const [];
    final number = step['step'];
    final title = _asString(step['title']);
    final body = _asString(step['body']);
    if (title.isEmpty && body.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class OnboardingSummaryCardSection extends StatelessWidget {
  final Map<String, dynamic> copy;
  const OnboardingSummaryCardSection({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    final section = _asMap(copy['summaryCard']);
    if (section == null) return const SizedBox.shrink();
    final title = _asString(section['title']);
    final feeLine = _asString(section['feeLine']);
    final includes = _asList(section['includes']).map(_asString).where((s) => s.isNotEmpty).toList();
    if (title.isEmpty && feeLine.isEmpty && includes.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: title.isNotEmpty ? title : 'Summary',
      icon: Icons.summarize_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feeLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(feeLine, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primaryDark)),
            ),
          if (includes.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in includes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(item, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Workstream 1c/D5 — mandatory disclosures. Every entry from the server's
/// `mandatoryDisclosures` array renders here, in full, visually distinct
/// (individually bordered rows, not a paragraph blob), never behind a
/// collapsed "read more". This section has NO empty-omit behaviour like its
/// siblings above — if the list is ever empty (should not happen; the
/// server always returns a non-empty constant array), it renders nothing,
/// but it never truncates a non-empty list.
class OnboardingDisclosuresSection extends StatelessWidget {
  final List<String> disclosures;
  const OnboardingDisclosuresSection({super.key, required this.disclosures});

  @override
  Widget build(BuildContext context) {
    if (disclosures.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
              SizedBox(width: 8),
              Text(
                'Important — please read',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final disclosure in disclosures)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.circle, size: 5, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      disclosure,
                      style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF78350F)),
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

class OnboardingSupportContactSection extends StatelessWidget {
  final Map<String, dynamic> copy;
  const OnboardingSupportContactSection({super.key, required this.copy});

  @override
  Widget build(BuildContext context) {
    final section = _asMap(copy['supportContact']);
    if (section == null) return const SizedBox.shrink();
    final title = _asString(section['title']);
    final body = _asString(section['body']);
    final email = _asString(section['email']);
    final phone = _asString(section['phone']);
    if (title.isEmpty && body.isEmpty && email.isEmpty && phone.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
            ),
          if (email.isNotEmpty || phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 16,
                children: [
                  if (email.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.email_outlined, size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                    ]),
                  if (phone.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color accent;

  const _Card({required this.title, required this.icon, required this.child, this.accent = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

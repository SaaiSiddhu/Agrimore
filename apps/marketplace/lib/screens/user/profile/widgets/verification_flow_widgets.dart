// Shared chrome for the Change Phone Number / Change Email Address wizards
// (PROFILE-10). Both screens are the same 4-step shape (Intro -> Enter value
// -> Verify -> Success); this file holds the pieces neither screen owns
// individually so the ~150 lines of identical step chrome aren't written
// twice. Every real send/verify/collision-check call stays in the two
// screen files themselves -- nothing here talks to a provider or a
// callable.

import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Icon-in-circle + title + subtitle, shown at the top of every wizard step.
class VerificationStepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const VerificationStepHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = isDark ? AppColors.primaryLight : AppColors.primary;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: isDark ? 0.18 : 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: tint, size: 32),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Read-only rounded row showing the current phone/email with a lock icon
/// -- used on the Intro step; there is nothing to tap here.
class LockedValueCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const LockedValueCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = isDark ? AppColors.primaryLight : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, size: 18, color: isDark ? Colors.grey[600] : Colors.grey[400]),
        ],
      ),
    );
  }
}

/// Blue-tinted callout with a bullet list, used under the "enter new
/// value" field on step 2 of both wizards.
class InfoCallout extends StatelessWidget {
  final List<String> bullets;
  final bool isDark;

  const InfoCallout({super.key, required this.bullets, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tint = isDark ? AppColors.infoLight : AppColors.info;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? tint.withValues(alpha: 0.12) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: isDark ? 0.35 : 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: tint, size: 18),
              const SizedBox(width: 8),
              Text(
                'Important',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: tint, fontWeight: FontWeight.w800)),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 6-box OTP display driven by a plain string -- no TextField, no system
/// keyboard. Entry comes only from [NumericKeypad] below, matching the
/// reference mockup's dedicated in-app keypad.
class OtpBoxesDisplay extends StatelessWidget {
  final String otp;
  final bool isDark;

  const OtpBoxesDisplay({super.key, required this.otp, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tint = isDark ? AppColors.primaryLight : AppColors.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final filled = i < otp.length;
        final active = i == otp.length;
        return Container(
          width: 46,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDarkVariant : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? tint
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: active ? 2 : 1,
            ),
          ),
          child: Text(
            filled ? otp[i] : '',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        );
      }),
    );
  }
}

/// Custom 3x4 numeric keypad (1-9, blank, 0, backspace), replacing the
/// system keyboard for OTP entry on the Verify step.
class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool isDark;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.isDark,
  });

  Widget _key(BuildContext context, {String? digit, Widget? child, VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? (digit == null ? null : () => onDigit(digit)),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 58,
            alignment: Alignment.center,
            child: child ??
                Text(
                  digit ?? '',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <List<String?>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [null, '0', 'back'],
    ];
    return Column(
      children: rows
          .map(
            (row) => Row(
              children: row.map((k) {
                if (k == null) return _key(context, child: const SizedBox.shrink(), onTap: () {});
                if (k == 'back') {
                  return _key(
                    context,
                    onTap: onBackspace,
                    child: Icon(
                      Icons.backspace_outlined,
                      size: 20,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  );
                }
                return _key(context, digit: k);
              }).toList(),
            ),
          )
          .toList(),
    );
  }
}

/// Success step scaffold: checkmark with a couple of decorative leaf
/// accents, title/subtitle, a card echoing the new value, and Done.
class VerificationSuccessView extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData valueIcon;
  final String valueLabel;
  final String value;
  final VoidCallback onDone;
  final bool isDark;

  const VerificationSuccessView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.valueIcon,
    required this.valueLabel,
    required this.value,
    required this.onDone,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = isDark ? AppColors.primaryLight : AppColors.primary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 6,
                left: 10,
                child: Icon(Icons.eco_rounded, size: 20, color: tint.withValues(alpha: 0.5)),
              ),
              Positioned(
                bottom: 10,
                right: 6,
                child: Icon(Icons.eco_rounded, size: 16, color: tint.withValues(alpha: 0.35)),
              ),
              Positioned(
                top: 14,
                right: 16,
                child: Icon(Icons.circle, size: 8, color: tint.withValues(alpha: 0.4)),
              ),
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: isDark ? 0.18 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: tint, size: 64),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(valueIcon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valueLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: tint,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width gradient "Continue"/"Send OTP" style button with a trailing
/// arrow, shared by every wizard step that advances forward.
class VerificationPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool isDark;

  const VerificationPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tint = isDark ? AppColors.primaryLight : AppColors.primary;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (enabled && !isLoading) ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: tint,
          disabledBackgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: enabled ? Colors.white : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: enabled ? Colors.white : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
      ),
    );
  }
}

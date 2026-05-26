import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

const _kVersion = '0.9.20260519';
const _kGitHubUrl = 'https://github.com/selwynpolit/three_by_five';

void showThreeByFiveAboutDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const _AboutDialog(),
  );
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: AppColors.canvas,
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── App icon / title ─────────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.appBackground,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '3×5',
                    style: GoogleFonts.caveat(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── App name ─────────────────────────────────────────────
              Text(
                '3by5',
                style: GoogleFonts.caveat(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'by Selwyn Polit',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Coded with Claude Code',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
              const SizedBox(height: 16),

              // ── Version ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Version $_kVersion',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.4,
                      ),
                ),
              ),
              const SizedBox(height: 20),

              // ── GitHub link ───────────────────────────────────────────
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                  children: [
                    const TextSpan(text: 'Source on '),
                    TextSpan(
                      text: 'GitHub',
                      style: TextStyle(
                        color: AppColors.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.accent,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            Process.run('open', [_kGitHubUrl]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── OK button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

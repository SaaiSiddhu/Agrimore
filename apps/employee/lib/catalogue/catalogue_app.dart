// ignore_for_file: public_member_api_docs

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import '../utils/sa_formatters.dart';

/// Standalone Developer Component Catalogue for AgriMore Sales Associate.
///
/// Runs without Firebase initialization, without backend dependencies, and
/// without requiring production login credentials.
class SaCatalogueApp extends StatelessWidget {
  const SaCatalogueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriMore SA Design Catalogue',
      debugShowCheckedModeBanner: false,
      theme: SalesAssociateTheme.lightTheme,
      home: const _CatalogueHomeScreen(),
    );
  }
}

class _CatalogueHomeScreen extends StatefulWidget {
  const _CatalogueHomeScreen();

  @override
  State<_CatalogueHomeScreen> createState() => _CatalogueHomeScreenState();
}

class _CatalogueHomeScreenState extends State<_CatalogueHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriMore SA Design System'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: SaTokens.primary,
          unselectedLabelColor: SaTokens.textSecondary,
          indicatorColor: SaTokens.primary,
          tabs: const [
            Tab(text: 'Brand & Tokens'),
            Tab(text: 'Typography'),
            Tab(text: 'Icons'),
            Tab(text: 'Components'),
            Tab(text: 'Content & Privacy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TokensTab(),
          _TypographyTab(),
          _IconsTab(),
          _ComponentsTab(),
          _ContentTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Brand & Tokens Tab
// ─────────────────────────────────────────────────────────────────────────────

class _TokensTab extends StatelessWidget {
  const _TokensTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SaTokens.pagePadding),
      children: [
        const _SectionHeader(title: '01 Primary Palette'),
        Row(
          children: const [
            Expanded(
              child: _ColorSwatch(
                name: 'Primary',
                hex: '#2563EB',
                color: SaTokens.primary,
                textColor: Colors.white,
                role: 'Actions & selection',
              ),
            ),
            SizedBox(width: SaTokens.space12),
            Expanded(
              child: _ColorSwatch(
                name: 'Pressed',
                hex: '#1D4ED8',
                color: SaTokens.primaryPressed,
                textColor: Colors.white,
                role: 'Pressed actions',
              ),
            ),
            SizedBox(width: SaTokens.space12),
            Expanded(
              child: _ColorSwatch(
                name: 'Subtle',
                hex: '#EFF6FF',
                color: SaTokens.primarySubtle,
                textColor: SaTokens.primary,
                role: 'Info surfaces',
                hasBorder: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: '02 Neutral Foundations'),
        Wrap(
          spacing: SaTokens.space12,
          runSpacing: SaTokens.space12,
          children: const [
            _MiniColorSwatch(
              name: 'Background',
              hex: '#F8FAFC',
              color: SaTokens.pageBackground,
            ),
            _MiniColorSwatch(
              name: 'Surface',
              hex: '#FFFFFF',
              color: SaTokens.surface,
              hasBorder: true,
            ),
            _MiniColorSwatch(
              name: 'Text Primary',
              hex: '#0F172A',
              color: SaTokens.textPrimary,
              textColor: Colors.white,
            ),
            _MiniColorSwatch(
              name: 'Text Secondary',
              hex: '#475569',
              color: SaTokens.textSecondary,
              textColor: Colors.white,
            ),
            _MiniColorSwatch(
              name: 'Divider',
              hex: '#E2E8F0',
              color: SaTokens.divider,
            ),
            _MiniColorSwatch(
              name: 'Input border',
              hex: '#64748B',
              color: SaTokens.inputBorder,
              textColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: '03 Semantic Accents'),
        Row(
          children: const [
            Expanded(
              child: _SemanticPairCard(
                name: 'Success',
                fgHex: '#15803D',
                fgColor: SaTokens.successFg,
                bgColor: SaTokens.successBg,
                icon: SaIcons.circleCheck,
              ),
            ),
            SizedBox(width: SaTokens.space8),
            Expanded(
              child: _SemanticPairCard(
                name: 'Warning',
                fgHex: '#B45309',
                fgColor: SaTokens.warningFg,
                bgColor: SaTokens.warningBg,
                icon: SaIcons.triangleAlert,
              ),
            ),
            SizedBox(width: SaTokens.space8),
            Expanded(
              child: _SemanticPairCard(
                name: 'Error',
                fgHex: '#B91C1C',
                fgColor: SaTokens.errorFg,
                bgColor: SaTokens.errorBg,
                icon: SaIcons.circleAlert,
              ),
            ),
          ],
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: '04 Spacing Scale'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SaTokens.space16),
            child: Column(
              children: const [
                _SpacingRow(label: '4 px', size: SaTokens.space4),
                _SpacingRow(label: '8 px', size: SaTokens.space8),
                _SpacingRow(label: '12 px', size: SaTokens.space12),
                _SpacingRow(label: '16 px', size: SaTokens.space16),
                _SpacingRow(label: '24 px', size: SaTokens.space24),
                _SpacingRow(label: '32 px', size: SaTokens.space32),
                _SpacingRow(label: '48 px', size: SaTokens.space48),
              ],
            ),
          ),
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: '05 Corner Radii'),
        Row(
          children: [
            Expanded(
              child: _RadiusCard(
                name: 'Input / Button',
                radius: SaTokens.radiusInput,
              ),
            ),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: _RadiusCard(
                name: 'Card',
                radius: SaTokens.radiusCard,
              ),
            ),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: _RadiusCard(
                name: 'Bottom Sheet',
                radius: SaTokens.radiusBottomSheet,
                topOnly: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Typography Tab
// ─────────────────────────────────────────────────────────────────────────────

class _TypographyTab extends StatefulWidget {
  const _TypographyTab();

  @override
  State<_TypographyTab> createState() => _TypographyTabState();
}

class _TypographyTabState extends State<_TypographyTab> {
  double _textScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_textScale),
      ),
      child: ListView(
        padding: const EdgeInsets.all(SaTokens.pagePadding),
        children: [
          Card(
            color: SaTokens.primarySubtle,
            child: Padding(
              padding: const EdgeInsets.all(SaTokens.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Text Scale Simulator',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(_textScale * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _textScale,
                    min: 0.8,
                    max: 2.0,
                    divisions: 12,
                    activeColor: SaTokens.primary,
                    onChanged: (val) => setState(() => _textScale = val),
                  ),
                  const Text(
                    'Verify that layouts do not clip when user enables system text scaling.',
                    style: TextStyle(
                      fontSize: SaTokens.fsCaption,
                      color: SaTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SaTokens.space24),
          const _SectionHeader(title: 'Inter 6-Level Scale'),
          _TypeSpecimenCard(
            level: 'Display amount',
            spec: '32 sp / 40 line-height / Semibold 600',
            sampleText: '₹12,500.00',
            style: theme.textTheme.displayLarge!,
          ),
          const SizedBox(height: SaTokens.space12),
          _TypeSpecimenCard(
            level: 'Screen title',
            spec: '24 sp / 32 line-height / Semibold 600',
            sampleText: 'Welcome back',
            style: theme.textTheme.headlineMedium!,
          ),
          const SizedBox(height: SaTokens.space12),
          _TypeSpecimenCard(
            level: 'Section heading',
            spec: '18 sp / 26 line-height / Semibold 600',
            sampleText: 'Account details',
            style: theme.textTheme.titleMedium!,
          ),
          const SizedBox(height: SaTokens.space12),
          _TypeSpecimenCard(
            level: 'Body',
            spec: '16 sp / 24 line-height / Regular 400',
            sampleText: 'Manage your sales and commission.',
            style: theme.textTheme.bodyLarge!,
          ),
          const SizedBox(height: SaTokens.space12),
          _TypeSpecimenCard(
            level: 'Label',
            spec: '14 sp / 20 line-height / Medium 500',
            sampleText: 'Mobile number',
            style: theme.textTheme.labelLarge!,
          ),
          const SizedBox(height: SaTokens.space12),
          _TypeSpecimenCard(
            level: 'Caption',
            spec: '12 sp / 18 line-height / Regular 400',
            sampleText: 'Last updated today',
            style: theme.textTheme.bodySmall!,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Icons Tab
// ─────────────────────────────────────────────────────────────────────────────

class _IconsTab extends StatelessWidget {
  const _IconsTab();

  static const List<(String, IconData)> _icons = [
    ('Phone', SaIcons.phone),
    ('Mail', SaIcons.mail),
    ('LockKeyhole', SaIcons.lockKeyhole),
    ('Eye', SaIcons.eye),
    ('EyeOff', SaIcons.eyeOff),
    ('ArrowLeft', SaIcons.arrowLeft),
    ('X', SaIcons.x),
    ('Info', SaIcons.info),
    ('CircleCheck', SaIcons.circleCheck),
    ('TriangleAlert', SaIcons.triangleAlert),
    ('CircleAlert', SaIcons.circleAlert),
    ('RotateCcw', SaIcons.rotateCcw),
    ('Headphones', SaIcons.headphones),
    ('LogOut', SaIcons.logOut),
    ('Wallet', SaIcons.wallet),
    ('ShoppingBag', SaIcons.shoppingBag),
    ('User', SaIcons.user),
    ('Bell', SaIcons.bell),
    ('Copy', SaIcons.copy),
    ('Share2', SaIcons.share2),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SaTokens.pagePadding),
      children: [
        const _SectionHeader(title: 'Core Icon Catalogue (20 Icons)'),
        const Text(
          'Rendered at navigation size (24px) inside 48×48 minimum touch targets.',
          style: TextStyle(
            fontSize: SaTokens.fsCaption,
            color: SaTokens.textSecondary,
          ),
        ),
        const SizedBox(height: SaTokens.space16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.85,
            crossAxisSpacing: SaTokens.space12,
            mainAxisSpacing: SaTokens.space12,
          ),
          itemCount: _icons.length,
          itemBuilder: (context, index) {
            final (name, icon) = _icons[index];
            return Card(
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: SaTokens.minTouchTarget,
                      height: SaTokens.minTouchTarget,
                      child: Center(
                        child: Icon(
                          icon,
                          size: SaTokens.iconNav,
                          color: SaTokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: SaTokens.space4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: SaTokens.fsCaption,
                        color: SaTokens.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: 'Size Specimens'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SaTokens.space16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _IconSpecimen(
                  size: SaTokens.iconSupporting,
                  label: 'Supporting (16 px)',
                  icon: SaIcons.eye,
                ),
                _IconSpecimen(
                  size: SaTokens.iconControl,
                  label: 'Controls (20 px)',
                  icon: SaIcons.eye,
                ),
                _IconSpecimen(
                  size: SaTokens.iconNav,
                  label: 'Navigation (24 px)',
                  icon: SaIcons.eye,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Components Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ComponentsTab extends StatefulWidget {
  const _ComponentsTab();

  @override
  State<_ComponentsTab> createState() => _ComponentsTabState();
}

class _ComponentsTabState extends State<_ComponentsTab> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SaTokens.pagePadding),
      children: [
        const _SectionHeader(title: '01 Actions & Buttons'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Toggle Interactive Loading State:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Switch(
              value: _isLoading,
              activeTrackColor: SaTokens.primary,
              onChanged: (val) => setState(() => _isLoading = val),
            ),
          ],
        ),
        const SizedBox(height: SaTokens.space12),
        SaLoadingButton(
          text: 'Continue (Primary)',
          isLoading: _isLoading,
          loadingText: 'Signing in...',
          onPressed: () {},
        ),
        const SizedBox(height: SaTokens.space12),
        SaLoadingButton(
          text: 'Back (Outlined)',
          variant: SaButtonVariant.outlined,
          isLoading: _isLoading,
          loadingText: 'Loading...',
          onPressed: () {},
        ),
        const SizedBox(height: SaTokens.space12),
        const SaLoadingButton(
          text: 'Disabled Action',
          onPressed: null,
        ),
        const SizedBox(height: SaTokens.space12),
        SaLoadingButton(
          text: 'Contact Support',
          variant: SaButtonVariant.outlined,
          icon: SaIcons.headphones,
          onPressed: () {},
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: '02 Form Fields & States'),
        TextFormField(
          initialValue: '98765 43210',
          decoration: const InputDecoration(
            labelText: 'Mobile number (Default / Populated)',
            hintText: 'e.g. 98765 43210',
          ),
        ),
        const SizedBox(height: SaTokens.space16),
        TextFormField(
          initialValue: '123',
          decoration: const InputDecoration(
            labelText: 'Mobile number (Error State)',
            errorText: 'Enter a valid 10-digit mobile number.',
          ),
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: '03 Feedback Banners'),
        const SaInfoBanner(
          message: 'Your application is under review.',
          variant: SaBannerVariant.info,
        ),
        const SizedBox(height: SaTokens.space12),
        const SaInfoBanner(
          message: 'Unable to load. Try again.',
          variant: SaBannerVariant.error,
          actionLabel: 'Try again',
        ),
        const SizedBox(height: SaTokens.space12),
        const SaInfoBanner(
          message: 'Please complete your payout details.',
          variant: SaBannerVariant.warning,
        ),
        const SizedBox(height: SaTokens.space12),
        const SaInfoBanner(
          message: 'Code verified successfully.',
          variant: SaBannerVariant.success,
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: '04 Card & Financial Items'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SaTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available balance',
                  style: TextStyle(
                    fontSize: SaTokens.fsLabel,
                    color: SaTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: SaTokens.space8),
                Text(
                  SaFormatters.formatCurrency(12500),
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SaTokens.space12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SaTokens.space16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: SaTokens.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      SaIcons.circleCheck,
                      color: SaTokens.successFg,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: SaTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Commission credited',
                        style: TextStyle(
                          fontSize: SaTokens.fsBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Order ORD-1042 • 12 Mar 2026',
                        style: TextStyle(
                          fontSize: SaTokens.fsCaption,
                          color: SaTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${SaFormatters.formatCurrency(500)}',
                  style: const TextStyle(
                    fontSize: SaTokens.fsBody,
                    fontWeight: FontWeight.bold,
                    color: SaTokens.successFg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Content & Privacy Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ContentTab extends StatelessWidget {
  const _ContentTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SaTokens.pagePadding),
      children: [
        const _SectionHeader(title: 'Content Conventions (Canonical Board 02)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SaTokens.space16),
            child: Column(
              children: [
                _ContentConventionRow(
                  label: 'Terminology',
                  value: 'AgriMore Sales Associate',
                  note: 'Approved user-facing role identity.',
                ),
                const Divider(),
                _ContentConventionRow(
                  label: 'Currency',
                  value: SaFormatters.formatCurrency(125000),
                  note: 'Indian number grouping with two decimals.',
                ),
                const Divider(),
                _ContentConventionRow(
                  label: 'Date',
                  value: SaFormatters.formatDate(DateTime(2026, 9, 18)),
                  note: 'Day-month-year with abbreviated month.',
                ),
                const Divider(),
                _ContentConventionRow(
                  label: 'Phone format',
                  value: SaFormatters.formatMaskedPhone('9876544321'),
                  note: 'Masked mobile with country code (+91 •••••• 4321).',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SaTokens.space24),
        const _SectionHeader(title: 'Privacy & Data Protection (Board 07)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(SaTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrivacyFieldRow(
                  label: 'Phone number',
                  value: SaFormatters.formatMaskedPhone('9876544321'),
                  icon: SaIcons.phone,
                ),
                const SizedBox(height: SaTokens.space12),
                _PrivacyFieldRow(
                  label: 'Bank account',
                  value: SaFormatters.formatMaskedAccount('5010043219874321'),
                  icon: SaIcons.wallet,
                ),
                const SizedBox(height: SaTokens.space12),
                const _PrivacyFieldRow(
                  label: 'Password',
                  value: '••••••••',
                  icon: SaIcons.lockKeyhole,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SaTokens.space12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: SaTokens.fsSectionHeading,
          fontWeight: FontWeight.w600,
          color: SaTokens.textPrimary,
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.name,
    required this.hex,
    required this.color,
    required this.textColor,
    required this.role,
    this.hasBorder = false,
  });

  final String name;
  final String hex;
  final Color color;
  final Color textColor;
  final String role;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
        border: hasBorder ? Border.all(color: SaTokens.divider) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: SaTokens.space4),
          Text(
            hex,
            style: TextStyle(
              fontSize: SaTokens.fsCaption,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: SaTokens.space8),
          Text(
            role,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniColorSwatch extends StatelessWidget {
  const _MiniColorSwatch({
    required this.name,
    required this.hex,
    required this.color,
    this.textColor = SaTokens.textPrimary,
    this.hasBorder = false,
  });

  final String name;
  final String hex;
  final Color color;
  final Color textColor;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(SaTokens.space8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
        border: hasBorder ? Border.all(color: SaTokens.divider) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            hex,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemanticPairCard extends StatelessWidget {
  const _SemanticPairCard({
    required this.name,
    required this.fgHex,
    required this.fgColor,
    required this.bgColor,
    required this.icon,
  });

  final String name;
  final String fgHex;
  final Color fgColor;
  final Color bgColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
        border: Border.all(color: fgColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: fgColor, size: 24),
          const SizedBox(height: SaTokens.space4),
          Text(
            name,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
          Text(
            fgHex,
            style: TextStyle(
              fontSize: 10,
              color: fgColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpacingRow extends StatelessWidget {
  const _SpacingRow({required this.label, required this.size});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontSize: SaTokens.fsCaption),
            ),
          ),
          Container(
            height: 16,
            width: size * 3,
            decoration: BoxDecoration(
              color: SaTokens.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusCard extends StatelessWidget {
  const _RadiusCard({
    required this.name,
    required this.radius,
    this.topOnly = false,
  });

  final String name;
  final double radius;
  final bool topOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: SaTokens.primarySubtle,
        borderRadius: topOnly
            ? BorderRadius.vertical(top: Radius.circular(radius))
            : BorderRadius.circular(radius),
        border: Border.all(color: SaTokens.primary),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SaTokens.primary,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '${radius.toInt()} px',
              style: const TextStyle(
                fontSize: 10,
                color: SaTokens.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSpecimenCard extends StatelessWidget {
  const _TypeSpecimenCard({
    required this.level,
    required this.spec,
    required this.sampleText,
    required this.style,
  });

  final String level;
  final String spec;
  final String sampleText;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SaTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  level,
                  style: const TextStyle(
                    fontSize: SaTokens.fsCaption,
                    fontWeight: FontWeight.w600,
                    color: SaTokens.primary,
                  ),
                ),
                Text(
                  spec,
                  style: const TextStyle(
                    fontSize: 11,
                    color: SaTokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SaTokens.space8),
            Text(sampleText, style: style),
          ],
        ),
      ),
    );
  }
}

class _IconSpecimen extends StatelessWidget {
  const _IconSpecimen({
    required this.size,
    required this.label,
    required this.icon,
  });

  final double size;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: size, color: SaTokens.textPrimary),
        const SizedBox(height: SaTokens.space4),
        Text(
          label,
          style: const TextStyle(
            fontSize: SaTokens.fsCaption,
            color: SaTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ContentConventionRow extends StatelessWidget {
  const _ContentConventionRow({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: SaTokens.fsLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: SaTokens.fsBody,
                    fontWeight: FontWeight.w600,
                    color: SaTokens.primary,
                  ),
                ),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: SaTokens.fsCaption,
                    color: SaTokens.textSecondary,
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

class _PrivacyFieldRow extends StatelessWidget {
  const _PrivacyFieldRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SaTokens.space16,
        vertical: SaTokens.space12,
      ),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: SaTokens.iconControl, color: SaTokens.textSecondary),
          const SizedBox(width: SaTokens.space12),
          Text(
            label,
            style: const TextStyle(
              fontSize: SaTokens.fsLabel,
              color: SaTokens.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: SaTokens.fsBody,
              fontWeight: FontWeight.w600,
              color: SaTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

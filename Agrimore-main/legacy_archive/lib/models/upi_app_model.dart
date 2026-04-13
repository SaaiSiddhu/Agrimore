class UpiAppModel {
  final String name;
  final String packageName;
  final String icon;
  final bool isInstalled;

  const UpiAppModel({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.isInstalled,
  });

  static List<UpiAppModel> defaultApps() {
    return [
      const UpiAppModel(
        name: 'Google Pay',
        packageName: 'com.google.android.apps.nbu.paisa.user',
        icon: '💰',
        isInstalled: false,
      ),
      const UpiAppModel(
        name: 'PhonePe',
        packageName: 'com.phonepe.app',
        icon: '📱',
        isInstalled: false,
      ),
      const UpiAppModel(
        name: 'Paytm',
        packageName: 'net.one97.paytm',
        icon: '💙',
        isInstalled: false,
      ),
      const UpiAppModel(
        name: 'Amazon Pay',
        packageName: 'in.amazon.mShop.android.shopping',
        icon: '🛒',
        isInstalled: false,
      ),
      const UpiAppModel(
        name: 'BHIM',
        packageName: 'in.org.npci.upiapp',
        icon: '🏦',
        isInstalled: false,
      ),
      const UpiAppModel(
        name: 'WhatsApp',
        packageName: 'com.whatsapp',
        icon: '💬',
        isInstalled: false,
      ),
    ];
  }
}

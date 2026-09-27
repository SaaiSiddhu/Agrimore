import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The Delivery Partner app's unified icon set: Lucide outline icons on a 24 dp
/// grid with 2 px stroke (Phase 06).
///
/// Feature screens import [DeliveryIcons] rather than raw `Icons.*` or
/// `CupertinoIcons.*` so `canon_check.sh` stays at 0 hits.
abstract final class DeliveryIcons {
  // Navigation (Phase 07: Home · Deliveries · Earnings · Inbox · Profile)
  static const IconData home = LucideIcons.house;
  static const IconData deliveries = LucideIcons.packageCheck;
  static const IconData earnings = LucideIcons.indianRupee;
  static const IconData inbox = LucideIcons.bell;
  static const IconData profile = LucideIcons.circleUser;

  // App bar & common actions
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData close = LucideIcons.x;
  static const IconData search = LucideIcons.search;
  static const IconData bell = LucideIcons.bell;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData add = LucideIcons.plus;
  static const IconData remove = LucideIcons.minus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData copy = LucideIcons.copy;
  static const IconData share = LucideIcons.share2;
  static const IconData externalLink = LucideIcons.externalLink;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData replace = LucideIcons.rotateCcw;
  static const IconData filter = LucideIcons.funnel;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData check = LucideIcons.check;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData settings = LucideIcons.settings;
  static const IconData logOut = LucideIcons.logOut;
  static const IconData logout = LucideIcons.logOut;
  static const IconData send = LucideIcons.sendHorizontal;
  static const IconData upload = LucideIcons.upload;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;

  // Status & alerts (paired with text, never colour alone — Phase 12, 32)
  static const IconData info = LucideIcons.info;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData danger = LucideIcons.circleAlert;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData cancelled = LucideIcons.circleX;
  static const IconData pending = LucideIcons.clock;
  static const IconData clock = LucideIcons.clock;
  static const IconData hourglass = LucideIcons.hourglass;
  static const IconData timer = LucideIcons.timer;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData cloudOff = LucideIcons.cloudOff;
  static const IconData online = LucideIcons.radio;
  static const IconData blocked = LucideIcons.ban;
  static const IconData flask = LucideIcons.flaskConical;

  // Rider, vehicles, route & navigation (Phases 06, 16, 18–25)
  static const IconData bike = LucideIcons.bike;
  static const IconData bicycle = LucideIcons.bike;
  static const IconData truck = LucideIcons.truck;
  static const IconData car = LucideIcons.car;
  static const IconData zap = LucideIcons.zap;
  static const IconData navigation = LucideIcons.navigation;
  static const IconData compass = LucideIcons.compass;
  static const IconData map = LucideIcons.map;
  static const IconData mapPin = LucideIcons.mapPin;
  static const IconData pickup = LucideIcons.store;
  static const IconData dropoff = LucideIcons.mapPinCheck;
  static const IconData locate = LucideIcons.locateFixed;
  static const IconData route = LucideIcons.route;
  static const IconData list = LucideIcons.list;
  static const IconData store = LucideIcons.store;
  static const IconData package = LucideIcons.package;
  static const IconData packageOpen = LucideIcons.packageOpen;
  static const IconData packageCheck = LucideIcons.packageCheck;
  static const IconData shield = LucideIcons.shieldCheck;
  static const IconData shieldAlert = LucideIcons.shieldAlert;
  static const IconData emergency = LucideIcons.siren;
  static const IconData verified = LucideIcons.badgeCheck;
  static const IconData keyRound = LucideIcons.keyRound;
  static const IconData pin = LucideIcons.keyRound;
  static const IconData batteryWarning = LucideIcons.batteryWarning;

  // Contact, identity & documents
  static const IconData phone = LucideIcons.phone;
  static const IconData phoneCall = LucideIcons.phoneCall;
  static const IconData call = LucideIcons.phoneCall;
  static const IconData mail = LucideIcons.mail;
  static const IconData message = LucideIcons.messageSquare;
  static const IconData lock = LucideIcons.lock;
  static const IconData user = LucideIcons.user;
  static const IconData idCard = LucideIcons.idCard;
  static const IconData document = LucideIcons.fileText;
  static const IconData documentCheck = LucideIcons.fileCheck;
  static const IconData documentWarning = LucideIcons.fileWarning;
  static const IconData support = LucideIcons.headset;
  static const IconData help = LucideIcons.circleHelp;
  static const IconData camera = LucideIcons.camera;
  static const IconData image = LucideIcons.image;
  static const IconData imageAdd = LucideIcons.imagePlus;
  static const IconData imageOff = LucideIcons.imageOff;

  // Money, COD & statements (Phases 27–29)
  static const IconData rupee = LucideIcons.indianRupee;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData cash = LucideIcons.banknote;
  static const IconData bank = LucideIcons.landmark;
  static const IconData upi = LucideIcons.send;
  static const IconData receipt = LucideIcons.receiptIndianRupee;
  static const IconData statement = LucideIcons.fileSpreadsheet;
  static const IconData history = LucideIcons.history;
  static const IconData calendar = LucideIcons.calendar;

  // Appearance (Phases 03, 14, 31)
  static const IconData sun = LucideIcons.sun;
  static const IconData moon = LucideIcons.moon;
  static const IconData systemTheme = LucideIcons.smartphone;

  // Additional semantic aliases used across feature screens
  static const IconData location = LucideIcons.mapPin;
  static const IconData locationOff = LucideIcons.locateOff;
  static const IconData battery = LucideIcons.batteryCharging;
  static const IconData report = LucideIcons.flag;
  static const IconData login = LucideIcons.logIn;
  static const IconData rider = LucideIcons.bike;
  static const IconData packageX = LucideIcons.packageX;
  static const IconData checkCircle = LucideIcons.circleCheck;
  static const IconData activeOrder = LucideIcons.packageCheck;
  static const IconData invoice = LucideIcons.fileSpreadsheet;
  static const IconData shieldCheck = LucideIcons.shieldCheck;
  static const IconData circle = LucideIcons.circle;
}

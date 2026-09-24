import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The one icon set for AgriMore Workspace apps (ADR-S06): Lucide outline.
///
/// A superset of `SaIcons` (same glyphs for the same names). `Icons.*`,
/// `FontAwesomeIcons.*` and `CupertinoIcons.*` are not used in Workspace
/// screens. Sizes: `WsIconSize`.
abstract final class AgIcons {
  AgIcons._();

  // ── Identity & auth (SaIcons parity) ──────────────────────────────────────
  static const IconData phone = LucideIcons.phone;
  static const IconData mail = LucideIcons.mail;
  static const IconData lock = LucideIcons.lock;
  static const IconData user = LucideIcons.user;
  static const IconData users = LucideIcons.users;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;
  static const IconData logOut = LucideIcons.logOut;
  static const IconData shieldCheck = LucideIcons.shieldCheck;
  static const IconData badgeCheck = LucideIcons.badgeCheck;

  // ── Navigation & actions ──────────────────────────────────────────────────
  static const IconData home = LucideIcons.house;
  static const IconData arrowLeft = LucideIcons.arrowLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData close = LucideIcons.x;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData search = LucideIcons.search;
  static const IconData filter = LucideIcons.filter;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData add = LucideIcons.plus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData copy = LucideIcons.copy;
  static const IconData share = LucideIcons.share2;
  static const IconData externalLink = LucideIcons.externalLink;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData undo = LucideIcons.rotateCcw;
  static const IconData settings = LucideIcons.settings2;

  // ── Feedback ──────────────────────────────────────────────────────────────
  static const IconData info = LucideIcons.info;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData bell = LucideIcons.bell;
  static const IconData support = LucideIcons.headphones;
  static const IconData help = LucideIcons.lifeBuoy;

  // ── Commerce domain ───────────────────────────────────────────────────────
  static const IconData orders = LucideIcons.shoppingBag;
  static const IconData product = LucideIcons.package;
  static const IconData packed = LucideIcons.packageCheck;
  static const IconData packageRejected = LucideIcons.packageX;
  static const IconData delivery = LucideIcons.truck;
  static const IconData quote = LucideIcons.clipboardList;
  static const IconData invoice = LucideIcons.receiptIndianRupee;
  static const IconData rupee = LucideIcons.indianRupee;
  static const IconData wallet = LucideIcons.wallet;
  static const IconData bank = LucideIcons.landmark;
  static const IconData document = LucideIcons.fileText;
  static const IconData download = LucideIcons.fileDown;
  static const IconData inventory = LucideIcons.boxes;
  static const IconData tag = LucideIcons.tag;
  static const IconData tags = LucideIcons.tags;
  static const IconData discount = LucideIcons.percent;
  static const IconData store = LucideIcons.store;
  static const IconData image = LucideIcons.image;
  static const IconData camera = LucideIcons.camera;
  static const IconData scan = LucideIcons.scanLine;
  static const IconData chat = LucideIcons.messageSquare;
  static const IconData thread = LucideIcons.messagesSquare;
  static const IconData star = LucideIcons.star;
  static const IconData location = LucideIcons.mapPin;

  // ── Delivery (DLV-P1: the rider app) ──────────────────────────────────────
  static const IconData rider = LucideIcons.bike;
  static const IconData navigate = LucideIcons.navigation;
  static const IconData locate = LucideIcons.locateFixed;
  static const IconData locationOff = LucideIcons.mapPinOff;
  static const IconData battery = LucideIcons.batteryWarning;
  static const IconData emergency = LucideIcons.siren;
  static const IconData call = LucideIcons.phoneCall;
  static const IconData history = LucideIcons.history;
  static const IconData report = LucideIcons.flag;
  static const IconData addPhoto = LucideIcons.imagePlus;
  static const IconData stepPending = LucideIcons.circle;
  static const IconData allDone = LucideIcons.checkCheck;

  // ── Insights & time ───────────────────────────────────────────────────────
  static const IconData chartBar = LucideIcons.chartColumn;
  static const IconData chartLine = LucideIcons.chartLine;
  static const IconData trendUp = LucideIcons.trendingUp;
  static const IconData trendDown = LucideIcons.trendingDown;
  static const IconData clock = LucideIcons.clock;
  static const IconData timer = LucideIcons.timer;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData sparkles = LucideIcons.sparkles;

  // ── App ───────────────────────────────────────────────────────────────────
  static const IconData language = LucideIcons.languages;
  static const IconData darkMode = LucideIcons.moon;
  static const IconData lightMode = LucideIcons.sun;
}

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The seller app's one icon set: Lucide outline, 2 px stroke (board 06).
/// Names describe meaning, not shape. `Icons.*`, `CupertinoIcons.*` and
/// `FontAwesomeIcons.*` are not used in seller screens.
abstract final class SellerIcons {
  // Navigation (board 06: Home · Orders · Catalogue · Payments · Account).
  static const IconData home = LucideIcons.house;
  static const IconData orders = LucideIcons.shoppingBag;
  static const IconData catalogue = LucideIcons.package;
  static const IconData payments = LucideIcons.creditCard;
  static const IconData account = LucideIcons.circleUser;

  // App bar & common actions.
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData close = LucideIcons.x;
  static const IconData search = LucideIcons.search;
  static const IconData bell = LucideIcons.bell;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData moreHorizontal = LucideIcons.ellipsis;
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
  static const IconData send = LucideIcons.sendHorizontal;
  static const IconData upload = LucideIcons.upload;
  static const IconData counter = LucideIcons.arrowLeftRight;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;

  // Status (board 12 / 24-06: each status has its own shape, never colour alone).
  static const IconData info = LucideIcons.info;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData cancelled = LucideIcons.circleX;
  static const IconData newItem = LucideIcons.circleDot;
  static const IconData pending = LucideIcons.clock;
  static const IconData hourglass = LucideIcons.hourglass;
  static const IconData timer = LucideIcons.timer;
  static const IconData paused = LucideIcons.circlePause;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData blocked = LucideIcons.ban;
  static const IconData trendUp = LucideIcons.arrowUp;
  static const IconData trendDown = LucideIcons.arrowDown;
  static const IconData flat = LucideIcons.minus;

  // Identity & contact.
  static const IconData phone = LucideIcons.phone;
  static const IconData mail = LucideIcons.mail;
  static const IconData message = LucideIcons.messageSquare;
  static const IconData lock = LucideIcons.lock;
  static const IconData user = LucideIcons.user;
  static const IconData users = LucideIcons.users;
  static const IconData business = LucideIcons.building2;
  static const IconData shield = LucideIcons.shieldCheck;
  static const IconData shieldAlert = LucideIcons.shieldAlert;
  static const IconData verified = LucideIcons.badgeCheck;
  static const IconData support = LucideIcons.headset;
  static const IconData help = LucideIcons.circleHelp;
  static const IconData google = LucideIcons.globe;

  // Commerce.
  static const IconData store = LucideIcons.store;
  static const IconData product = LucideIcons.package;
  static const IconData packing = LucideIcons.package;
  static const IconData packed = LucideIcons.packageCheck;
  static const IconData packageOpen = LucideIcons.packageOpen;
  static const IconData ready = LucideIcons.store;
  static const IconData delivery = LucideIcons.truck;
  static const IconData quote = LucideIcons.messageSquareText;
  static const IconData invoice = LucideIcons.fileText;
  static const IconData document = LucideIcons.fileText;
  static const IconData documentCheck = LucideIcons.fileCheck;
  static const IconData documentWarning = LucideIcons.fileWarning;
  static const IconData receipt = LucideIcons.receiptIndianRupee;
  static const IconData rupee = LucideIcons.indianRupee;
  static const IconData bank = LucideIcons.landmark;
  static const IconData upi = LucideIcons.send;
  static const IconData cash = LucideIcons.banknote;
  static const IconData card = LucideIcons.creditCard;
  static const IconData stock = LucideIcons.layers;
  static const IconData inventory = LucideIcons.boxes;
  static const IconData tag = LucideIcons.tag;
  static const IconData percent = LucideIcons.percent;
  static const IconData wholesale = LucideIcons.users;
  static const IconData coverage = LucideIcons.mapPin;
  static const IconData location = LucideIcons.mapPin;
  static const IconData locate = LucideIcons.locateFixed;
  static const IconData image = LucideIcons.image;
  static const IconData imageOff = LucideIcons.imageOff;
  static const IconData imageAdd = LucideIcons.imagePlus;
  static const IconData camera = LucideIcons.camera;
  static const IconData star = LucideIcons.star;
  static const IconData starHalf = LucideIcons.starHalf;
  static const IconData leaf = LucideIcons.leaf;
  static const IconData sprout = LucideIcons.sprout;
  static const IconData post = LucideIcons.squarePen;
  static const IconData history = LucideIcons.history;
  static const IconData checklist = LucideIcons.listChecks;

  // Time & schedule.
  static const IconData calendar = LucideIcons.calendar;
  static const IconData calendarDays = LucideIcons.calendarDays;
  static const IconData calendarAdd = LucideIcons.calendarPlus;
  static const IconData clock = LucideIcons.clock;

  // Insights.
  static const IconData chartBar = LucideIcons.chartColumn;
  static const IconData chartLine = LucideIcons.chartLine;
  static const IconData chartPie = LucideIcons.chartPie;
  static const IconData trendingUp = LucideIcons.trendingUp;
  static const IconData health = LucideIcons.shieldCheck;

  // Tools & app.
  static const IconData ai = LucideIcons.sparkles;
  static const IconData sun = LucideIcons.sun;
  static const IconData moon = LucideIcons.moon;
  static const IconData systemTheme = LucideIcons.smartphone;
  static const IconData keyboard = LucideIcons.keyboard;
  static const IconData licences = LucideIcons.scrollText;
  static const IconData policy = LucideIcons.shieldCheck;
}

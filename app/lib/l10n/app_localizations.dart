import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fa')];

  /// No description provided for @moduleTasks.
  ///
  /// In fa, this message translates to:
  /// **'وظایف'**
  String get moduleTasks;

  /// No description provided for @moduleProjects.
  ///
  /// In fa, this message translates to:
  /// **'پروژه‌ها'**
  String get moduleProjects;

  /// No description provided for @moduleLetters.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌ها'**
  String get moduleLetters;

  /// No description provided for @navMore.
  ///
  /// In fa, this message translates to:
  /// **'بیشتر'**
  String get navMore;

  /// No description provided for @navProfile.
  ///
  /// In fa, this message translates to:
  /// **'پروفایل'**
  String get navProfile;

  /// No description provided for @navDevices.
  ///
  /// In fa, this message translates to:
  /// **'دستگاه‌ها'**
  String get navDevices;

  /// No description provided for @navAllLetters.
  ///
  /// In fa, this message translates to:
  /// **'همه نامه‌ها'**
  String get navAllLetters;

  /// No description provided for @navAdmin.
  ///
  /// In fa, this message translates to:
  /// **'مدیریت'**
  String get navAdmin;

  /// No description provided for @signOut.
  ///
  /// In fa, this message translates to:
  /// **'خروج'**
  String get signOut;

  /// No description provided for @comingSoonTitle.
  ///
  /// In fa, this message translates to:
  /// **'به‌زودی'**
  String get comingSoonTitle;

  /// No description provided for @comingSoonMessage.
  ///
  /// In fa, this message translates to:
  /// **'این بخش به‌زودی در دسترس خواهد بود.'**
  String get comingSoonMessage;

  /// No description provided for @jalaliPickerConfirm.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get jalaliPickerConfirm;

  /// No description provided for @jalaliPickerCancel.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get jalaliPickerCancel;

  /// No description provided for @jalaliFieldHint.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب تاریخ'**
  String get jalaliFieldHint;

  /// No description provided for @jalaliFieldClear.
  ///
  /// In fa, this message translates to:
  /// **'پاک کردن تاریخ'**
  String get jalaliFieldClear;

  /// No description provided for @commonCancel.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In fa, this message translates to:
  /// **'تلاش دوباره'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره'**
  String get commonSave;

  /// No description provided for @tasksTabInbox.
  ///
  /// In fa, this message translates to:
  /// **'صندوق'**
  String get tasksTabInbox;

  /// No description provided for @tasksTabFollowup.
  ///
  /// In fa, this message translates to:
  /// **'پیگیری'**
  String get tasksTabFollowup;

  /// No description provided for @tasksTabAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get tasksTabAll;

  /// No description provided for @tasksSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی عنوان وظیفه'**
  String get tasksSearchHint;

  /// No description provided for @tasksSearchClear.
  ///
  /// In fa, this message translates to:
  /// **'پاک کردن جستجو'**
  String get tasksSearchClear;

  /// No description provided for @tasksFilterAll.
  ///
  /// In fa, this message translates to:
  /// **'همه وضعیت‌ها'**
  String get tasksFilterAll;

  /// No description provided for @tasksLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری وظایف ممکن نشد'**
  String get tasksLoadFailed;

  /// No description provided for @tasksLoadMore.
  ///
  /// In fa, this message translates to:
  /// **'نمایش بیشتر'**
  String get tasksLoadMore;

  /// No description provided for @tasksEmptyInboxTitle.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای در صندوق نیست'**
  String get tasksEmptyInboxTitle;

  /// No description provided for @tasksEmptyInboxMessage.
  ///
  /// In fa, this message translates to:
  /// **'وظایفی که باید انجام یا تأیید کنید اینجا نمایش داده می‌شوند.'**
  String get tasksEmptyInboxMessage;

  /// No description provided for @tasksEmptyFollowupTitle.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای برای پیگیری نیست'**
  String get tasksEmptyFollowupTitle;

  /// No description provided for @tasksEmptyFollowupMessage.
  ///
  /// In fa, this message translates to:
  /// **'وظایفی که ایجاد کرده‌اید یا دنبال می‌کنید اینجا نمایش داده می‌شوند.'**
  String get tasksEmptyFollowupMessage;

  /// No description provided for @tasksEmptyAllTitle.
  ///
  /// In fa, this message translates to:
  /// **'هنوز وظیفه‌ای ثبت نشده'**
  String get tasksEmptyAllTitle;

  /// No description provided for @tasksEmptyAllMessage.
  ///
  /// In fa, this message translates to:
  /// **'همه وظایفی که به شما مربوط است اینجا نمایش داده می‌شود.'**
  String get tasksEmptyAllMessage;

  /// No description provided for @tasksEmptyFilteredTitle.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای پیدا نشد'**
  String get tasksEmptyFilteredTitle;

  /// No description provided for @tasksEmptyFilteredMessage.
  ///
  /// In fa, this message translates to:
  /// **'جستجو یا فیلترها را تغییر دهید.'**
  String get tasksEmptyFilteredMessage;

  /// No description provided for @taskNew.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه جدید'**
  String get taskNew;

  /// No description provided for @taskEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش وظیفه'**
  String get taskEdit;

  /// No description provided for @taskDetailTitle.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه'**
  String get taskDetailTitle;

  /// No description provided for @taskLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری وظیفه ممکن نشد'**
  String get taskLoadFailed;

  /// No description provided for @taskStatusOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز'**
  String get taskStatusOpen;

  /// No description provided for @taskStatusAwaiting.
  ///
  /// In fa, this message translates to:
  /// **'در انتظار تأیید'**
  String get taskStatusAwaiting;

  /// No description provided for @taskStatusDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام‌شده'**
  String get taskStatusDone;

  /// No description provided for @taskStatusCancelled.
  ///
  /// In fa, this message translates to:
  /// **'لغوشده'**
  String get taskStatusCancelled;

  /// No description provided for @taskPriorityLow.
  ///
  /// In fa, this message translates to:
  /// **'کم'**
  String get taskPriorityLow;

  /// No description provided for @taskPriorityNormal.
  ///
  /// In fa, this message translates to:
  /// **'معمولی'**
  String get taskPriorityNormal;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In fa, this message translates to:
  /// **'زیاد'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityUrgent.
  ///
  /// In fa, this message translates to:
  /// **'فوری'**
  String get taskPriorityUrgent;

  /// No description provided for @taskChecklistCount.
  ///
  /// In fa, this message translates to:
  /// **'{done} از {total}'**
  String taskChecklistCount(String done, String total);

  /// No description provided for @taskCreatedBy.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد‌کننده: {name}'**
  String taskCreatedBy(String name);

  /// No description provided for @taskProgressFromChecklist.
  ///
  /// In fa, this message translates to:
  /// **'پیشرفت از روی فهرست کارها محاسبه می‌شود.'**
  String get taskProgressFromChecklist;

  /// No description provided for @taskComplete.
  ///
  /// In fa, this message translates to:
  /// **'انجام شد'**
  String get taskComplete;

  /// No description provided for @taskApprove.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get taskApprove;

  /// No description provided for @taskReject.
  ///
  /// In fa, this message translates to:
  /// **'رد'**
  String get taskReject;

  /// No description provided for @taskReopen.
  ///
  /// In fa, this message translates to:
  /// **'بازگشایی'**
  String get taskReopen;

  /// No description provided for @taskCancel.
  ///
  /// In fa, this message translates to:
  /// **'لغو وظیفه'**
  String get taskCancel;

  /// No description provided for @taskCancelConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این وظیفه لغو شود؟'**
  String get taskCancelConfirm;

  /// No description provided for @taskCancelYes.
  ///
  /// In fa, this message translates to:
  /// **'بله، لغو شود'**
  String get taskCancelYes;

  /// No description provided for @taskNoteOptional.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت (اختیاری)'**
  String get taskNoteOptional;

  /// No description provided for @taskRejectNoteRequired.
  ///
  /// In fa, this message translates to:
  /// **'دلیل رد را بنویسید'**
  String get taskRejectNoteRequired;

  /// No description provided for @taskConflict.
  ///
  /// In fa, this message translates to:
  /// **'این وظیفه همزمان توسط فرد دیگری تغییر کرده است. نسخه جدید بارگذاری شد؛ دوباره تلاش کنید.'**
  String get taskConflict;

  /// No description provided for @taskForbidden.
  ///
  /// In fa, this message translates to:
  /// **'اجازه انجام این کار را ندارید.'**
  String get taskForbidden;

  /// No description provided for @taskNotFound.
  ///
  /// In fa, this message translates to:
  /// **'این وظیفه دیگر در دسترس نیست.'**
  String get taskNotFound;

  /// No description provided for @taskActionFailed.
  ///
  /// In fa, this message translates to:
  /// **'انجام کار ممکن نشد.'**
  String get taskActionFailed;

  /// No description provided for @fieldTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get fieldTitle;

  /// No description provided for @fieldDescription.
  ///
  /// In fa, this message translates to:
  /// **'توضیحات'**
  String get fieldDescription;

  /// No description provided for @fieldPriority.
  ///
  /// In fa, this message translates to:
  /// **'اولویت'**
  String get fieldPriority;

  /// No description provided for @fieldStatus.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت'**
  String get fieldStatus;

  /// No description provided for @fieldStart.
  ///
  /// In fa, this message translates to:
  /// **'شروع'**
  String get fieldStart;

  /// No description provided for @fieldDue.
  ///
  /// In fa, this message translates to:
  /// **'سررسید'**
  String get fieldDue;

  /// No description provided for @fieldAllDay.
  ///
  /// In fa, this message translates to:
  /// **'تمام روز'**
  String get fieldAllDay;

  /// No description provided for @fieldProgress.
  ///
  /// In fa, this message translates to:
  /// **'پیشرفت'**
  String get fieldProgress;

  /// No description provided for @fieldOwners.
  ///
  /// In fa, this message translates to:
  /// **'مسئولان'**
  String get fieldOwners;

  /// No description provided for @fieldApprovers.
  ///
  /// In fa, this message translates to:
  /// **'تأییدکنندگان'**
  String get fieldApprovers;

  /// No description provided for @fieldFollowers.
  ///
  /// In fa, this message translates to:
  /// **'دنبال‌کنندگان'**
  String get fieldFollowers;

  /// No description provided for @fieldChecklist.
  ///
  /// In fa, this message translates to:
  /// **'فهرست کارها'**
  String get fieldChecklist;

  /// No description provided for @approverApproved.
  ///
  /// In fa, this message translates to:
  /// **'تأیید کرد'**
  String get approverApproved;

  /// No description provided for @approverRejected.
  ///
  /// In fa, this message translates to:
  /// **'رد کرد'**
  String get approverRejected;

  /// No description provided for @approverPending.
  ///
  /// In fa, this message translates to:
  /// **'در انتظار'**
  String get approverPending;

  /// No description provided for @approverTurn.
  ///
  /// In fa, this message translates to:
  /// **'نوبت تأیید'**
  String get approverTurn;

  /// No description provided for @checklistAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن'**
  String get checklistAdd;

  /// No description provided for @checklistAddHint.
  ///
  /// In fa, this message translates to:
  /// **'مورد جدید'**
  String get checklistAddHint;

  /// No description provided for @checklistRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف مورد'**
  String get checklistRemove;

  /// No description provided for @formTitleRequired.
  ///
  /// In fa, this message translates to:
  /// **'عنوان را وارد کنید'**
  String get formTitleRequired;

  /// No description provided for @formOwnerRequired.
  ///
  /// In fa, this message translates to:
  /// **'دست‌کم یک مسئول لازم است'**
  String get formOwnerRequired;

  /// No description provided for @formDueBeforeStart.
  ///
  /// In fa, this message translates to:
  /// **'سررسید باید بعد از شروع باشد'**
  String get formDueBeforeStart;

  /// No description provided for @labelsTitle.
  ///
  /// In fa, this message translates to:
  /// **'برچسب‌ها'**
  String get labelsTitle;

  /// No description provided for @peopleAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن'**
  String get peopleAdd;

  /// No description provided for @peopleSearch.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی همکار'**
  String get peopleSearch;

  /// No description provided for @peopleEmpty.
  ///
  /// In fa, this message translates to:
  /// **'همکاری پیدا نشد'**
  String get peopleEmpty;

  /// No description provided for @peopleRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف {name}'**
  String peopleRemove(String name);

  /// No description provided for @tabComments.
  ///
  /// In fa, this message translates to:
  /// **'نظرها'**
  String get tabComments;

  /// No description provided for @tabFiles.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌ها'**
  String get tabFiles;

  /// No description provided for @tabHistory.
  ///
  /// In fa, this message translates to:
  /// **'تاریخچه'**
  String get tabHistory;

  /// No description provided for @commentsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز نظری ثبت نشده'**
  String get commentsEmpty;

  /// No description provided for @commentHint.
  ///
  /// In fa, this message translates to:
  /// **'نظر خود را بنویسید'**
  String get commentHint;

  /// No description provided for @commentSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال'**
  String get commentSend;

  /// No description provided for @commentReply.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ'**
  String get commentReply;

  /// No description provided for @commentEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش'**
  String get commentEdit;

  /// No description provided for @commentDelete.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get commentDelete;

  /// No description provided for @commentEdited.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش‌شده'**
  String get commentEdited;

  /// No description provided for @commentEditing.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش نظر'**
  String get commentEditing;

  /// No description provided for @commentReplyingTo.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ به {name}'**
  String commentReplyingTo(String name);

  /// No description provided for @commentKindComment.
  ///
  /// In fa, this message translates to:
  /// **'نظر'**
  String get commentKindComment;

  /// No description provided for @commentKindReport.
  ///
  /// In fa, this message translates to:
  /// **'گزارش'**
  String get commentKindReport;

  /// No description provided for @commentAttachProgress.
  ///
  /// In fa, this message translates to:
  /// **'ثبت درصد پیشرفت'**
  String get commentAttachProgress;

  /// No description provided for @commentProgress.
  ///
  /// In fa, this message translates to:
  /// **'پیشرفت: {percent}٪'**
  String commentProgress(String percent);

  /// No description provided for @filesEmpty.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌ای پیوست نشده'**
  String get filesEmpty;

  /// No description provided for @fileUpload.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری پرونده'**
  String get fileUpload;

  /// No description provided for @fileDownload.
  ///
  /// In fa, this message translates to:
  /// **'دریافت'**
  String get fileDownload;

  /// No description provided for @fileDelete.
  ///
  /// In fa, this message translates to:
  /// **'حذف پرونده'**
  String get fileDelete;

  /// No description provided for @historyEmpty.
  ///
  /// In fa, this message translates to:
  /// **'تغییری ثبت نشده'**
  String get historyEmpty;

  /// No description provided for @historyNone.
  ///
  /// In fa, this message translates to:
  /// **'—'**
  String get historyNone;

  /// No description provided for @historyYes.
  ///
  /// In fa, this message translates to:
  /// **'بله'**
  String get historyYes;

  /// No description provided for @historyNo.
  ///
  /// In fa, this message translates to:
  /// **'خیر'**
  String get historyNo;

  /// No description provided for @historySystem.
  ///
  /// In fa, this message translates to:
  /// **'سیستم'**
  String get historySystem;

  /// No description provided for @historyChanged.
  ///
  /// In fa, this message translates to:
  /// **'{actor}، «{field}» را تغییر داد'**
  String historyChanged(String actor, String field);

  /// No description provided for @seenByTitle.
  ///
  /// In fa, this message translates to:
  /// **'دیده‌شده توسط'**
  String get seenByTitle;

  /// No description provided for @seenByEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز کسی ندیده است'**
  String get seenByEmpty;

  /// No description provided for @seenByFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری ممکن نشد'**
  String get seenByFailed;

  /// No description provided for @fieldProject.
  ///
  /// In fa, this message translates to:
  /// **'پروژه'**
  String get fieldProject;

  /// No description provided for @fieldColumn.
  ///
  /// In fa, this message translates to:
  /// **'ستون'**
  String get fieldColumn;

  /// No description provided for @projectNone.
  ///
  /// In fa, this message translates to:
  /// **'بدون پروژه'**
  String get projectNone;

  /// No description provided for @projectStatusActive.
  ///
  /// In fa, this message translates to:
  /// **'فعال'**
  String get projectStatusActive;

  /// No description provided for @projectStatusDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام‌شده'**
  String get projectStatusDone;

  /// No description provided for @projectStatusArchived.
  ///
  /// In fa, this message translates to:
  /// **'بایگانی‌شده'**
  String get projectStatusArchived;

  /// No description provided for @roleManager.
  ///
  /// In fa, this message translates to:
  /// **'مدیر'**
  String get roleManager;

  /// No description provided for @roleMember.
  ///
  /// In fa, this message translates to:
  /// **'عضو'**
  String get roleMember;

  /// No description provided for @roleViewer.
  ///
  /// In fa, this message translates to:
  /// **'بیننده'**
  String get roleViewer;

  /// No description provided for @sortManual.
  ///
  /// In fa, this message translates to:
  /// **'ترتیب دستی'**
  String get sortManual;

  /// No description provided for @sortCreatedAsc.
  ///
  /// In fa, this message translates to:
  /// **'قدیمی‌ترین ایجاد'**
  String get sortCreatedAsc;

  /// No description provided for @sortCreatedDesc.
  ///
  /// In fa, this message translates to:
  /// **'جدیدترین ایجاد'**
  String get sortCreatedDesc;

  /// No description provided for @sortDueAsc.
  ///
  /// In fa, this message translates to:
  /// **'سررسید نزدیک‌تر'**
  String get sortDueAsc;

  /// No description provided for @sortDueDesc.
  ///
  /// In fa, this message translates to:
  /// **'سررسید دورتر'**
  String get sortDueDesc;

  /// No description provided for @sortUpdatedAsc.
  ///
  /// In fa, this message translates to:
  /// **'قدیمی‌ترین تغییر'**
  String get sortUpdatedAsc;

  /// No description provided for @sortUpdatedDesc.
  ///
  /// In fa, this message translates to:
  /// **'جدیدترین تغییر'**
  String get sortUpdatedDesc;

  /// No description provided for @projectConflict.
  ///
  /// In fa, this message translates to:
  /// **'پروژه همزمان تغییر کرده است. دوباره تلاش کنید.'**
  String get projectConflict;

  /// No description provided for @projectNotFound.
  ///
  /// In fa, this message translates to:
  /// **'این پروژه یا مورد دیگر در دسترس نیست.'**
  String get projectNotFound;

  /// No description provided for @boardCompact.
  ///
  /// In fa, this message translates to:
  /// **'کارت فشرده'**
  String get boardCompact;

  /// No description provided for @columnAdd.
  ///
  /// In fa, this message translates to:
  /// **'ستون جدید'**
  String get columnAdd;

  /// No description provided for @columnTitleHint.
  ///
  /// In fa, this message translates to:
  /// **'عنوان ستون'**
  String get columnTitleHint;

  /// No description provided for @boardEmpty.
  ///
  /// In fa, this message translates to:
  /// **'ستونی وجود ندارد'**
  String get boardEmpty;

  /// No description provided for @columnRename.
  ///
  /// In fa, this message translates to:
  /// **'تغییر نام ستون'**
  String get columnRename;

  /// No description provided for @columnHide.
  ///
  /// In fa, this message translates to:
  /// **'پنهان کردن ستون'**
  String get columnHide;

  /// No description provided for @columnMoveEarlier.
  ///
  /// In fa, this message translates to:
  /// **'جابه‌جایی به قبل'**
  String get columnMoveEarlier;

  /// No description provided for @columnMoveLater.
  ///
  /// In fa, this message translates to:
  /// **'جابه‌جایی به بعد'**
  String get columnMoveLater;

  /// No description provided for @columnSort.
  ///
  /// In fa, this message translates to:
  /// **'مرتب‌سازی'**
  String get columnSort;

  /// No description provided for @columnMenu.
  ///
  /// In fa, this message translates to:
  /// **'گزینه‌های ستون'**
  String get columnMenu;

  /// No description provided for @boardAddTask.
  ///
  /// In fa, this message translates to:
  /// **'افزودن وظیفه'**
  String get boardAddTask;

  /// No description provided for @boardAddTaskHint.
  ///
  /// In fa, this message translates to:
  /// **'عنوان وظیفه'**
  String get boardAddTaskHint;

  /// No description provided for @projectListEmpty.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای پیدا نشد'**
  String get projectListEmpty;

  /// No description provided for @calendarPickDay.
  ///
  /// In fa, this message translates to:
  /// **'یک روز را انتخاب کنید.'**
  String get calendarPickDay;

  /// No description provided for @calendarDayEmpty.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای در این روز نیست.'**
  String get calendarDayEmpty;

  /// No description provided for @fileTypeImage.
  ///
  /// In fa, this message translates to:
  /// **'تصویر'**
  String get fileTypeImage;

  /// No description provided for @fileTypeVideo.
  ///
  /// In fa, this message translates to:
  /// **'ویدئو'**
  String get fileTypeVideo;

  /// No description provided for @fileTypeDocument.
  ///
  /// In fa, this message translates to:
  /// **'سند'**
  String get fileTypeDocument;

  /// No description provided for @projectFilesUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌های پروژه هنوز در دسترس نیست.'**
  String get projectFilesUnavailable;

  /// No description provided for @filesSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی نام پرونده'**
  String get filesSearchHint;

  /// No description provided for @projectArchive.
  ///
  /// In fa, this message translates to:
  /// **'بایگانی پروژه'**
  String get projectArchive;

  /// No description provided for @projectArchiveConfirm.
  ///
  /// In fa, this message translates to:
  /// **'پروژه بایگانی شود؟ دیگر وظیفه جدیدی نمی‌پذیرد.'**
  String get projectArchiveConfirm;

  /// No description provided for @projectCopy.
  ///
  /// In fa, this message translates to:
  /// **'کپی پروژه'**
  String get projectCopy;

  /// No description provided for @projectCopyUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'کپی پروژه روی این سرور در دسترس نیست.'**
  String get projectCopyUnavailable;

  /// No description provided for @projectEnd.
  ///
  /// In fa, this message translates to:
  /// **'پایان'**
  String get projectEnd;

  /// No description provided for @projectMembers.
  ///
  /// In fa, this message translates to:
  /// **'اعضا'**
  String get projectMembers;

  /// No description provided for @projectEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش پروژه'**
  String get projectEdit;

  /// No description provided for @projectMarkDone.
  ///
  /// In fa, this message translates to:
  /// **'پایان پروژه'**
  String get projectMarkDone;

  /// No description provided for @projectReactivate.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی دوباره'**
  String get projectReactivate;

  /// No description provided for @projectTabBoard.
  ///
  /// In fa, this message translates to:
  /// **'برد'**
  String get projectTabBoard;

  /// No description provided for @projectTabList.
  ///
  /// In fa, this message translates to:
  /// **'فهرست'**
  String get projectTabList;

  /// No description provided for @projectTabCalendar.
  ///
  /// In fa, this message translates to:
  /// **'تقویم'**
  String get projectTabCalendar;

  /// No description provided for @projectTabFiles.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌ها'**
  String get projectTabFiles;

  /// No description provided for @projectTabMembers.
  ///
  /// In fa, this message translates to:
  /// **'اعضا و تنظیمات'**
  String get projectTabMembers;

  /// No description provided for @projectTabChat.
  ///
  /// In fa, this message translates to:
  /// **'گفتگو'**
  String get projectTabChat;

  /// No description provided for @projectLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری پروژه ممکن نشد'**
  String get projectLoadFailed;

  /// No description provided for @projectNew.
  ///
  /// In fa, this message translates to:
  /// **'پروژه جدید'**
  String get projectNew;

  /// No description provided for @projectName.
  ///
  /// In fa, this message translates to:
  /// **'نام پروژه'**
  String get projectName;

  /// No description provided for @projectNameRequired.
  ///
  /// In fa, this message translates to:
  /// **'نام پروژه را وارد کنید'**
  String get projectNameRequired;

  /// No description provided for @projectEndBeforeStart.
  ///
  /// In fa, this message translates to:
  /// **'پایان باید بعد از شروع باشد'**
  String get projectEndBeforeStart;

  /// No description provided for @projectGroup.
  ///
  /// In fa, this message translates to:
  /// **'گروه'**
  String get projectGroup;

  /// No description provided for @projectColor.
  ///
  /// In fa, this message translates to:
  /// **'رنگ'**
  String get projectColor;

  /// No description provided for @groupNew.
  ///
  /// In fa, this message translates to:
  /// **'گروه جدید'**
  String get groupNew;

  /// No description provided for @groupNameHint.
  ///
  /// In fa, this message translates to:
  /// **'نام گروه'**
  String get groupNameHint;

  /// No description provided for @groupScopeTitle.
  ///
  /// In fa, this message translates to:
  /// **'نوع گروه'**
  String get groupScopeTitle;

  /// No description provided for @groupScopeOrg.
  ///
  /// In fa, this message translates to:
  /// **'گروه سازمان'**
  String get groupScopeOrg;

  /// No description provided for @groupScopePersonal.
  ///
  /// In fa, this message translates to:
  /// **'گروه شخصی'**
  String get groupScopePersonal;

  /// No description provided for @groupRename.
  ///
  /// In fa, this message translates to:
  /// **'تغییر نام گروه'**
  String get groupRename;

  /// No description provided for @groupsTitle.
  ///
  /// In fa, this message translates to:
  /// **'گروه‌های پروژه'**
  String get groupsTitle;

  /// No description provided for @groupsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'گروهی وجود ندارد'**
  String get groupsEmpty;

  /// No description provided for @groupDeactivate.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال‌سازی گروه'**
  String get groupDeactivate;

  /// No description provided for @groupActivate.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی گروه'**
  String get groupActivate;

  /// No description provided for @projectsSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی پروژه'**
  String get projectsSearchHint;

  /// No description provided for @projectsLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری پروژه‌ها ممکن نشد'**
  String get projectsLoadFailed;

  /// No description provided for @projectsEmptyFilteredTitle.
  ///
  /// In fa, this message translates to:
  /// **'پروژه‌ای پیدا نشد'**
  String get projectsEmptyFilteredTitle;

  /// No description provided for @projectsEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'هنوز پروژه‌ای ندارید'**
  String get projectsEmptyTitle;

  /// No description provided for @projectsEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'پروژه‌هایی که عضو آن هستید اینجا نمایش داده می‌شوند.'**
  String get projectsEmptyMessage;

  /// No description provided for @projectsUngrouped.
  ///
  /// In fa, this message translates to:
  /// **'بدون گروه'**
  String get projectsUngrouped;

  /// No description provided for @labelNew.
  ///
  /// In fa, this message translates to:
  /// **'برچسب جدید'**
  String get labelNew;

  /// No description provided for @labelEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش برچسب'**
  String get labelEdit;

  /// No description provided for @labelName.
  ///
  /// In fa, this message translates to:
  /// **'نام برچسب'**
  String get labelName;

  /// No description provided for @labelDuplicate.
  ///
  /// In fa, this message translates to:
  /// **'برچسبی با این نام وجود دارد.'**
  String get labelDuplicate;

  /// No description provided for @labelScopeOrg.
  ///
  /// In fa, this message translates to:
  /// **'برچسب سازمان (برای همه)'**
  String get labelScopeOrg;

  /// No description provided for @labelsLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری برچسب‌ها ممکن نشد'**
  String get labelsLoadFailed;

  /// No description provided for @labelsOrgTitle.
  ///
  /// In fa, this message translates to:
  /// **'برچسب‌های سازمان'**
  String get labelsOrgTitle;

  /// No description provided for @labelsPersonalTitle.
  ///
  /// In fa, this message translates to:
  /// **'برچسب‌های من'**
  String get labelsPersonalTitle;

  /// No description provided for @labelsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'برچسبی وجود ندارد'**
  String get labelsEmpty;

  /// No description provided for @labelDeactivate.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال‌سازی برچسب'**
  String get labelDeactivate;

  /// No description provided for @labelActivate.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی برچسب'**
  String get labelActivate;

  /// No description provided for @navLabels.
  ///
  /// In fa, this message translates to:
  /// **'برچسب‌ها'**
  String get navLabels;

  /// No description provided for @remindersTitle.
  ///
  /// In fa, this message translates to:
  /// **'یادآوری‌های من'**
  String get remindersTitle;

  /// No description provided for @reminderAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن یادآوری'**
  String get reminderAdd;

  /// No description provided for @remindersEmpty.
  ///
  /// In fa, this message translates to:
  /// **'یادآوری‌ای ثبت نشده'**
  String get remindersEmpty;

  /// No description provided for @reminderRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف یادآوری'**
  String get reminderRemove;

  /// No description provided for @reminderWhen.
  ///
  /// In fa, this message translates to:
  /// **'زمان یادآوری'**
  String get reminderWhen;

  /// No description provided for @reminderDateRequired.
  ///
  /// In fa, this message translates to:
  /// **'یک تاریخ و ساعت در آینده انتخاب کنید'**
  String get reminderDateRequired;

  /// No description provided for @reminderRepeat.
  ///
  /// In fa, this message translates to:
  /// **'تکرار'**
  String get reminderRepeat;

  /// No description provided for @reminderOnce.
  ///
  /// In fa, this message translates to:
  /// **'یک‌بار'**
  String get reminderOnce;

  /// No description provided for @reminderDaily.
  ///
  /// In fa, this message translates to:
  /// **'روزانه'**
  String get reminderDaily;

  /// No description provided for @reminderWeekly.
  ///
  /// In fa, this message translates to:
  /// **'هفتگی'**
  String get reminderWeekly;

  /// No description provided for @reminderMonthly.
  ///
  /// In fa, this message translates to:
  /// **'ماهانه'**
  String get reminderMonthly;

  /// No description provided for @taskMove.
  ///
  /// In fa, this message translates to:
  /// **'انتقال'**
  String get taskMove;

  /// No description provided for @taskCopy.
  ///
  /// In fa, this message translates to:
  /// **'کپی'**
  String get taskCopy;

  /// No description provided for @taskCopied.
  ///
  /// In fa, this message translates to:
  /// **'نسخه‌ای از وظیفه ساخته شد.'**
  String get taskCopied;

  /// No description provided for @taskNoProject.
  ///
  /// In fa, this message translates to:
  /// **'این وظیفه در هیچ پروژه‌ای نیست.'**
  String get taskNoProject;

  /// No description provided for @percentValue.
  ///
  /// In fa, this message translates to:
  /// **'{p}٪'**
  String percentValue(String p);

  /// No description provided for @projectCopyName.
  ///
  /// In fa, this message translates to:
  /// **'{name} (کپی)'**
  String projectCopyName(String name);

  /// No description provided for @projectCopied.
  ///
  /// In fa, this message translates to:
  /// **'پروژه «{name}» ساخته شد.'**
  String projectCopied(String name);

  /// No description provided for @sizeBytes.
  ///
  /// In fa, this message translates to:
  /// **'{n} بایت'**
  String sizeBytes(String n);

  /// No description provided for @sizeKilobytes.
  ///
  /// In fa, this message translates to:
  /// **'{n} کیلوبایت'**
  String sizeKilobytes(String n);

  /// No description provided for @sizeMegabytes.
  ///
  /// In fa, this message translates to:
  /// **'{n} مگابایت'**
  String sizeMegabytes(String n);

  /// No description provided for @reminderMonthDay.
  ///
  /// In fa, this message translates to:
  /// **'روز {day}'**
  String reminderMonthDay(String day);

  /// No description provided for @lettersBoxInbox.
  ///
  /// In fa, this message translates to:
  /// **'دریافتی'**
  String get lettersBoxInbox;

  /// No description provided for @lettersBoxOutbox.
  ///
  /// In fa, this message translates to:
  /// **'ارسالی'**
  String get lettersBoxOutbox;

  /// No description provided for @lettersBoxArchive.
  ///
  /// In fa, this message translates to:
  /// **'بایگانی'**
  String get lettersBoxArchive;

  /// No description provided for @lettersBoxAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get lettersBoxAll;

  /// No description provided for @lettersSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی عنوان نامه'**
  String get lettersSearchHint;

  /// No description provided for @lettersSearchClear.
  ///
  /// In fa, this message translates to:
  /// **'پاک کردن جستجو'**
  String get lettersSearchClear;

  /// No description provided for @lettersAdvancedSearch.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی پیشرفته'**
  String get lettersAdvancedSearch;

  /// No description provided for @lettersLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری نامه‌ها ممکن نشد'**
  String get lettersLoadFailed;

  /// No description provided for @lettersEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌ای وجود ندارد'**
  String get lettersEmptyTitle;

  /// No description provided for @lettersEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌هایی که می‌نویسید یا برای شما ارسال می‌شود اینجا نمایش داده می‌شود.'**
  String get lettersEmptyMessage;

  /// No description provided for @lettersNoMatchTitle.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌ای پیدا نشد'**
  String get lettersNoMatchTitle;

  /// No description provided for @lettersNoMatchMessage.
  ///
  /// In fa, this message translates to:
  /// **'جستجو یا فیلترها را تغییر دهید.'**
  String get lettersNoMatchMessage;

  /// No description provided for @lettersNew.
  ///
  /// In fa, this message translates to:
  /// **'نامه جدید'**
  String get lettersNew;

  /// No description provided for @lettersCreatedByYou.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد شده توسط شما'**
  String get lettersCreatedByYou;

  /// No description provided for @lettersSharedWithYou.
  ///
  /// In fa, this message translates to:
  /// **'ارسال شده برای شما'**
  String get lettersSharedWithYou;

  /// No description provided for @lettersPublic.
  ///
  /// In fa, this message translates to:
  /// **'عمومی'**
  String get lettersPublic;

  /// No description provided for @lettersPrivate.
  ///
  /// In fa, this message translates to:
  /// **'خصوصی'**
  String get lettersPrivate;

  /// No description provided for @lettersArchive.
  ///
  /// In fa, this message translates to:
  /// **'بایگانی کردن'**
  String get lettersArchive;

  /// No description provided for @lettersUnarchive.
  ///
  /// In fa, this message translates to:
  /// **'خروج از بایگانی'**
  String get lettersUnarchive;

  /// No description provided for @lettersEditLabels.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش برچسب‌ها'**
  String get lettersEditLabels;

  /// No description provided for @lettersNoLabels.
  ///
  /// In fa, this message translates to:
  /// **'هنوز برچسبی تعریف نشده است.'**
  String get lettersNoLabels;

  /// No description provided for @lettersMenu.
  ///
  /// In fa, this message translates to:
  /// **'گزینه‌ها'**
  String get lettersMenu;

  /// No description provided for @lettersSecretariat.
  ///
  /// In fa, this message translates to:
  /// **'دبیرخانه'**
  String get lettersSecretariat;

  /// No description provided for @lettersReferralCount.
  ///
  /// In fa, this message translates to:
  /// **'{n} ارجاع'**
  String lettersReferralCount(String n);

  /// No description provided for @lettersSearchText.
  ///
  /// In fa, this message translates to:
  /// **'متن جستجو'**
  String get lettersSearchText;

  /// No description provided for @lettersSearchStatus.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت'**
  String get lettersSearchStatus;

  /// No description provided for @lettersSearchAnyStatus.
  ///
  /// In fa, this message translates to:
  /// **'همه وضعیت‌ها'**
  String get lettersSearchAnyStatus;

  /// No description provided for @lettersSearchLabel.
  ///
  /// In fa, this message translates to:
  /// **'برچسب'**
  String get lettersSearchLabel;

  /// No description provided for @lettersSearchNumber.
  ///
  /// In fa, this message translates to:
  /// **'شماره نامه'**
  String get lettersSearchNumber;

  /// No description provided for @lettersSearchCreator.
  ///
  /// In fa, this message translates to:
  /// **'نویسنده'**
  String get lettersSearchCreator;

  /// No description provided for @lettersSearchSigner.
  ///
  /// In fa, this message translates to:
  /// **'امضاکننده'**
  String get lettersSearchSigner;

  /// No description provided for @lettersSearchFrom.
  ///
  /// In fa, this message translates to:
  /// **'از تاریخ'**
  String get lettersSearchFrom;

  /// No description provided for @lettersSearchTo.
  ///
  /// In fa, this message translates to:
  /// **'تا تاریخ'**
  String get lettersSearchTo;

  /// No description provided for @lettersSearchReset.
  ///
  /// In fa, this message translates to:
  /// **'پاک کردن'**
  String get lettersSearchReset;

  /// No description provided for @lettersSearchApply.
  ///
  /// In fa, this message translates to:
  /// **'اعمال'**
  String get lettersSearchApply;

  /// No description provided for @letterStatusDraft.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نویس'**
  String get letterStatusDraft;

  /// No description provided for @letterStatusInSigning.
  ///
  /// In fa, this message translates to:
  /// **'در حال امضا'**
  String get letterStatusInSigning;

  /// No description provided for @letterStatusPublished.
  ///
  /// In fa, this message translates to:
  /// **'منتشرشده'**
  String get letterStatusPublished;

  /// No description provided for @letterStatusRejected.
  ///
  /// In fa, this message translates to:
  /// **'ردشده'**
  String get letterStatusRejected;

  /// No description provided for @letterStatusCancelled.
  ///
  /// In fa, this message translates to:
  /// **'لغوشده'**
  String get letterStatusCancelled;

  /// No description provided for @letterTitle.
  ///
  /// In fa, this message translates to:
  /// **'نامه {no}'**
  String letterTitle(String no);

  /// No description provided for @letterLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری نامه ممکن نشد'**
  String get letterLoadFailed;

  /// No description provided for @paperTooltip.
  ///
  /// In fa, this message translates to:
  /// **'کاغذ / چاپ'**
  String get paperTooltip;

  /// No description provided for @certTooltip.
  ///
  /// In fa, this message translates to:
  /// **'گواهی امضا'**
  String get certTooltip;

  /// No description provided for @letterAttachments.
  ///
  /// In fa, this message translates to:
  /// **'پیوست‌ها'**
  String get letterAttachments;

  /// No description provided for @letterFileCount.
  ///
  /// In fa, this message translates to:
  /// **'{n} پرونده'**
  String letterFileCount(String n);

  /// No description provided for @letterSigning.
  ///
  /// In fa, this message translates to:
  /// **'امضا'**
  String get letterSigning;

  /// No description provided for @letterSerial.
  ///
  /// In fa, this message translates to:
  /// **'امضاکنندگان یکی پس از دیگری امضا می‌کنند'**
  String get letterSerial;

  /// No description provided for @letterParallel.
  ///
  /// In fa, this message translates to:
  /// **'امضاکنندگان به هر ترتیب می‌توانند امضا کنند'**
  String get letterParallel;

  /// No description provided for @letterViewers.
  ///
  /// In fa, this message translates to:
  /// **'بینندگان'**
  String get letterViewers;

  /// No description provided for @letterChained.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌های زنجیره‌ای'**
  String get letterChained;

  /// No description provided for @letterCustomers.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌های مشتری'**
  String get letterCustomers;

  /// No description provided for @letterUnlisted.
  ///
  /// In fa, this message translates to:
  /// **'فهرست‌نشده'**
  String get letterUnlisted;

  /// No description provided for @letterArchived.
  ///
  /// In fa, this message translates to:
  /// **'بایگانی‌شده'**
  String get letterArchived;

  /// No description provided for @letterCreatedSent.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد: {created}{sent}'**
  String letterCreatedSent(String created, String sent);

  /// No description provided for @letterSent.
  ///
  /// In fa, this message translates to:
  /// **'ارسال: {date}'**
  String letterSent(String date);

  /// No description provided for @letterRepliesTo.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ به نامه‌ای قبلی'**
  String get letterRepliesTo;

  /// No description provided for @letterYourTurn.
  ///
  /// In fa, this message translates to:
  /// **'امضای شما روی این نامه لازم است.'**
  String get letterYourTurn;

  /// No description provided for @letterNoText.
  ///
  /// In fa, this message translates to:
  /// **'(بدون متن)'**
  String get letterNoText;

  /// No description provided for @letterNoSigners.
  ///
  /// In fa, this message translates to:
  /// **'امضاکننده‌ای نیست'**
  String get letterNoSigners;

  /// No description provided for @letterRelist.
  ///
  /// In fa, this message translates to:
  /// **'فهرست کردن'**
  String get letterRelist;

  /// No description provided for @letterUnlist.
  ///
  /// In fa, this message translates to:
  /// **'حذف از فهرست'**
  String get letterUnlist;

  /// No description provided for @letterCancel.
  ///
  /// In fa, this message translates to:
  /// **'لغو نامه'**
  String get letterCancel;

  /// No description provided for @letterReply.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ با نامه'**
  String get letterReply;

  /// No description provided for @letterSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال'**
  String get letterSend;

  /// No description provided for @letterSign.
  ///
  /// In fa, this message translates to:
  /// **'امضا'**
  String get letterSign;

  /// No description provided for @letterAttachmentFallback.
  ///
  /// In fa, this message translates to:
  /// **'پیوست'**
  String get letterAttachmentFallback;

  /// No description provided for @decisionApproved.
  ///
  /// In fa, this message translates to:
  /// **'تأیید شد'**
  String get decisionApproved;

  /// No description provided for @decisionRejected.
  ///
  /// In fa, this message translates to:
  /// **'رد شد'**
  String get decisionRejected;

  /// No description provided for @decisionPending.
  ///
  /// In fa, this message translates to:
  /// **'در انتظار'**
  String get decisionPending;

  /// No description provided for @decisionOpened.
  ///
  /// In fa, this message translates to:
  /// **'باز کرده'**
  String get decisionOpened;

  /// No description provided for @decisionApprove.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get decisionApprove;

  /// No description provided for @decisionReject.
  ///
  /// In fa, this message translates to:
  /// **'رد'**
  String get decisionReject;

  /// No description provided for @signMethodPin.
  ///
  /// In fa, this message translates to:
  /// **'رمز'**
  String get signMethodPin;

  /// No description provided for @signMethodBiometric.
  ///
  /// In fa, this message translates to:
  /// **'زیست‌سنجی'**
  String get signMethodBiometric;

  /// No description provided for @paraphTitle.
  ///
  /// In fa, this message translates to:
  /// **'پاراف'**
  String get paraphTitle;

  /// No description provided for @paraphNone.
  ///
  /// In fa, this message translates to:
  /// **'هنوز پارافی ثبت نشده است.'**
  String get paraphNone;

  /// No description provided for @paraphAction.
  ///
  /// In fa, this message translates to:
  /// **'پاراف'**
  String get paraphAction;

  /// No description provided for @paraphExplain.
  ///
  /// In fa, this message translates to:
  /// **'پاراف مهر می‌شود و برای هر نفر یک بار ثبت می‌شود.'**
  String get paraphExplain;

  /// No description provided for @paraphReason.
  ///
  /// In fa, this message translates to:
  /// **'پاراف نامه: {title}'**
  String paraphReason(String title);

  /// No description provided for @referralTitle.
  ///
  /// In fa, this message translates to:
  /// **'ارجاعات'**
  String get referralTitle;

  /// No description provided for @referralRefer.
  ///
  /// In fa, this message translates to:
  /// **'ارجاع'**
  String get referralRefer;

  /// No description provided for @referralEmpty.
  ///
  /// In fa, this message translates to:
  /// **'این نامه ارجاعی ندارد.'**
  String get referralEmpty;

  /// No description provided for @referralSheetTitle.
  ///
  /// In fa, this message translates to:
  /// **'ارجاع به'**
  String get referralSheetTitle;

  /// No description provided for @referralNoteOptional.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت (اختیاری)'**
  String get referralNoteOptional;

  /// No description provided for @referralSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال ارجاع'**
  String get referralSend;

  /// No description provided for @referralMarkDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام شد'**
  String get referralMarkDone;

  /// No description provided for @referralMarkDeclined.
  ///
  /// In fa, this message translates to:
  /// **'رد ارجاع'**
  String get referralMarkDeclined;

  /// No description provided for @referralDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام شد'**
  String get referralDone;

  /// No description provided for @referralDeclined.
  ///
  /// In fa, this message translates to:
  /// **'ردشده'**
  String get referralDeclined;

  /// No description provided for @referralPending.
  ///
  /// In fa, this message translates to:
  /// **'در انتظار'**
  String get referralPending;

  /// No description provided for @referralFromTo.
  ///
  /// In fa, this message translates to:
  /// **'{from} به {to}'**
  String referralFromTo(String from, String to);

  /// No description provided for @referralAnswer.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ'**
  String get referralAnswer;

  /// No description provided for @letterTasksTitle.
  ///
  /// In fa, this message translates to:
  /// **'وظایف مرتبط'**
  String get letterTasksTitle;

  /// No description provided for @letterTaskLink.
  ///
  /// In fa, this message translates to:
  /// **'پیوند وظیفه'**
  String get letterTaskLink;

  /// No description provided for @letterTaskCreate.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد وظیفه'**
  String get letterTaskCreate;

  /// No description provided for @letterTaskUnlink.
  ///
  /// In fa, this message translates to:
  /// **'جدا کردن وظیفه'**
  String get letterTaskUnlink;

  /// No description provided for @letterTasksEmpty.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای به این نامه وصل نشده است.'**
  String get letterTasksEmpty;

  /// No description provided for @letterTaskPickerEmpty.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای پیدا نشد.'**
  String get letterTaskPickerEmpty;

  /// No description provided for @letterTaskTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیگیری نامه: {title}'**
  String letterTaskTitle(String title);

  /// No description provided for @letterTaskDescription.
  ///
  /// In fa, this message translates to:
  /// **'مربوط به نامه {number}: {title}'**
  String letterTaskDescription(String number, String title);

  /// No description provided for @certVerified.
  ///
  /// In fa, this message translates to:
  /// **'امضاها تأیید شد'**
  String get certVerified;

  /// No description provided for @certFailed.
  ///
  /// In fa, this message translates to:
  /// **'تأیید امضاها ناموفق بود'**
  String get certFailed;

  /// No description provided for @certNoSignatures.
  ///
  /// In fa, this message translates to:
  /// **'هنوز امضایی نیست'**
  String get certNoSignatures;

  /// No description provided for @certParaphsVerified.
  ///
  /// In fa, this message translates to:
  /// **'پاراف‌ها تأیید شد'**
  String get certParaphsVerified;

  /// No description provided for @certParaphsFailed.
  ///
  /// In fa, this message translates to:
  /// **'تأیید پاراف‌ها ناموفق بود'**
  String get certParaphsFailed;

  /// No description provided for @certDevice.
  ///
  /// In fa, this message translates to:
  /// **'دستگاه {device}'**
  String certDevice(String device);

  /// No description provided for @certValid.
  ///
  /// In fa, this message translates to:
  /// **'معتبر'**
  String get certValid;

  /// No description provided for @certInvalid.
  ///
  /// In fa, this message translates to:
  /// **'نامعتبر'**
  String get certInvalid;

  /// No description provided for @commonClose.
  ///
  /// In fa, this message translates to:
  /// **'بستن'**
  String get commonClose;

  /// No description provided for @signTitle.
  ///
  /// In fa, this message translates to:
  /// **'امضای نامه'**
  String get signTitle;

  /// No description provided for @signHow.
  ///
  /// In fa, this message translates to:
  /// **'چگونه امضا می‌کنید؟'**
  String get signHow;

  /// No description provided for @signDecision.
  ///
  /// In fa, this message translates to:
  /// **'تصمیم شما'**
  String get signDecision;

  /// No description provided for @signApproveHint.
  ///
  /// In fa, this message translates to:
  /// **'با این نامه موافقم'**
  String get signApproveHint;

  /// No description provided for @signRejectHint.
  ///
  /// In fa, this message translates to:
  /// **'موافق نیستم'**
  String get signRejectHint;

  /// No description provided for @signRejectFinal.
  ///
  /// In fa, this message translates to:
  /// **'رد کردن قطعی است. نویسنده می‌تواند نامه زنجیره‌ای جدید بنویسد.'**
  String get signRejectFinal;

  /// No description provided for @signNoteOptional.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت (اختیاری)'**
  String get signNoteOptional;

  /// No description provided for @signProgress.
  ///
  /// In fa, this message translates to:
  /// **'{signed} از {total} امضا شده'**
  String signProgress(String signed, String total);

  /// No description provided for @signReasonApprove.
  ///
  /// In fa, this message translates to:
  /// **'تأیید: {title}'**
  String signReasonApprove(String title);

  /// No description provided for @signReasonReject.
  ///
  /// In fa, this message translates to:
  /// **'رد: {title}'**
  String signReasonReject(String title);

  /// No description provided for @signPinInvalid.
  ///
  /// In fa, this message translates to:
  /// **'۶ رقم وارد کنید'**
  String get signPinInvalid;

  /// No description provided for @signPinLabel.
  ///
  /// In fa, this message translates to:
  /// **'رمز امضا'**
  String get signPinLabel;

  /// No description provided for @signBiometricFailed.
  ///
  /// In fa, this message translates to:
  /// **'تأیید اثر انگشت یا چهره ناموفق بود'**
  String get signBiometricFailed;

  /// No description provided for @signDeclined.
  ///
  /// In fa, this message translates to:
  /// **'{device} رد کرد. به‌جای آن رمز خود را وارد کنید.'**
  String signDeclined(String device);

  /// No description provided for @signExpired.
  ///
  /// In fa, this message translates to:
  /// **'درخواست منقضی شد. به‌جای آن رمز خود را وارد کنید.'**
  String get signExpired;

  /// No description provided for @signCancelled.
  ///
  /// In fa, this message translates to:
  /// **'درخواست لغو شد.'**
  String get signCancelled;

  /// No description provided for @signNoAnswer.
  ///
  /// In fa, this message translates to:
  /// **'{device} پاسخ نداد. به‌جای آن رمز خود را وارد کنید.'**
  String signNoAnswer(String device);

  /// No description provided for @signBusy.
  ///
  /// In fa, this message translates to:
  /// **'در حال امضا...'**
  String get signBusy;

  /// No description provided for @signWithPin.
  ///
  /// In fa, this message translates to:
  /// **'امضا با رمز'**
  String get signWithPin;

  /// No description provided for @signOrBiometric.
  ///
  /// In fa, this message translates to:
  /// **'یا با زیست‌سنجی تأیید کنید'**
  String get signOrBiometric;

  /// No description provided for @signFingerprint.
  ///
  /// In fa, this message translates to:
  /// **'اثر انگشت / چهره'**
  String get signFingerprint;

  /// No description provided for @signEnableBiometric.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی اثر انگشت / چهره'**
  String get signEnableBiometric;

  /// No description provided for @signAskDevice.
  ///
  /// In fa, this message translates to:
  /// **'تأیید با {device} من'**
  String signAskDevice(String device);

  /// No description provided for @signWaiting.
  ///
  /// In fa, this message translates to:
  /// **'در انتظار تأیید روی {device}'**
  String signWaiting(String device);

  /// No description provided for @signWaitingHint.
  ///
  /// In fa, this message translates to:
  /// **'برنامه را آنجا باز کنید و با اثر انگشت یا چهره تأیید کنید. درخواست پس از ۵ دقیقه منقضی می‌شود.'**
  String get signWaitingHint;

  /// No description provided for @paperNumber.
  ///
  /// In fa, this message translates to:
  /// **'شماره: {number}'**
  String paperNumber(String number);

  /// No description provided for @paperDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ: {date}'**
  String paperDate(String date);

  /// No description provided for @paperSubject.
  ///
  /// In fa, this message translates to:
  /// **'موضوع: {title}'**
  String paperSubject(String title);

  /// No description provided for @paperDecisionApproved.
  ///
  /// In fa, this message translates to:
  /// **'تصمیم: تأیید'**
  String get paperDecisionApproved;

  /// No description provided for @paperDecisionRejected.
  ///
  /// In fa, this message translates to:
  /// **'تصمیم: رد'**
  String get paperDecisionRejected;

  /// No description provided for @paperDocumentId.
  ///
  /// In fa, this message translates to:
  /// **'شناسه سند: {id}'**
  String paperDocumentId(String id);

  /// No description provided for @paperSeal.
  ///
  /// In fa, this message translates to:
  /// **'مهر سرور: {seal}'**
  String paperSeal(String seal);

  /// No description provided for @paperParaphs.
  ///
  /// In fa, this message translates to:
  /// **'پاراف‌ها'**
  String get paperParaphs;

  /// No description provided for @paperPrintFailed.
  ///
  /// In fa, this message translates to:
  /// **'چاپ ممکن نشد: {error}'**
  String paperPrintFailed(String error);

  /// No description provided for @paperPreviewTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نمایش کاغذ'**
  String get paperPreviewTitle;

  /// No description provided for @paperPrint.
  ///
  /// In fa, this message translates to:
  /// **'چاپ / ذخیره PDF'**
  String get paperPrint;

  /// No description provided for @secretariatAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get secretariatAll;

  /// No description provided for @secretariatIn.
  ///
  /// In fa, this message translates to:
  /// **'وارده'**
  String get secretariatIn;

  /// No description provided for @secretariatOut.
  ///
  /// In fa, this message translates to:
  /// **'صادره'**
  String get secretariatOut;

  /// No description provided for @secretariatAnyYear.
  ///
  /// In fa, this message translates to:
  /// **'همه سال‌ها'**
  String get secretariatAnyYear;

  /// No description provided for @secretariatSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجو در دبیرخانه'**
  String get secretariatSearchHint;

  /// No description provided for @secretariatLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری دفتر دبیرخانه ممکن نشد'**
  String get secretariatLoadFailed;

  /// No description provided for @secretariatEmpty.
  ///
  /// In fa, this message translates to:
  /// **'موردی ثبت نشده است'**
  String get secretariatEmpty;

  /// No description provided for @secretariatRegister.
  ///
  /// In fa, this message translates to:
  /// **'ثبت نامه'**
  String get secretariatRegister;

  /// No description provided for @secretariatFrom.
  ///
  /// In fa, this message translates to:
  /// **'فرستنده'**
  String get secretariatFrom;

  /// No description provided for @secretariatTo.
  ///
  /// In fa, this message translates to:
  /// **'گیرنده'**
  String get secretariatTo;

  /// No description provided for @secretariatEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش'**
  String get secretariatEdit;

  /// No description provided for @secretariatTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get secretariatTitle;

  /// No description provided for @secretariatTitleRequired.
  ///
  /// In fa, this message translates to:
  /// **'عنوان را وارد کنید'**
  String get secretariatTitleRequired;

  /// No description provided for @secretariatPartyFrom.
  ///
  /// In fa, this message translates to:
  /// **'نام فرستنده'**
  String get secretariatPartyFrom;

  /// No description provided for @secretariatPartyTo.
  ///
  /// In fa, this message translates to:
  /// **'نام گیرنده'**
  String get secretariatPartyTo;

  /// No description provided for @secretariatPartyRef.
  ///
  /// In fa, this message translates to:
  /// **'شماره یا ارجاع طرف مقابل'**
  String get secretariatPartyRef;

  /// No description provided for @secretariatSummary.
  ///
  /// In fa, this message translates to:
  /// **'خلاصه'**
  String get secretariatSummary;

  /// No description provided for @secretariatPickLetter.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب نامه موجود (اختیاری)'**
  String get secretariatPickLetter;

  /// No description provided for @secretariatRegisteredBy.
  ///
  /// In fa, this message translates to:
  /// **'ثبت‌کننده: {name}'**
  String secretariatRegisteredBy(String name);

  /// No description provided for @secretariatDetailTitle.
  ///
  /// In fa, this message translates to:
  /// **'مورد دبیرخانه'**
  String get secretariatDetailTitle;

  /// No description provided for @secretariatOpenLetter.
  ///
  /// In fa, this message translates to:
  /// **'باز کردن نامه'**
  String get secretariatOpenLetter;

  /// No description provided for @moduleMeetings.
  ///
  /// In fa, this message translates to:
  /// **'جلسات'**
  String get moduleMeetings;

  /// No description provided for @meetingStatusDraft.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نویس'**
  String get meetingStatusDraft;

  /// No description provided for @meetingStatusScheduled.
  ///
  /// In fa, this message translates to:
  /// **'برنامه‌ریزی‌شده'**
  String get meetingStatusScheduled;

  /// No description provided for @meetingStatusHeld.
  ///
  /// In fa, this message translates to:
  /// **'برگزارشده'**
  String get meetingStatusHeld;

  /// No description provided for @meetingStatusClosed.
  ///
  /// In fa, this message translates to:
  /// **'بسته‌شده'**
  String get meetingStatusClosed;

  /// No description provided for @meetingStatusCancelled.
  ///
  /// In fa, this message translates to:
  /// **'لغوشده'**
  String get meetingStatusCancelled;

  /// No description provided for @meetingKindOrganizational.
  ///
  /// In fa, this message translates to:
  /// **'سازمانی'**
  String get meetingKindOrganizational;

  /// No description provided for @meetingKindSimple.
  ///
  /// In fa, this message translates to:
  /// **'ساده'**
  String get meetingKindSimple;

  /// No description provided for @meetingKindAny.
  ///
  /// In fa, this message translates to:
  /// **'همه انواع'**
  String get meetingKindAny;

  /// No description provided for @meetingRoleChair.
  ///
  /// In fa, this message translates to:
  /// **'رئیس جلسه'**
  String get meetingRoleChair;

  /// No description provided for @meetingRoleSecretary.
  ///
  /// In fa, this message translates to:
  /// **'دبیر'**
  String get meetingRoleSecretary;

  /// No description provided for @meetingRoleMember.
  ///
  /// In fa, this message translates to:
  /// **'عضو'**
  String get meetingRoleMember;

  /// No description provided for @meetingRoleGuest.
  ///
  /// In fa, this message translates to:
  /// **'مهمان'**
  String get meetingRoleGuest;

  /// No description provided for @meetingAttendancePresent.
  ///
  /// In fa, this message translates to:
  /// **'حاضر'**
  String get meetingAttendancePresent;

  /// No description provided for @meetingAttendanceAbsent.
  ///
  /// In fa, this message translates to:
  /// **'غایب'**
  String get meetingAttendanceAbsent;

  /// No description provided for @meetingAttendanceExcused.
  ///
  /// In fa, this message translates to:
  /// **'موجه'**
  String get meetingAttendanceExcused;

  /// No description provided for @meetingAttendanceUnknown.
  ///
  /// In fa, this message translates to:
  /// **'نامشخص'**
  String get meetingAttendanceUnknown;

  /// No description provided for @meetingsSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی عنوان جلسه'**
  String get meetingsSearchHint;

  /// No description provided for @meetingsFilters.
  ///
  /// In fa, this message translates to:
  /// **'فیلترها'**
  String get meetingsFilters;

  /// No description provided for @meetingTemplatesTitle.
  ///
  /// In fa, this message translates to:
  /// **'الگوهای جلسه'**
  String get meetingTemplatesTitle;

  /// No description provided for @meetingsLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری جلسات ممکن نشد'**
  String get meetingsLoadFailed;

  /// No description provided for @meetingsEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'جلسه‌ای وجود ندارد'**
  String get meetingsEmptyTitle;

  /// No description provided for @meetingsEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'جلسه‌هایی که برگزار می‌کنید یا در آن‌ها دعوت هستید اینجا نمایش داده می‌شود.'**
  String get meetingsEmptyMessage;

  /// No description provided for @meetingNew.
  ///
  /// In fa, this message translates to:
  /// **'جلسه جدید'**
  String get meetingNew;

  /// No description provided for @meetingNoDate.
  ///
  /// In fa, this message translates to:
  /// **'بدون زمان'**
  String get meetingNoDate;

  /// No description provided for @meetingAttendeeCount.
  ///
  /// In fa, this message translates to:
  /// **'{n} نفر'**
  String meetingAttendeeCount(String n);

  /// No description provided for @meetingResolutionCount.
  ///
  /// In fa, this message translates to:
  /// **'مصوبات {done} از {total}'**
  String meetingResolutionCount(String done, String total);

  /// No description provided for @meetingFieldStatus.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت'**
  String get meetingFieldStatus;

  /// No description provided for @meetingFieldKind.
  ///
  /// In fa, this message translates to:
  /// **'نوع'**
  String get meetingFieldKind;

  /// No description provided for @meetingsMineOnly.
  ///
  /// In fa, this message translates to:
  /// **'فقط جلسات من'**
  String get meetingsMineOnly;

  /// No description provided for @meetingsFrom.
  ///
  /// In fa, this message translates to:
  /// **'از تاریخ'**
  String get meetingsFrom;

  /// No description provided for @meetingsTo.
  ///
  /// In fa, this message translates to:
  /// **'تا تاریخ'**
  String get meetingsTo;

  /// No description provided for @meetingAttendees.
  ///
  /// In fa, this message translates to:
  /// **'حاضرین'**
  String get meetingAttendees;

  /// No description provided for @meetingExternalGuest.
  ///
  /// In fa, this message translates to:
  /// **'مهمان بیرونی'**
  String get meetingExternalGuest;

  /// No description provided for @meetingFieldRole.
  ///
  /// In fa, this message translates to:
  /// **'نقش'**
  String get meetingFieldRole;

  /// No description provided for @meetingAddPeople.
  ///
  /// In fa, this message translates to:
  /// **'افزودن همکار'**
  String get meetingAddPeople;

  /// No description provided for @meetingAddGuest.
  ///
  /// In fa, this message translates to:
  /// **'افزودن مهمان'**
  String get meetingAddGuest;

  /// No description provided for @meetingGuestName.
  ///
  /// In fa, this message translates to:
  /// **'نام مهمان'**
  String get meetingGuestName;

  /// No description provided for @meetingEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش جلسه'**
  String get meetingEdit;

  /// No description provided for @meetingTemplate.
  ///
  /// In fa, this message translates to:
  /// **'الگو'**
  String get meetingTemplate;

  /// No description provided for @meetingProject.
  ///
  /// In fa, this message translates to:
  /// **'پروژه'**
  String get meetingProject;

  /// No description provided for @meetingNoProject.
  ///
  /// In fa, this message translates to:
  /// **'بدون پروژه'**
  String get meetingNoProject;

  /// No description provided for @meetingStart.
  ///
  /// In fa, this message translates to:
  /// **'شروع'**
  String get meetingStart;

  /// No description provided for @meetingEnd.
  ///
  /// In fa, this message translates to:
  /// **'پایان'**
  String get meetingEnd;

  /// No description provided for @meetingFieldTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get meetingFieldTitle;

  /// No description provided for @meetingLocation.
  ///
  /// In fa, this message translates to:
  /// **'مکان'**
  String get meetingLocation;

  /// No description provided for @meetingDescription.
  ///
  /// In fa, this message translates to:
  /// **'توضیحات'**
  String get meetingDescription;

  /// No description provided for @meetingSaveTemplate.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره به‌عنوان الگو'**
  String get meetingSaveTemplate;

  /// No description provided for @meetingTemplateName.
  ///
  /// In fa, this message translates to:
  /// **'نام الگو'**
  String get meetingTemplateName;

  /// No description provided for @meetingTemplateOrg.
  ///
  /// In fa, this message translates to:
  /// **'الگوی سازمانی (برای همه)'**
  String get meetingTemplateOrg;

  /// No description provided for @meetingTemplateSaved.
  ///
  /// In fa, this message translates to:
  /// **'الگو ذخیره شد'**
  String get meetingTemplateSaved;

  /// No description provided for @meetingSaveDraft.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره پیش‌نویس'**
  String get meetingSaveDraft;

  /// No description provided for @meetingSaveSchedule.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره و برنامه‌ریزی'**
  String get meetingSaveSchedule;

  /// No description provided for @meetingTitleRequired.
  ///
  /// In fa, this message translates to:
  /// **'عنوان را وارد کنید'**
  String get meetingTitleRequired;

  /// No description provided for @meetingStartRequired.
  ///
  /// In fa, this message translates to:
  /// **'زمان شروع را مشخص کنید'**
  String get meetingStartRequired;

  /// No description provided for @meetingEndBeforeStart.
  ///
  /// In fa, this message translates to:
  /// **'پایان نباید قبل از شروع باشد'**
  String get meetingEndBeforeStart;

  /// No description provided for @meetingNeedChair.
  ///
  /// In fa, this message translates to:
  /// **'جلسه سازمانی دقیقاً یک رئیس لازم دارد'**
  String get meetingNeedChair;

  /// No description provided for @meetingNeedSecretary.
  ///
  /// In fa, this message translates to:
  /// **'جلسه سازمانی دقیقاً یک دبیر لازم دارد'**
  String get meetingNeedSecretary;

  /// No description provided for @meetingTemplateScopeOrg.
  ///
  /// In fa, this message translates to:
  /// **'سازمانی'**
  String get meetingTemplateScopeOrg;

  /// No description provided for @meetingTemplateScopePersonal.
  ///
  /// In fa, this message translates to:
  /// **'شخصی'**
  String get meetingTemplateScopePersonal;

  /// No description provided for @meetingTemplateInactive.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال'**
  String get meetingTemplateInactive;

  /// No description provided for @meetingTemplateRename.
  ///
  /// In fa, this message translates to:
  /// **'تغییر نام'**
  String get meetingTemplateRename;

  /// No description provided for @meetingTemplateDeactivate.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال کردن'**
  String get meetingTemplateDeactivate;

  /// No description provided for @meetingTemplateActivate.
  ///
  /// In fa, this message translates to:
  /// **'فعال کردن'**
  String get meetingTemplateActivate;

  /// No description provided for @meetingTemplatesEmpty.
  ///
  /// In fa, this message translates to:
  /// **'الگویی وجود ندارد'**
  String get meetingTemplatesEmpty;

  /// No description provided for @meetingTemplatesEmptyHint.
  ///
  /// In fa, this message translates to:
  /// **'هنگام ساخت جلسه می‌توانید آن را به‌عنوان الگو ذخیره کنید.'**
  String get meetingTemplatesEmptyHint;

  /// No description provided for @meetingDetailTitle.
  ///
  /// In fa, this message translates to:
  /// **'جلسه'**
  String get meetingDetailTitle;

  /// No description provided for @meetingLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری جلسه ممکن نشد'**
  String get meetingLoadFailed;

  /// No description provided for @meetingNotFound.
  ///
  /// In fa, this message translates to:
  /// **'این جلسه دیگر در دسترس نیست.'**
  String get meetingNotFound;

  /// No description provided for @meetingConfirmCancel.
  ///
  /// In fa, this message translates to:
  /// **'این جلسه لغو شود؟'**
  String get meetingConfirmCancel;

  /// No description provided for @meetingConfirmClose.
  ///
  /// In fa, this message translates to:
  /// **'صورتجلسه بسته شود؟'**
  String get meetingConfirmClose;

  /// No description provided for @meetingConfirmReopen.
  ///
  /// In fa, this message translates to:
  /// **'جلسه دوباره باز شود؟ امضاهای قبلی منسوخ می‌شوند.'**
  String get meetingConfirmReopen;

  /// No description provided for @meetingRevision.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش {n}'**
  String meetingRevision(String n);

  /// No description provided for @meetingCreatedBy.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد‌کننده: {name}'**
  String meetingCreatedBy(String name);

  /// No description provided for @meetingAttendanceHint.
  ///
  /// In fa, this message translates to:
  /// **'برای ثبت حضور روی وضعیت هر نفر بزنید'**
  String get meetingAttendanceHint;

  /// No description provided for @meetingNoAttendees.
  ///
  /// In fa, this message translates to:
  /// **'حاضری ثبت نشده است'**
  String get meetingNoAttendees;

  /// No description provided for @meetingMarkAttendance.
  ///
  /// In fa, this message translates to:
  /// **'ثبت حضور'**
  String get meetingMarkAttendance;

  /// No description provided for @meetingMinutes.
  ///
  /// In fa, this message translates to:
  /// **'صورتجلسه'**
  String get meetingMinutes;

  /// No description provided for @meetingEditMinutes.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش متن'**
  String get meetingEditMinutes;

  /// No description provided for @meetingNoMinutes.
  ///
  /// In fa, this message translates to:
  /// **'هنوز متنی نوشته نشده است.'**
  String get meetingNoMinutes;

  /// No description provided for @meetingSignatures.
  ///
  /// In fa, this message translates to:
  /// **'امضاها'**
  String get meetingSignatures;

  /// No description provided for @meetingAllSigned.
  ///
  /// In fa, this message translates to:
  /// **'همه امضا کرده‌اند'**
  String get meetingAllSigned;

  /// No description provided for @meetingNoSignatures.
  ///
  /// In fa, this message translates to:
  /// **'هنوز امضایی نیست.'**
  String get meetingNoSignatures;

  /// No description provided for @meetingSign.
  ///
  /// In fa, this message translates to:
  /// **'امضای صورتجلسه'**
  String get meetingSign;

  /// No description provided for @meetingSignatureStale.
  ///
  /// In fa, this message translates to:
  /// **'منسوخ'**
  String get meetingSignatureStale;

  /// No description provided for @meetingResolutions.
  ///
  /// In fa, this message translates to:
  /// **'مصوبات'**
  String get meetingResolutions;

  /// No description provided for @resolutionAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن مصوبه'**
  String get resolutionAdd;

  /// No description provided for @resolutionEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش'**
  String get resolutionEdit;

  /// No description provided for @resolutionDeactivate.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال کردن'**
  String get resolutionDeactivate;

  /// No description provided for @resolutionDeactivateConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این مصوبه و وظیفه پیگیری آن لغو شود؟'**
  String get resolutionDeactivateConfirm;

  /// No description provided for @resolutionOwners.
  ///
  /// In fa, this message translates to:
  /// **'مسئولان'**
  String get resolutionOwners;

  /// No description provided for @resolutionDue.
  ///
  /// In fa, this message translates to:
  /// **'سررسید'**
  String get resolutionDue;

  /// No description provided for @resolutionTask.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه'**
  String get resolutionTask;

  /// No description provided for @resolutionText.
  ///
  /// In fa, this message translates to:
  /// **'متن مصوبه'**
  String get resolutionText;

  /// No description provided for @resolutionOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز'**
  String get resolutionOpen;

  /// No description provided for @resolutionDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام شد'**
  String get resolutionDone;

  /// No description provided for @resolutionCancelled.
  ///
  /// In fa, this message translates to:
  /// **'لغوشده'**
  String get resolutionCancelled;

  /// No description provided for @meetingNoResolutions.
  ///
  /// In fa, this message translates to:
  /// **'مصوبه‌ای ثبت نشده است.'**
  String get meetingNoResolutions;

  /// No description provided for @meetingSignTitle.
  ///
  /// In fa, this message translates to:
  /// **'امضای صورتجلسه'**
  String get meetingSignTitle;

  /// No description provided for @meetingSignApproveHint.
  ///
  /// In fa, this message translates to:
  /// **'با صورتجلسه موافقم'**
  String get meetingSignApproveHint;

  /// No description provided for @meetingSignRejectHint.
  ///
  /// In fa, this message translates to:
  /// **'با صورتجلسه موافق نیستم'**
  String get meetingSignRejectHint;

  /// No description provided for @meetingSignNoteRequired.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت (برای رد الزامی است)'**
  String get meetingSignNoteRequired;

  /// No description provided for @meetingRejectNeedsNote.
  ///
  /// In fa, this message translates to:
  /// **'برای رد کردن باید یادداشت بنویسید.'**
  String get meetingRejectNeedsNote;

  /// No description provided for @meetingSignReason.
  ///
  /// In fa, this message translates to:
  /// **'امضای صورتجلسه: {title}'**
  String meetingSignReason(String title);

  /// No description provided for @meetingActionSchedule.
  ///
  /// In fa, this message translates to:
  /// **'برنامه‌ریزی'**
  String get meetingActionSchedule;

  /// No description provided for @meetingActionHold.
  ///
  /// In fa, this message translates to:
  /// **'شروع جلسه'**
  String get meetingActionHold;

  /// No description provided for @meetingActionClose.
  ///
  /// In fa, this message translates to:
  /// **'بستن صورتجلسه'**
  String get meetingActionClose;

  /// No description provided for @meetingActionReopen.
  ///
  /// In fa, this message translates to:
  /// **'بازگشایی'**
  String get meetingActionReopen;

  /// No description provided for @meetingActionCancel.
  ///
  /// In fa, this message translates to:
  /// **'لغو جلسه'**
  String get meetingActionCancel;

  /// No description provided for @meetingRemind.
  ///
  /// In fa, this message translates to:
  /// **'یادآوری به حاضرین'**
  String get meetingRemind;

  /// No description provided for @meetingSms.
  ///
  /// In fa, this message translates to:
  /// **'پیامک به حاضرین'**
  String get meetingSms;

  /// No description provided for @meetingRemindTitle.
  ///
  /// In fa, this message translates to:
  /// **'یادآوری به حاضرین'**
  String get meetingRemindTitle;

  /// No description provided for @meetingRemindBefore.
  ///
  /// In fa, this message translates to:
  /// **'چه مدت قبل از شروع'**
  String get meetingRemindBefore;

  /// No description provided for @meetingOffsetDays.
  ///
  /// In fa, this message translates to:
  /// **'{n} روز'**
  String meetingOffsetDays(String n);

  /// No description provided for @meetingOffsetHours.
  ///
  /// In fa, this message translates to:
  /// **'{n} ساعت'**
  String meetingOffsetHours(String n);

  /// No description provided for @meetingOffsetMinutes.
  ///
  /// In fa, this message translates to:
  /// **'{n} دقیقه'**
  String meetingOffsetMinutes(String n);

  /// No description provided for @meetingRemindDone.
  ///
  /// In fa, this message translates to:
  /// **'{n} یادآوری ثبت شد'**
  String meetingRemindDone(String n);

  /// No description provided for @meetingSmsTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیامک به حاضرین'**
  String get meetingSmsTitle;

  /// No description provided for @meetingSmsText.
  ///
  /// In fa, this message translates to:
  /// **'متن پیامک'**
  String get meetingSmsText;

  /// No description provided for @meetingSmsSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال'**
  String get meetingSmsSend;

  /// No description provided for @meetingSmsDone.
  ///
  /// In fa, this message translates to:
  /// **'ارسال‌شده: {sent}، بدون شماره: {without}'**
  String meetingSmsDone(String sent, String without);

  /// No description provided for @meetingPrint.
  ///
  /// In fa, this message translates to:
  /// **'چاپ صورتجلسه'**
  String get meetingPrint;

  /// No description provided for @meetingPrintTitle.
  ///
  /// In fa, this message translates to:
  /// **'صورتجلسه'**
  String get meetingPrintTitle;

  /// No description provided for @meetingPrintDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ'**
  String get meetingPrintDate;

  /// No description provided for @moduleNotes.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت‌ها'**
  String get moduleNotes;

  /// No description provided for @notesSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجو در یادداشت‌ها'**
  String get notesSearchHint;

  /// No description provided for @notesViewGrid.
  ///
  /// In fa, this message translates to:
  /// **'نمایش شبکه‌ای'**
  String get notesViewGrid;

  /// No description provided for @notesViewList.
  ///
  /// In fa, this message translates to:
  /// **'نمایش فهرستی'**
  String get notesViewList;

  /// No description provided for @notesArchiveToggle.
  ///
  /// In fa, this message translates to:
  /// **'آرشیو'**
  String get notesArchiveToggle;

  /// No description provided for @notesNew.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت جدید'**
  String get notesNew;

  /// No description provided for @notesPinned.
  ///
  /// In fa, this message translates to:
  /// **'سنجاق‌شده'**
  String get notesPinned;

  /// No description provided for @notesOthers.
  ///
  /// In fa, this message translates to:
  /// **'سایر'**
  String get notesOthers;

  /// No description provided for @notesEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'یادداشتی ندارید'**
  String get notesEmptyTitle;

  /// No description provided for @notesEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'با دکمه «یادداشت جدید» اولین یادداشت خود را بنویسید. یادداشت‌ها فقط برای شما دیده می‌شوند.'**
  String get notesEmptyMessage;

  /// No description provided for @notesEmptyArchived.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت آرشیوشده‌ای وجود ندارد'**
  String get notesEmptyArchived;

  /// No description provided for @notesLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری یادداشت‌ها ممکن نشد'**
  String get notesLoadFailed;

  /// No description provided for @noteEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش یادداشت'**
  String get noteEdit;

  /// No description provided for @noteTitleHint.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get noteTitleHint;

  /// No description provided for @noteBodyHint.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت'**
  String get noteBodyHint;

  /// No description provided for @noteColorName.
  ///
  /// In fa, this message translates to:
  /// **'رنگ {n}'**
  String noteColorName(String n);

  /// No description provided for @notePin.
  ///
  /// In fa, this message translates to:
  /// **'سنجاق کردن'**
  String get notePin;

  /// No description provided for @noteUnpin.
  ///
  /// In fa, this message translates to:
  /// **'برداشتن سنجاق'**
  String get noteUnpin;

  /// No description provided for @noteArchive.
  ///
  /// In fa, this message translates to:
  /// **'بایگانی'**
  String get noteArchive;

  /// No description provided for @noteUnarchive.
  ///
  /// In fa, this message translates to:
  /// **'خارج کردن از آرشیو'**
  String get noteUnarchive;

  /// No description provided for @noteChecklistAddHint.
  ///
  /// In fa, this message translates to:
  /// **'افزودن مورد'**
  String get noteChecklistAddHint;

  /// No description provided for @noteChecklistAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن'**
  String get noteChecklistAdd;

  /// No description provided for @noteItemUp.
  ///
  /// In fa, this message translates to:
  /// **'انتقال به بالا'**
  String get noteItemUp;

  /// No description provided for @noteItemDown.
  ///
  /// In fa, this message translates to:
  /// **'انتقال به پایین'**
  String get noteItemDown;

  /// No description provided for @noteItemRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف مورد'**
  String get noteItemRemove;

  /// No description provided for @noteImageAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن تصویر'**
  String get noteImageAdd;

  /// No description provided for @noteImageRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف تصویر'**
  String get noteImageRemove;

  /// No description provided for @noteImageOnly.
  ///
  /// In fa, this message translates to:
  /// **'فقط پرونده تصویر مجاز است.'**
  String get noteImageOnly;

  /// No description provided for @moduleChat.
  ///
  /// In fa, this message translates to:
  /// **'گفتگو'**
  String get moduleChat;

  /// No description provided for @chatTabMine.
  ///
  /// In fa, this message translates to:
  /// **'گفتگوهای من'**
  String get chatTabMine;

  /// No description provided for @chatTabPublic.
  ///
  /// In fa, this message translates to:
  /// **'عمومی'**
  String get chatTabPublic;

  /// No description provided for @chatSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'متن پیام'**
  String get chatSearchHint;

  /// No description provided for @chatKindGroup.
  ///
  /// In fa, this message translates to:
  /// **'گروه'**
  String get chatKindGroup;

  /// No description provided for @chatKindChannel.
  ///
  /// In fa, this message translates to:
  /// **'کانال'**
  String get chatKindChannel;

  /// No description provided for @chatKindDm.
  ///
  /// In fa, this message translates to:
  /// **'پیام مستقیم'**
  String get chatKindDm;

  /// No description provided for @chatLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری گفتگوها ممکن نشد'**
  String get chatLoadFailed;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'هنوز گفتگویی ندارید'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'یک گروه بسازید یا از فهرست همکاران پیام مستقیم بفرستید.'**
  String get chatEmptyMessage;

  /// No description provided for @chatEmptyPublic.
  ///
  /// In fa, this message translates to:
  /// **'گروه یا کانال عمومی‌ای برای پیوستن نیست.'**
  String get chatEmptyPublic;

  /// No description provided for @chatNew.
  ///
  /// In fa, this message translates to:
  /// **'گفتگوی جدید'**
  String get chatNew;

  /// No description provided for @chatNewGroup.
  ///
  /// In fa, this message translates to:
  /// **'گروه جدید'**
  String get chatNewGroup;

  /// No description provided for @chatNewChannel.
  ///
  /// In fa, this message translates to:
  /// **'کانال جدید'**
  String get chatNewChannel;

  /// No description provided for @chatNewDm.
  ///
  /// In fa, this message translates to:
  /// **'پیام مستقیم'**
  String get chatNewDm;

  /// No description provided for @chatPinConv.
  ///
  /// In fa, this message translates to:
  /// **'سنجاق کردن گفتگو'**
  String get chatPinConv;

  /// No description provided for @chatUnpinConv.
  ///
  /// In fa, this message translates to:
  /// **'برداشتن سنجاق گفتگو'**
  String get chatUnpinConv;

  /// No description provided for @chatMute.
  ///
  /// In fa, this message translates to:
  /// **'بی‌صدا کردن'**
  String get chatMute;

  /// No description provided for @chatUnmute.
  ///
  /// In fa, this message translates to:
  /// **'فعال کردن صدا'**
  String get chatUnmute;

  /// No description provided for @chatJoin.
  ///
  /// In fa, this message translates to:
  /// **'پیوستن'**
  String get chatJoin;

  /// No description provided for @chatLeave.
  ///
  /// In fa, this message translates to:
  /// **'ترک گفتگو'**
  String get chatLeave;

  /// No description provided for @chatLeaveConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این گفتگو را ترک می‌کنید؟'**
  String get chatLeaveConfirm;

  /// No description provided for @chatMembersCount.
  ///
  /// In fa, this message translates to:
  /// **'{count} عضو'**
  String chatMembersCount(String count);

  /// No description provided for @chatName.
  ///
  /// In fa, this message translates to:
  /// **'نام'**
  String get chatName;

  /// No description provided for @chatDescription.
  ///
  /// In fa, this message translates to:
  /// **'توضیحات (اختیاری)'**
  String get chatDescription;

  /// No description provided for @chatPublicSwitch.
  ///
  /// In fa, this message translates to:
  /// **'عمومی (همه می‌توانند پیدا کنند و بپیوندند)'**
  String get chatPublicSwitch;

  /// No description provided for @chatPostPolicy.
  ///
  /// In fa, this message translates to:
  /// **'چه کسی می‌تواند پیام بدهد'**
  String get chatPostPolicy;

  /// No description provided for @chatPostAll.
  ///
  /// In fa, this message translates to:
  /// **'همه اعضا'**
  String get chatPostAll;

  /// No description provided for @chatPostAdmins.
  ///
  /// In fa, this message translates to:
  /// **'فقط مدیران'**
  String get chatPostAdmins;

  /// No description provided for @chatMembers.
  ///
  /// In fa, this message translates to:
  /// **'اعضا'**
  String get chatMembers;

  /// No description provided for @chatAddMembers.
  ///
  /// In fa, this message translates to:
  /// **'افزودن اعضا'**
  String get chatAddMembers;

  /// No description provided for @chatNameRequired.
  ///
  /// In fa, this message translates to:
  /// **'نام را وارد کنید'**
  String get chatNameRequired;

  /// No description provided for @chatCreate.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد'**
  String get chatCreate;

  /// No description provided for @chatCreateForbidden.
  ///
  /// In fa, this message translates to:
  /// **'اجازه ساختن گروه یا کانال را ندارید.'**
  String get chatCreateForbidden;

  /// No description provided for @chatDmPickTitle.
  ///
  /// In fa, this message translates to:
  /// **'شروع گفتگوی مستقیم'**
  String get chatDmPickTitle;

  /// No description provided for @chatDirectorySearch.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی همکار'**
  String get chatDirectorySearch;

  /// No description provided for @chatMessageHint.
  ///
  /// In fa, this message translates to:
  /// **'پیام بنویسید'**
  String get chatMessageHint;

  /// No description provided for @chatSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال'**
  String get chatSend;

  /// No description provided for @chatAttach.
  ///
  /// In fa, this message translates to:
  /// **'پیوست پرونده'**
  String get chatAttach;

  /// No description provided for @chatPaste.
  ///
  /// In fa, this message translates to:
  /// **'چسباندن از کلیپ‌بورد'**
  String get chatPaste;

  /// No description provided for @chatPasteEmpty.
  ///
  /// In fa, this message translates to:
  /// **'چیزی برای چسباندن نیست.'**
  String get chatPasteEmpty;

  /// No description provided for @chatMention.
  ///
  /// In fa, this message translates to:
  /// **'اشاره به همکار'**
  String get chatMention;

  /// No description provided for @chatVoice.
  ///
  /// In fa, this message translates to:
  /// **'پیام صوتی'**
  String get chatVoice;

  /// No description provided for @chatReply.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ'**
  String get chatReply;

  /// No description provided for @chatReplyingTo.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ به {name}'**
  String chatReplyingTo(String name);

  /// No description provided for @chatCancelReply.
  ///
  /// In fa, this message translates to:
  /// **'لغو پاسخ'**
  String get chatCancelReply;

  /// No description provided for @chatDelete.
  ///
  /// In fa, this message translates to:
  /// **'حذف پیام'**
  String get chatDelete;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In fa, this message translates to:
  /// **'این پیام حذف شود؟'**
  String get chatDeleteConfirm;

  /// No description provided for @chatDeleted.
  ///
  /// In fa, this message translates to:
  /// **'این پیام حذف شد'**
  String get chatDeleted;

  /// No description provided for @chatPinMessage.
  ///
  /// In fa, this message translates to:
  /// **'سنجاق پیام'**
  String get chatPinMessage;

  /// No description provided for @chatUnpinMessage.
  ///
  /// In fa, this message translates to:
  /// **'برداشتن سنجاق پیام'**
  String get chatUnpinMessage;

  /// No description provided for @chatBookmark.
  ///
  /// In fa, this message translates to:
  /// **'نشان کردن'**
  String get chatBookmark;

  /// No description provided for @chatBookmarked.
  ///
  /// In fa, this message translates to:
  /// **'پیام نشان شد.'**
  String get chatBookmarked;

  /// No description provided for @chatToTask.
  ///
  /// In fa, this message translates to:
  /// **'تبدیل به وظیفه'**
  String get chatToTask;

  /// No description provided for @chatSeenBy.
  ///
  /// In fa, this message translates to:
  /// **'چه کسی دیده است'**
  String get chatSeenBy;

  /// No description provided for @chatCopy.
  ///
  /// In fa, this message translates to:
  /// **'رونوشت متن'**
  String get chatCopy;

  /// No description provided for @chatPinsBar.
  ///
  /// In fa, this message translates to:
  /// **'{count} پیام سنجاق‌شده'**
  String chatPinsBar(String count);

  /// No description provided for @chatJumpToDate.
  ///
  /// In fa, this message translates to:
  /// **'رفتن به تاریخ'**
  String get chatJumpToDate;

  /// No description provided for @chatJumpLatest.
  ///
  /// In fa, this message translates to:
  /// **'رفتن به آخرین پیام'**
  String get chatJumpLatest;

  /// No description provided for @chatNoMessagesOnDate.
  ///
  /// In fa, this message translates to:
  /// **'از این تاریخ به بعد پیامی نیست.'**
  String get chatNoMessagesOnDate;

  /// No description provided for @chatSeenTitle.
  ///
  /// In fa, this message translates to:
  /// **'دیده‌شده توسط'**
  String get chatSeenTitle;

  /// No description provided for @chatSeenEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز کسی ندیده است.'**
  String get chatSeenEmpty;

  /// No description provided for @chatSeenUntracked.
  ///
  /// In fa, this message translates to:
  /// **'در گفتگوهای بزرگ رسید خواندن ثبت نمی‌شود.'**
  String get chatSeenUntracked;

  /// No description provided for @chatSeenFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری رسیدها ممکن نشد.'**
  String get chatSeenFailed;

  /// No description provided for @chatNotMember.
  ///
  /// In fa, this message translates to:
  /// **'برای دیدن پیام‌ها ابتدا بپیوندید.'**
  String get chatNotMember;

  /// No description provided for @chatArchivedNote.
  ///
  /// In fa, this message translates to:
  /// **'این گفتگو بایگانی شده است.'**
  String get chatArchivedNote;

  /// No description provided for @chatReadOnly.
  ///
  /// In fa, this message translates to:
  /// **'فقط مدیران می‌توانند پیام بدهند.'**
  String get chatReadOnly;

  /// No description provided for @chatSendFailed.
  ///
  /// In fa, this message translates to:
  /// **'ارسال پیام ممکن نشد.'**
  String get chatSendFailed;

  /// No description provided for @chatActionFailed.
  ///
  /// In fa, this message translates to:
  /// **'انجام این کار ممکن نشد.'**
  String get chatActionFailed;

  /// No description provided for @chatForbidden.
  ///
  /// In fa, this message translates to:
  /// **'اجازه انجام این کار را ندارید.'**
  String get chatForbidden;

  /// No description provided for @chatDownload.
  ///
  /// In fa, this message translates to:
  /// **'دریافت پرونده'**
  String get chatDownload;

  /// No description provided for @chatEdited.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش‌شده'**
  String get chatEdited;

  /// No description provided for @chatTaskCreated.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای از یک پیام ساخته شد.'**
  String get chatTaskCreated;

  /// No description provided for @chatInfo.
  ///
  /// In fa, this message translates to:
  /// **'اطلاعات گفتگو'**
  String get chatInfo;

  /// No description provided for @chatAdminRole.
  ///
  /// In fa, this message translates to:
  /// **'مدیر'**
  String get chatAdminRole;

  /// No description provided for @chatMentionSearch.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی عضو'**
  String get chatMentionSearch;

  /// No description provided for @chatMessageToTaskPrefix.
  ///
  /// In fa, this message translates to:
  /// **'پیام گفتگو'**
  String get chatMessageToTaskPrefix;

  /// No description provided for @chatSeen.
  ///
  /// In fa, this message translates to:
  /// **'دیده شد'**
  String get chatSeen;

  /// No description provided for @chatToday.
  ///
  /// In fa, this message translates to:
  /// **'امروز'**
  String get chatToday;

  /// No description provided for @chatUnreadMentions.
  ///
  /// In fa, this message translates to:
  /// **'اشاره‌ها'**
  String get chatUnreadMentions;

  /// No description provided for @monTitle.
  ///
  /// In fa, this message translates to:
  /// **'پایش'**
  String get monTitle;

  /// No description provided for @monMyNumbers.
  ///
  /// In fa, this message translates to:
  /// **'اعداد من'**
  String get monMyNumbers;

  /// No description provided for @monOpenTasks.
  ///
  /// In fa, this message translates to:
  /// **'کار باز'**
  String get monOpenTasks;

  /// No description provided for @monOverdue.
  ///
  /// In fa, this message translates to:
  /// **'عقب‌افتاده'**
  String get monOverdue;

  /// No description provided for @monDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام‌شده'**
  String get monDone;

  /// No description provided for @monLettersWaiting.
  ///
  /// In fa, this message translates to:
  /// **'نامه منتظر شما'**
  String get monLettersWaiting;

  /// No description provided for @monMeetingsToday.
  ///
  /// In fa, this message translates to:
  /// **'جلسه امروز'**
  String get monMeetingsToday;

  /// No description provided for @monUnreadChat.
  ///
  /// In fa, this message translates to:
  /// **'پیام خوانده‌نشده'**
  String get monUnreadChat;

  /// No description provided for @monRemindersToday.
  ///
  /// In fa, this message translates to:
  /// **'یادآور امروز'**
  String get monRemindersToday;

  /// No description provided for @monTabOverview.
  ///
  /// In fa, this message translates to:
  /// **'نمای کلی'**
  String get monTabOverview;

  /// No description provided for @monTabProjects.
  ///
  /// In fa, this message translates to:
  /// **'پروژه‌ها'**
  String get monTabProjects;

  /// No description provided for @monTabTasks.
  ///
  /// In fa, this message translates to:
  /// **'کارها'**
  String get monTabTasks;

  /// No description provided for @monTabMeetings.
  ///
  /// In fa, this message translates to:
  /// **'جلسات'**
  String get monTabMeetings;

  /// No description provided for @monTabMembers.
  ///
  /// In fa, this message translates to:
  /// **'اعضا'**
  String get monTabMembers;

  /// No description provided for @monTabOnline.
  ///
  /// In fa, this message translates to:
  /// **'آنلاین'**
  String get monTabOnline;

  /// No description provided for @monTabCustomers.
  ///
  /// In fa, this message translates to:
  /// **'مشتریان'**
  String get monTabCustomers;

  /// No description provided for @monTabFinance.
  ///
  /// In fa, this message translates to:
  /// **'مالی'**
  String get monTabFinance;

  /// No description provided for @monTabSales.
  ///
  /// In fa, this message translates to:
  /// **'فروش'**
  String get monTabSales;

  /// No description provided for @monPeriodWeek.
  ///
  /// In fa, this message translates to:
  /// **'هفته'**
  String get monPeriodWeek;

  /// No description provided for @monPeriodMonth.
  ///
  /// In fa, this message translates to:
  /// **'ماه'**
  String get monPeriodMonth;

  /// No description provided for @monPeriodQuarter.
  ///
  /// In fa, this message translates to:
  /// **'فصل'**
  String get monPeriodQuarter;

  /// No description provided for @monPeriodYear.
  ///
  /// In fa, this message translates to:
  /// **'سال'**
  String get monPeriodYear;

  /// No description provided for @monPeriodCustom.
  ///
  /// In fa, this message translates to:
  /// **'بازه دلخواه'**
  String get monPeriodCustom;

  /// No description provided for @monBucketDay.
  ///
  /// In fa, this message translates to:
  /// **'روزانه'**
  String get monBucketDay;

  /// No description provided for @monBucketWeek.
  ///
  /// In fa, this message translates to:
  /// **'هفتگی'**
  String get monBucketWeek;

  /// No description provided for @monBucketMonth.
  ///
  /// In fa, this message translates to:
  /// **'ماهانه'**
  String get monBucketMonth;

  /// No description provided for @monFrom.
  ///
  /// In fa, this message translates to:
  /// **'از'**
  String get monFrom;

  /// No description provided for @monTo.
  ///
  /// In fa, this message translates to:
  /// **'تا'**
  String get monTo;

  /// No description provided for @monChat.
  ///
  /// In fa, this message translates to:
  /// **'پیام‌های گفتگو'**
  String get monChat;

  /// No description provided for @monLetters.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌ها'**
  String get monLetters;

  /// No description provided for @monTasks.
  ///
  /// In fa, this message translates to:
  /// **'کارها'**
  String get monTasks;

  /// No description provided for @monCustomers.
  ///
  /// In fa, this message translates to:
  /// **'مشتریان'**
  String get monCustomers;

  /// No description provided for @monMeetings.
  ///
  /// In fa, this message translates to:
  /// **'جلسات'**
  String get monMeetings;

  /// No description provided for @monProjectsTitle.
  ///
  /// In fa, this message translates to:
  /// **'پروژه‌ها'**
  String get monProjectsTitle;

  /// No description provided for @monCreated.
  ///
  /// In fa, this message translates to:
  /// **'ایجادشده'**
  String get monCreated;

  /// No description provided for @monCompleted.
  ///
  /// In fa, this message translates to:
  /// **'تکمیل‌شده'**
  String get monCompleted;

  /// No description provided for @monSigned.
  ///
  /// In fa, this message translates to:
  /// **'امضاشده'**
  String get monSigned;

  /// No description provided for @monEvents.
  ///
  /// In fa, this message translates to:
  /// **'رویدادها'**
  String get monEvents;

  /// No description provided for @monMessages.
  ///
  /// In fa, this message translates to:
  /// **'پیام'**
  String get monMessages;

  /// No description provided for @monSortLastDone.
  ///
  /// In fa, this message translates to:
  /// **'آخرین کار انجام‌شده'**
  String get monSortLastDone;

  /// No description provided for @monSortMostOverdue.
  ///
  /// In fa, this message translates to:
  /// **'بیشترین عقب‌افتادگی'**
  String get monSortMostOverdue;

  /// No description provided for @monSortLeastOverdue.
  ///
  /// In fa, this message translates to:
  /// **'کمترین عقب‌افتادگی'**
  String get monSortLeastOverdue;

  /// No description provided for @monSortCompleted.
  ///
  /// In fa, this message translates to:
  /// **'بیشترین انجام‌شده'**
  String get monSortCompleted;

  /// No description provided for @monSortActivity.
  ///
  /// In fa, this message translates to:
  /// **'فعالیت'**
  String get monSortActivity;

  /// No description provided for @monGroups.
  ///
  /// In fa, this message translates to:
  /// **'گروه‌های پروژه'**
  String get monGroups;

  /// No description provided for @monNoGroup.
  ///
  /// In fa, this message translates to:
  /// **'بدون گروه'**
  String get monNoGroup;

  /// No description provided for @monProjectsCount.
  ///
  /// In fa, this message translates to:
  /// **'پروژه'**
  String get monProjectsCount;

  /// No description provided for @monOverdueReport.
  ///
  /// In fa, this message translates to:
  /// **'گزارش عقب‌افتاده‌ها'**
  String get monOverdueReport;

  /// No description provided for @monLate.
  ///
  /// In fa, this message translates to:
  /// **'تأخیر'**
  String get monLate;

  /// No description provided for @monDays.
  ///
  /// In fa, this message translates to:
  /// **'روز'**
  String get monDays;

  /// No description provided for @monHours.
  ///
  /// In fa, this message translates to:
  /// **'ساعت'**
  String get monHours;

  /// No description provided for @monFilterProject.
  ///
  /// In fa, this message translates to:
  /// **'پروژه'**
  String get monFilterProject;

  /// No description provided for @monFilterLabel.
  ///
  /// In fa, this message translates to:
  /// **'برچسب'**
  String get monFilterLabel;

  /// No description provided for @monFilterPerson.
  ///
  /// In fa, this message translates to:
  /// **'فرد'**
  String get monFilterPerson;

  /// No description provided for @monFilterCustomer.
  ///
  /// In fa, this message translates to:
  /// **'مشتری'**
  String get monFilterCustomer;

  /// No description provided for @monFilterAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get monFilterAll;

  /// No description provided for @monFilterNoProject.
  ///
  /// In fa, this message translates to:
  /// **'بدون پروژه'**
  String get monFilterNoProject;

  /// No description provided for @monPrint.
  ///
  /// In fa, this message translates to:
  /// **'چاپ فهرست'**
  String get monPrint;

  /// No description provided for @monPrintTitle.
  ///
  /// In fa, this message translates to:
  /// **'گزارش کارهای عقب‌افتاده'**
  String get monPrintTitle;

  /// No description provided for @monMeetingProjectFilter.
  ///
  /// In fa, this message translates to:
  /// **'عنوان پروژه'**
  String get monMeetingProjectFilter;

  /// No description provided for @monInvited.
  ///
  /// In fa, this message translates to:
  /// **'دعوت‌شده'**
  String get monInvited;

  /// No description provided for @monPresent.
  ///
  /// In fa, this message translates to:
  /// **'حاضر'**
  String get monPresent;

  /// No description provided for @monOpenResolutions.
  ///
  /// In fa, this message translates to:
  /// **'مصوبهٔ باز'**
  String get monOpenResolutions;

  /// No description provided for @monOnTime.
  ///
  /// In fa, this message translates to:
  /// **'به‌موقع'**
  String get monOnTime;

  /// No description provided for @monLateDone.
  ///
  /// In fa, this message translates to:
  /// **'با تأخیر'**
  String get monLateDone;

  /// No description provided for @monAvgDelay.
  ///
  /// In fa, this message translates to:
  /// **'میانگین تأخیر (روز)'**
  String get monAvgDelay;

  /// No description provided for @monLettersSigned.
  ///
  /// In fa, this message translates to:
  /// **'نامه امضاشده'**
  String get monLettersSigned;

  /// No description provided for @monMeetingsAttended.
  ///
  /// In fa, this message translates to:
  /// **'جلسه حاضر'**
  String get monMeetingsAttended;

  /// No description provided for @monOnlineNow.
  ///
  /// In fa, this message translates to:
  /// **'آنلاین'**
  String get monOnlineNow;

  /// No description provided for @monLastActive.
  ///
  /// In fa, this message translates to:
  /// **'آخرین فعالیت'**
  String get monLastActive;

  /// No description provided for @monNever.
  ///
  /// In fa, this message translates to:
  /// **'هرگز'**
  String get monNever;

  /// No description provided for @monHistory.
  ///
  /// In fa, this message translates to:
  /// **'سابقهٔ ورود و دستگاه‌ها'**
  String get monHistory;

  /// No description provided for @monRevoked.
  ///
  /// In fa, this message translates to:
  /// **'خروج‌شده'**
  String get monRevoked;

  /// No description provided for @monTheirTasks.
  ///
  /// In fa, this message translates to:
  /// **'کارهای این فرد'**
  String get monTheirTasks;

  /// No description provided for @monQuiet.
  ///
  /// In fa, this message translates to:
  /// **'مشتریان بی‌حرکت'**
  String get monQuiet;

  /// No description provided for @monQuietHint.
  ///
  /// In fa, this message translates to:
  /// **'بدون رویداد در ۳۰ روز اخیر'**
  String get monQuietHint;

  /// No description provided for @monCustomerTotal.
  ///
  /// In fa, this message translates to:
  /// **'کل پرونده‌ها'**
  String get monCustomerTotal;

  /// No description provided for @monCreatedInPeriod.
  ///
  /// In fa, this message translates to:
  /// **'ایجادشده در بازه'**
  String get monCreatedInPeriod;

  /// No description provided for @monLastEvent.
  ///
  /// In fa, this message translates to:
  /// **'آخرین رویداد'**
  String get monLastEvent;

  /// No description provided for @monReceipts.
  ///
  /// In fa, this message translates to:
  /// **'دریافت قطعی'**
  String get monReceipts;

  /// No description provided for @monPayments.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت قطعی'**
  String get monPayments;

  /// No description provided for @monNet.
  ///
  /// In fa, this message translates to:
  /// **'خالص'**
  String get monNet;

  /// No description provided for @monProbableReceipts.
  ///
  /// In fa, this message translates to:
  /// **'دریافت محتمل'**
  String get monProbableReceipts;

  /// No description provided for @monProbablePayments.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت محتمل'**
  String get monProbablePayments;

  /// No description provided for @monOverdueReceipts.
  ///
  /// In fa, this message translates to:
  /// **'دریافت معوق'**
  String get monOverdueReceipts;

  /// No description provided for @monOverduePayments.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت معوق'**
  String get monOverduePayments;

  /// No description provided for @monSalesWon.
  ///
  /// In fa, this message translates to:
  /// **'برده‌شده'**
  String get monSalesWon;

  /// No description provided for @monSalesOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز'**
  String get monSalesOpen;

  /// No description provided for @monSalesLost.
  ///
  /// In fa, this message translates to:
  /// **'ازدست‌رفته'**
  String get monSalesLost;

  /// No description provided for @monAccess.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی'**
  String get monAccess;

  /// No description provided for @monAccessTitle.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی گروه'**
  String get monAccessTitle;

  /// No description provided for @monAccessAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن عضو'**
  String get monAccessAdd;

  /// No description provided for @monAccessRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف دسترسی'**
  String get monAccessRemove;

  /// No description provided for @monAccessSaved.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی ذخیره شد'**
  String get monAccessSaved;

  /// No description provided for @monRoleManager.
  ///
  /// In fa, this message translates to:
  /// **'مدیر'**
  String get monRoleManager;

  /// No description provided for @monRoleMember.
  ///
  /// In fa, this message translates to:
  /// **'عضو'**
  String get monRoleMember;

  /// No description provided for @monRoleViewer.
  ///
  /// In fa, this message translates to:
  /// **'بیننده'**
  String get monRoleViewer;

  /// No description provided for @monAccessPick.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب فرد'**
  String get monAccessPick;

  /// No description provided for @monEmpty.
  ///
  /// In fa, this message translates to:
  /// **'داده‌ای برای نمایش نیست'**
  String get monEmpty;

  /// No description provided for @monStatusOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز'**
  String get monStatusOpen;

  /// No description provided for @monStatusAwaiting.
  ///
  /// In fa, this message translates to:
  /// **'در انتظار'**
  String get monStatusAwaiting;

  /// No description provided for @monStatusDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام‌شده'**
  String get monStatusDone;

  /// No description provided for @monStatusCancelled.
  ///
  /// In fa, this message translates to:
  /// **'لغوشده'**
  String get monStatusCancelled;

  /// No description provided for @monTotal.
  ///
  /// In fa, this message translates to:
  /// **'کل'**
  String get monTotal;

  /// No description provided for @commonRial.
  ///
  /// In fa, this message translates to:
  /// **'ریال'**
  String get commonRial;

  /// No description provided for @moneyFiles.
  ///
  /// In fa, this message translates to:
  /// **'پیوست‌ها'**
  String get moneyFiles;

  /// No description provided for @moneyLabels.
  ///
  /// In fa, this message translates to:
  /// **'برچسب‌ها'**
  String get moneyLabels;

  /// No description provided for @moneyVoidReasonRequired.
  ///
  /// In fa, this message translates to:
  /// **'دلیل را بنویسید.'**
  String get moneyVoidReasonRequired;

  /// No description provided for @moneyChartLabel.
  ///
  /// In fa, this message translates to:
  /// **'نمودار میله‌ای'**
  String get moneyChartLabel;

  /// No description provided for @moduleFinance.
  ///
  /// In fa, this message translates to:
  /// **'مالی'**
  String get moduleFinance;

  /// No description provided for @moduleSales.
  ///
  /// In fa, this message translates to:
  /// **'فروش'**
  String get moduleSales;

  /// No description provided for @moduleCrm.
  ///
  /// In fa, this message translates to:
  /// **'مشتریان'**
  String get moduleCrm;

  /// No description provided for @crmTitle.
  ///
  /// In fa, this message translates to:
  /// **'پرونده مشتری'**
  String get crmTitle;

  /// No description provided for @crmNew.
  ///
  /// In fa, this message translates to:
  /// **'مشتری جدید'**
  String get crmNew;

  /// No description provided for @crmEditTitle.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش مشتری'**
  String get crmEditTitle;

  /// No description provided for @crmSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی نام، تلفن، ایمیل یا کد ملی'**
  String get crmSearchHint;

  /// No description provided for @crmFilterAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get crmFilterAll;

  /// No description provided for @crmLoadMore.
  ///
  /// In fa, this message translates to:
  /// **'نمایش بیشتر'**
  String get crmLoadMore;

  /// No description provided for @crmLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگیری مشتریان ممکن نشد'**
  String get crmLoadFailed;

  /// No description provided for @crmEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'مشتری‌ای پیدا نشد'**
  String get crmEmptyTitle;

  /// No description provided for @crmEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'با دکمه «مشتری جدید» اولین پرونده را بسازید.'**
  String get crmEmptyMessage;

  /// No description provided for @crmKindPerson.
  ///
  /// In fa, this message translates to:
  /// **'شخص'**
  String get crmKindPerson;

  /// No description provided for @crmKindCompany.
  ///
  /// In fa, this message translates to:
  /// **'شرکت'**
  String get crmKindCompany;

  /// No description provided for @crmStatusActive.
  ///
  /// In fa, this message translates to:
  /// **'فعال'**
  String get crmStatusActive;

  /// No description provided for @crmStatusInactive.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال'**
  String get crmStatusInactive;

  /// No description provided for @crmStatusArchived.
  ///
  /// In fa, this message translates to:
  /// **'بایگانی'**
  String get crmStatusArchived;

  /// No description provided for @crmRoleManager.
  ///
  /// In fa, this message translates to:
  /// **'مدیر'**
  String get crmRoleManager;

  /// No description provided for @crmRoleMember.
  ///
  /// In fa, this message translates to:
  /// **'عضو'**
  String get crmRoleMember;

  /// No description provided for @crmRoleViewer.
  ///
  /// In fa, this message translates to:
  /// **'ناظر'**
  String get crmRoleViewer;

  /// No description provided for @crmFieldKind.
  ///
  /// In fa, this message translates to:
  /// **'نوع'**
  String get crmFieldKind;

  /// No description provided for @crmFieldStatus.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت'**
  String get crmFieldStatus;

  /// No description provided for @crmFieldName.
  ///
  /// In fa, this message translates to:
  /// **'نام'**
  String get crmFieldName;

  /// No description provided for @crmFieldLegalName.
  ///
  /// In fa, this message translates to:
  /// **'نام حقوقی'**
  String get crmFieldLegalName;

  /// No description provided for @crmFieldRegistrationNo.
  ///
  /// In fa, this message translates to:
  /// **'شماره ثبت'**
  String get crmFieldRegistrationNo;

  /// No description provided for @crmFieldNationalId.
  ///
  /// In fa, this message translates to:
  /// **'کد ملی / شناسه ملی'**
  String get crmFieldNationalId;

  /// No description provided for @crmFieldPhone.
  ///
  /// In fa, this message translates to:
  /// **'تلفن'**
  String get crmFieldPhone;

  /// No description provided for @crmFieldMobile.
  ///
  /// In fa, this message translates to:
  /// **'موبایل'**
  String get crmFieldMobile;

  /// No description provided for @crmFieldEmail.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل'**
  String get crmFieldEmail;

  /// No description provided for @crmFieldAddress.
  ///
  /// In fa, this message translates to:
  /// **'نشانی'**
  String get crmFieldAddress;

  /// No description provided for @crmFieldNotes.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت‌ها'**
  String get crmFieldNotes;

  /// No description provided for @crmFieldOwner.
  ///
  /// In fa, this message translates to:
  /// **'مسئول پرونده'**
  String get crmFieldOwner;

  /// No description provided for @crmNameRequired.
  ///
  /// In fa, this message translates to:
  /// **'نام را وارد کنید.'**
  String get crmNameRequired;

  /// No description provided for @crmLimitReached.
  ///
  /// In fa, this message translates to:
  /// **'سقف تعداد پرونده‌های مشتری پر شده است.'**
  String get crmLimitReached;

  /// No description provided for @crmSaveFailed.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره انجام نشد'**
  String get crmSaveFailed;

  /// No description provided for @crmTabOverview.
  ///
  /// In fa, this message translates to:
  /// **'نمای کلی'**
  String get crmTabOverview;

  /// No description provided for @crmTabTimeline.
  ///
  /// In fa, this message translates to:
  /// **'خط زمانی'**
  String get crmTabTimeline;

  /// No description provided for @crmTabTasks.
  ///
  /// In fa, this message translates to:
  /// **'وظایف'**
  String get crmTabTasks;

  /// No description provided for @crmTabMeetings.
  ///
  /// In fa, this message translates to:
  /// **'جلسات'**
  String get crmTabMeetings;

  /// No description provided for @crmTabLetters.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌ها'**
  String get crmTabLetters;

  /// No description provided for @crmTabFiles.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌ها و اسناد'**
  String get crmTabFiles;

  /// No description provided for @crmTabCalls.
  ///
  /// In fa, this message translates to:
  /// **'گزارش تماس'**
  String get crmTabCalls;

  /// No description provided for @crmTabFinance.
  ///
  /// In fa, this message translates to:
  /// **'مالی'**
  String get crmTabFinance;

  /// No description provided for @crmTabLeads.
  ///
  /// In fa, this message translates to:
  /// **'فروش'**
  String get crmTabLeads;

  /// No description provided for @crmTabChat.
  ///
  /// In fa, this message translates to:
  /// **'گفتگو'**
  String get crmTabChat;

  /// No description provided for @crmTabMembers.
  ///
  /// In fa, this message translates to:
  /// **'اعضا'**
  String get crmTabMembers;

  /// No description provided for @crmNoteHint.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت جدید برای خط زمانی'**
  String get crmNoteHint;

  /// No description provided for @crmNoteAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن یادداشت'**
  String get crmNoteAdd;

  /// No description provided for @crmTimelineEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز رویدادی ثبت نشده.'**
  String get crmTimelineEmpty;

  /// No description provided for @crmEventNote.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت'**
  String get crmEventNote;

  /// No description provided for @crmEventCall.
  ///
  /// In fa, this message translates to:
  /// **'تماس'**
  String get crmEventCall;

  /// No description provided for @crmEventMeeting.
  ///
  /// In fa, this message translates to:
  /// **'جلسه'**
  String get crmEventMeeting;

  /// No description provided for @crmEventFinance.
  ///
  /// In fa, this message translates to:
  /// **'مالی'**
  String get crmEventFinance;

  /// No description provided for @crmEventLead.
  ///
  /// In fa, this message translates to:
  /// **'فروش'**
  String get crmEventLead;

  /// No description provided for @crmEventSystem.
  ///
  /// In fa, this message translates to:
  /// **'سیستم'**
  String get crmEventSystem;

  /// No description provided for @crmEventTask.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه'**
  String get crmEventTask;

  /// No description provided for @crmEventLetter.
  ///
  /// In fa, this message translates to:
  /// **'نامه'**
  String get crmEventLetter;

  /// No description provided for @crmTasksEmpty.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه‌ای به این پرونده وصل نیست.'**
  String get crmTasksEmpty;

  /// No description provided for @crmTaskNew.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه جدید'**
  String get crmTaskNew;

  /// No description provided for @crmMeetingsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'جلسه‌ای به این پرونده وصل نیست.'**
  String get crmMeetingsEmpty;

  /// No description provided for @crmMeetingNew.
  ///
  /// In fa, this message translates to:
  /// **'جلسه جدید'**
  String get crmMeetingNew;

  /// No description provided for @crmLettersEmpty.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌ای به این پرونده وصل نیست.'**
  String get crmLettersEmpty;

  /// No description provided for @crmCallsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'تماسی ثبت نشده.'**
  String get crmCallsEmpty;

  /// No description provided for @crmCallNew.
  ///
  /// In fa, this message translates to:
  /// **'ثبت تماس'**
  String get crmCallNew;

  /// No description provided for @crmCallIn.
  ///
  /// In fa, this message translates to:
  /// **'ورودی'**
  String get crmCallIn;

  /// No description provided for @crmCallOut.
  ///
  /// In fa, this message translates to:
  /// **'خروجی'**
  String get crmCallOut;

  /// No description provided for @crmCallContact.
  ///
  /// In fa, this message translates to:
  /// **'نام مخاطب'**
  String get crmCallContact;

  /// No description provided for @crmCallSummary.
  ///
  /// In fa, this message translates to:
  /// **'خلاصه گفتگو'**
  String get crmCallSummary;

  /// No description provided for @crmCallDuration.
  ///
  /// In fa, this message translates to:
  /// **'مدت (دقیقه)'**
  String get crmCallDuration;

  /// No description provided for @crmCallNoContact.
  ///
  /// In fa, this message translates to:
  /// **'بدون نام'**
  String get crmCallNoContact;

  /// No description provided for @crmCallToTask.
  ///
  /// In fa, this message translates to:
  /// **'تبدیل به وظیفه'**
  String get crmCallToTask;

  /// No description provided for @crmCallTaskCreated.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه پیگیری ساخته شد.'**
  String get crmCallTaskCreated;

  /// No description provided for @crmMembersAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن عضو'**
  String get crmMembersAdd;

  /// No description provided for @crmMemberRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف عضو'**
  String get crmMemberRemove;

  /// No description provided for @crmImport.
  ///
  /// In fa, this message translates to:
  /// **'درون‌ریزی از اکسل'**
  String get crmImport;

  /// No description provided for @crmImportHelp.
  ///
  /// In fa, this message translates to:
  /// **'فایل CSV یا xlsx با ستون‌های kind, name, legal_name, national_id, phone, mobile, email, address, status انتخاب کنید؛ فقط name الزامی است.'**
  String get crmImportHelp;

  /// No description provided for @crmImportPick.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب فایل'**
  String get crmImportPick;

  /// No description provided for @crmImportFailed.
  ///
  /// In fa, this message translates to:
  /// **'درون‌ریزی انجام نشد.'**
  String get crmImportFailed;

  /// No description provided for @crmCallMinutes.
  ///
  /// In fa, this message translates to:
  /// **'{minutes} دقیقه'**
  String crmCallMinutes(String minutes);

  /// No description provided for @crmImportRow.
  ///
  /// In fa, this message translates to:
  /// **'ردیف {row}'**
  String crmImportRow(String row);

  /// No description provided for @crmImportSummary.
  ///
  /// In fa, this message translates to:
  /// **'{created} ایجاد، {skipped} ردشده، {errors} خطا'**
  String crmImportSummary(String created, String skipped, String errors);

  /// No description provided for @financeTabDocs.
  ///
  /// In fa, this message translates to:
  /// **'اسناد'**
  String get financeTabDocs;

  /// No description provided for @financeTabReport.
  ///
  /// In fa, this message translates to:
  /// **'گزارش'**
  String get financeTabReport;

  /// No description provided for @financeTabMonitor.
  ///
  /// In fa, this message translates to:
  /// **'پایش'**
  String get financeTabMonitor;

  /// No description provided for @financeNew.
  ///
  /// In fa, this message translates to:
  /// **'سند مالی جدید'**
  String get financeNew;

  /// No description provided for @financeEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش سند مالی'**
  String get financeEdit;

  /// No description provided for @financeSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجو در مشتری، مبلغ و توضیحات'**
  String get financeSearchHint;

  /// No description provided for @financeLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری اسناد مالی ممکن نشد'**
  String get financeLoadFailed;

  /// No description provided for @financeEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'سندی پیدا نشد'**
  String get financeEmptyTitle;

  /// No description provided for @financeEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'با دکمه «سند مالی جدید» اولین سند را ثبت کنید.'**
  String get financeEmptyMessage;

  /// No description provided for @financeFilterAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get financeFilterAll;

  /// No description provided for @financeKindCash.
  ///
  /// In fa, this message translates to:
  /// **'نقد'**
  String get financeKindCash;

  /// No description provided for @financeKindCheque.
  ///
  /// In fa, this message translates to:
  /// **'چک'**
  String get financeKindCheque;

  /// No description provided for @financeKindProbable.
  ///
  /// In fa, this message translates to:
  /// **'احتمالی'**
  String get financeKindProbable;

  /// No description provided for @financeKindVoid.
  ///
  /// In fa, this message translates to:
  /// **'باطل'**
  String get financeKindVoid;

  /// No description provided for @financeDirReceipt.
  ///
  /// In fa, this message translates to:
  /// **'دریافت'**
  String get financeDirReceipt;

  /// No description provided for @financeDirPayment.
  ///
  /// In fa, this message translates to:
  /// **'پرداخت'**
  String get financeDirPayment;

  /// No description provided for @financeStatusConfirmed.
  ///
  /// In fa, this message translates to:
  /// **'قطعی'**
  String get financeStatusConfirmed;

  /// No description provided for @financeStatusPending.
  ///
  /// In fa, this message translates to:
  /// **'در انتظار'**
  String get financeStatusPending;

  /// No description provided for @financeStatusVoid.
  ///
  /// In fa, this message translates to:
  /// **'باطل‌شده'**
  String get financeStatusVoid;

  /// No description provided for @financeOverdue.
  ///
  /// In fa, this message translates to:
  /// **'سررسید گذشته'**
  String get financeOverdue;

  /// No description provided for @financeKind.
  ///
  /// In fa, this message translates to:
  /// **'نوع سند'**
  String get financeKind;

  /// No description provided for @financeDirection.
  ///
  /// In fa, this message translates to:
  /// **'جهت'**
  String get financeDirection;

  /// No description provided for @financeAmount.
  ///
  /// In fa, this message translates to:
  /// **'مبلغ (ریال)'**
  String get financeAmount;

  /// No description provided for @financeDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ'**
  String get financeDate;

  /// No description provided for @financeDueDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ سررسید'**
  String get financeDueDate;

  /// No description provided for @financeDescription.
  ///
  /// In fa, this message translates to:
  /// **'توضیحات'**
  String get financeDescription;

  /// No description provided for @financeCustomer.
  ///
  /// In fa, this message translates to:
  /// **'مشتری: {name}'**
  String financeCustomer(String name);

  /// No description provided for @financeAmountInvalid.
  ///
  /// In fa, this message translates to:
  /// **'مبلغ باید عددی مثبت باشد.'**
  String get financeAmountInvalid;

  /// No description provided for @financeDueRequired.
  ///
  /// In fa, this message translates to:
  /// **'برای چک و سند احتمالی تاریخ سررسید لازم است.'**
  String get financeDueRequired;

  /// No description provided for @financeSaved.
  ///
  /// In fa, this message translates to:
  /// **'سند ذخیره شد.'**
  String get financeSaved;

  /// No description provided for @financeSaveFirstFiles.
  ///
  /// In fa, this message translates to:
  /// **'برای پیوست فایل، ابتدا سند را ذخیره کنید.'**
  String get financeSaveFirstFiles;

  /// No description provided for @financeConfirm.
  ///
  /// In fa, this message translates to:
  /// **'قطعی‌سازی'**
  String get financeConfirm;

  /// No description provided for @financeConfirmed.
  ///
  /// In fa, this message translates to:
  /// **'سند قطعی شد.'**
  String get financeConfirmed;

  /// No description provided for @financeVoid.
  ///
  /// In fa, this message translates to:
  /// **'ابطال سند'**
  String get financeVoid;

  /// No description provided for @financeVoidReason.
  ///
  /// In fa, this message translates to:
  /// **'دلیل ابطال'**
  String get financeVoidReason;

  /// No description provided for @financeVoidSubmit.
  ///
  /// In fa, this message translates to:
  /// **'ابطال'**
  String get financeVoidSubmit;

  /// No description provided for @financeVoidedBanner.
  ///
  /// In fa, this message translates to:
  /// **'این سند باطل شده است: {reason}'**
  String financeVoidedBanner(String reason);

  /// No description provided for @financeReportMonthly.
  ///
  /// In fa, this message translates to:
  /// **'ماهانه'**
  String get financeReportMonthly;

  /// No description provided for @financeReportYearly.
  ///
  /// In fa, this message translates to:
  /// **'سالانه'**
  String get financeReportYearly;

  /// No description provided for @financeReportEmpty.
  ///
  /// In fa, this message translates to:
  /// **'داده‌ای برای گزارش نیست.'**
  String get financeReportEmpty;

  /// No description provided for @financeColPeriod.
  ///
  /// In fa, this message translates to:
  /// **'دوره'**
  String get financeColPeriod;

  /// No description provided for @financeColReceipts.
  ///
  /// In fa, this message translates to:
  /// **'دریافتی'**
  String get financeColReceipts;

  /// No description provided for @financeColPayments.
  ///
  /// In fa, this message translates to:
  /// **'پرداختی'**
  String get financeColPayments;

  /// No description provided for @financeColNet.
  ///
  /// In fa, this message translates to:
  /// **'خالص'**
  String get financeColNet;

  /// No description provided for @financeTotals.
  ///
  /// In fa, this message translates to:
  /// **'جمع کل'**
  String get financeTotals;

  /// No description provided for @financeProbableReceipts.
  ///
  /// In fa, this message translates to:
  /// **'دریافتی احتمالی'**
  String get financeProbableReceipts;

  /// No description provided for @financeProbablePayments.
  ///
  /// In fa, this message translates to:
  /// **'پرداختی احتمالی'**
  String get financeProbablePayments;

  /// No description provided for @financeOverdueReceipts.
  ///
  /// In fa, this message translates to:
  /// **'دریافتی معوق'**
  String get financeOverdueReceipts;

  /// No description provided for @financeProjectedNet.
  ///
  /// In fa, this message translates to:
  /// **'خالص پیش‌بینی‌شده'**
  String get financeProjectedNet;

  /// No description provided for @financeChartTitle.
  ///
  /// In fa, this message translates to:
  /// **'دریافتی و پرداختی قطعی'**
  String get financeChartTitle;

  /// No description provided for @financeDrillTitle.
  ///
  /// In fa, this message translates to:
  /// **'اسناد {period}'**
  String financeDrillTitle(String period);

  /// No description provided for @financeMonitorTitle.
  ///
  /// In fa, this message translates to:
  /// **'دریافتی‌های احتمالی و معوق'**
  String get financeMonitorTitle;

  /// No description provided for @financeMonitorOverdue.
  ///
  /// In fa, this message translates to:
  /// **'معوق'**
  String get financeMonitorOverdue;

  /// No description provided for @financeMonitorUpcoming.
  ///
  /// In fa, this message translates to:
  /// **'در راه'**
  String get financeMonitorUpcoming;

  /// No description provided for @financeMonitorEmpty.
  ///
  /// In fa, this message translates to:
  /// **'دریافتی احتمالی یا معوقی وجود ندارد.'**
  String get financeMonitorEmpty;

  /// No description provided for @financeCustomerTitle.
  ///
  /// In fa, this message translates to:
  /// **'گزارش مالی مشتری'**
  String get financeCustomerTitle;

  /// No description provided for @financeCustomerEmpty.
  ///
  /// In fa, this message translates to:
  /// **'سند مالی برای این مشتری ثبت نشده.'**
  String get financeCustomerEmpty;

  /// No description provided for @salesTabLeads.
  ///
  /// In fa, this message translates to:
  /// **'فرصت‌ها'**
  String get salesTabLeads;

  /// No description provided for @salesTabMonitor.
  ///
  /// In fa, this message translates to:
  /// **'پایش فروش'**
  String get salesTabMonitor;

  /// No description provided for @salesNew.
  ///
  /// In fa, this message translates to:
  /// **'فرصت فروش جدید'**
  String get salesNew;

  /// No description provided for @salesEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش فرصت فروش'**
  String get salesEdit;

  /// No description provided for @salesSearchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجو در عنوان و مشتری'**
  String get salesSearchHint;

  /// No description provided for @salesLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری فرصت‌های فروش ممکن نشد'**
  String get salesLoadFailed;

  /// No description provided for @salesEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'فرصت فروشی پیدا نشد'**
  String get salesEmptyTitle;

  /// No description provided for @salesEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'با دکمه «فرصت فروش جدید» اولین فرصت را ثبت کنید.'**
  String get salesEmptyMessage;

  /// No description provided for @salesStatusOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز'**
  String get salesStatusOpen;

  /// No description provided for @salesStatusWon.
  ///
  /// In fa, this message translates to:
  /// **'موفق'**
  String get salesStatusWon;

  /// No description provided for @salesStatusLost.
  ///
  /// In fa, this message translates to:
  /// **'ناموفق'**
  String get salesStatusLost;

  /// No description provided for @salesTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get salesTitle;

  /// No description provided for @salesValue.
  ///
  /// In fa, this message translates to:
  /// **'ارزش (ریال)'**
  String get salesValue;

  /// No description provided for @salesProbability.
  ///
  /// In fa, this message translates to:
  /// **'احتمال موفقیت: {percent}٪'**
  String salesProbability(String percent);

  /// No description provided for @salesOwner.
  ///
  /// In fa, this message translates to:
  /// **'مسئول'**
  String get salesOwner;

  /// No description provided for @salesDescription.
  ///
  /// In fa, this message translates to:
  /// **'توضیحات'**
  String get salesDescription;

  /// No description provided for @salesTitleRequired.
  ///
  /// In fa, this message translates to:
  /// **'عنوان را بنویسید.'**
  String get salesTitleRequired;

  /// No description provided for @salesSaved.
  ///
  /// In fa, this message translates to:
  /// **'فرصت ذخیره شد.'**
  String get salesSaved;

  /// No description provided for @salesSaveFirstFiles.
  ///
  /// In fa, this message translates to:
  /// **'برای پیوست فایل، ابتدا فرصت را ذخیره کنید.'**
  String get salesSaveFirstFiles;

  /// No description provided for @salesWin.
  ///
  /// In fa, this message translates to:
  /// **'موفق شد'**
  String get salesWin;

  /// No description provided for @salesLose.
  ///
  /// In fa, this message translates to:
  /// **'ناموفق بود'**
  String get salesLose;

  /// No description provided for @salesLoseReason.
  ///
  /// In fa, this message translates to:
  /// **'دلیل ناموفق بودن'**
  String get salesLoseReason;

  /// No description provided for @salesLoseSubmit.
  ///
  /// In fa, this message translates to:
  /// **'ثبت'**
  String get salesLoseSubmit;

  /// No description provided for @salesReopen.
  ///
  /// In fa, this message translates to:
  /// **'بازگشایی'**
  String get salesReopen;

  /// No description provided for @salesWeighted.
  ///
  /// In fa, this message translates to:
  /// **'ارزش وزنی: {amount}'**
  String salesWeighted(String amount);

  /// No description provided for @salesLostBanner.
  ///
  /// In fa, this message translates to:
  /// **'این فرصت ناموفق بسته شد: {reason}'**
  String salesLostBanner(String reason);

  /// No description provided for @salesMonitorWon.
  ///
  /// In fa, this message translates to:
  /// **'فروش موفق'**
  String get salesMonitorWon;

  /// No description provided for @salesMonitorProbable.
  ///
  /// In fa, this message translates to:
  /// **'فروش احتمالی (وزنی)'**
  String get salesMonitorProbable;

  /// No description provided for @salesMonitorOpen.
  ///
  /// In fa, this message translates to:
  /// **'مجموع فرصت‌های باز'**
  String get salesMonitorOpen;

  /// No description provided for @salesMonitorChart.
  ///
  /// In fa, this message translates to:
  /// **'موفق در برابر احتمالی'**
  String get salesMonitorChart;

  /// No description provided for @salesByBucket.
  ///
  /// In fa, this message translates to:
  /// **'فرصت‌های باز بر اساس احتمال'**
  String get salesByBucket;

  /// No description provided for @salesBucketLeads.
  ///
  /// In fa, this message translates to:
  /// **'فرصت‌های با احتمال {bucket}'**
  String salesBucketLeads(String bucket);

  /// No description provided for @salesWonByMonth.
  ///
  /// In fa, this message translates to:
  /// **'فروش موفق به تفکیک ماه'**
  String get salesWonByMonth;

  /// No description provided for @salesCountValue.
  ///
  /// In fa, this message translates to:
  /// **'{count} فرصت'**
  String salesCountValue(String count);

  /// No description provided for @salesCustomerTitle.
  ///
  /// In fa, this message translates to:
  /// **'فرصت‌های فروش مشتری'**
  String get salesCustomerTitle;

  /// No description provided for @salesCustomerEmpty.
  ///
  /// In fa, this message translates to:
  /// **'فرصت فروشی برای این مشتری ثبت نشده.'**
  String get salesCustomerEmpty;

  /// No description provided for @openFailed.
  ///
  /// In fa, this message translates to:
  /// **'باز کردن مورد ممکن نشد'**
  String get openFailed;

  /// No description provided for @bookmarkAdd.
  ///
  /// In fa, this message translates to:
  /// **'نشان‌دار کردن'**
  String get bookmarkAdd;

  /// No description provided for @bookmarkRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف نشان'**
  String get bookmarkRemove;

  /// No description provided for @bookmarkFailed.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره نشان ممکن نشد'**
  String get bookmarkFailed;

  /// No description provided for @bookmarksTitle.
  ///
  /// In fa, this message translates to:
  /// **'نشان‌شده‌ها'**
  String get bookmarksTitle;

  /// No description provided for @bookmarksEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز چیزی نشان نکرده‌اید'**
  String get bookmarksEmpty;

  /// No description provided for @bookmarksEmptyHint.
  ///
  /// In fa, this message translates to:
  /// **'با ستاره بالای وظیفه، نامه یا جلسه آن را نشان کنید.'**
  String get bookmarksEmptyHint;

  /// No description provided for @bookmarksLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری نشان‌شده‌ها ممکن نشد'**
  String get bookmarksLoadFailed;

  /// No description provided for @pinnedTitle.
  ///
  /// In fa, this message translates to:
  /// **'سنجاق‌شده‌ها'**
  String get pinnedTitle;

  /// No description provided for @pinnedEmpty.
  ///
  /// In fa, this message translates to:
  /// **'چیزی سنجاق نشده'**
  String get pinnedEmpty;

  /// No description provided for @pinnedEmptyHint.
  ///
  /// In fa, this message translates to:
  /// **'پروژه‌ها، مشتریان و گفتگوها را سنجاق کنید تا اینجا در دسترس باشند.'**
  String get pinnedEmptyHint;

  /// No description provided for @pinnedLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری سنجاق‌ها ممکن نشد'**
  String get pinnedLoadFailed;

  /// No description provided for @pinAdd.
  ///
  /// In fa, this message translates to:
  /// **'سنجاق کردن'**
  String get pinAdd;

  /// No description provided for @pinRemove.
  ///
  /// In fa, this message translates to:
  /// **'برداشتن سنجاق'**
  String get pinRemove;

  /// No description provided for @pinFailed.
  ///
  /// In fa, this message translates to:
  /// **'تغییر سنجاق ممکن نشد'**
  String get pinFailed;

  /// No description provided for @searchTitle.
  ///
  /// In fa, this message translates to:
  /// **'جستجو'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In fa, this message translates to:
  /// **'جستجو در همه بخش‌ها و نام فایل‌ها'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In fa, this message translates to:
  /// **'جستجو کنید'**
  String get searchPrompt;

  /// No description provided for @searchMinChars.
  ///
  /// In fa, this message translates to:
  /// **'دست‌کم دو نویسه وارد کنید.'**
  String get searchMinChars;

  /// No description provided for @searchNoResults.
  ///
  /// In fa, this message translates to:
  /// **'نتیجه‌ای پیدا نشد'**
  String get searchNoResults;

  /// No description provided for @searchFailed.
  ///
  /// In fa, this message translates to:
  /// **'جستجو ممکن نشد'**
  String get searchFailed;

  /// No description provided for @searchRateLimited.
  ///
  /// In fa, this message translates to:
  /// **'درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.'**
  String get searchRateLimited;

  /// No description provided for @searchModuleCrm.
  ///
  /// In fa, this message translates to:
  /// **'مشتریان'**
  String get searchModuleCrm;

  /// No description provided for @searchModuleChat.
  ///
  /// In fa, this message translates to:
  /// **'گفتگو'**
  String get searchModuleChat;

  /// No description provided for @searchModuleFinance.
  ///
  /// In fa, this message translates to:
  /// **'مالی'**
  String get searchModuleFinance;

  /// No description provided for @searchModuleSales.
  ///
  /// In fa, this message translates to:
  /// **'فروش'**
  String get searchModuleSales;

  /// No description provided for @searchModuleFiles.
  ///
  /// In fa, this message translates to:
  /// **'فایل‌ها'**
  String get searchModuleFiles;

  /// No description provided for @searchFileIn.
  ///
  /// In fa, this message translates to:
  /// **'این فایل در «{owner}» است.'**
  String searchFileIn(String owner);

  /// No description provided for @calendarTitle.
  ///
  /// In fa, this message translates to:
  /// **'تقویم'**
  String get calendarTitle;

  /// No description provided for @calendarMonth.
  ///
  /// In fa, this message translates to:
  /// **'ماه'**
  String get calendarMonth;

  /// No description provided for @calendarWeek.
  ///
  /// In fa, this message translates to:
  /// **'هفته'**
  String get calendarWeek;

  /// No description provided for @calendarTeam.
  ///
  /// In fa, this message translates to:
  /// **'تیم'**
  String get calendarTeam;

  /// No description provided for @calendarColleagues.
  ///
  /// In fa, this message translates to:
  /// **'وظایف همکار'**
  String get calendarColleagues;

  /// No description provided for @calendarFilters.
  ///
  /// In fa, this message translates to:
  /// **'فیلتر'**
  String get calendarFilters;

  /// No description provided for @calendarLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری تقویم ممکن نشد'**
  String get calendarLoadFailed;

  /// No description provided for @calendarDayNothing.
  ///
  /// In fa, this message translates to:
  /// **'موردی در این روز نیست.'**
  String get calendarDayNothing;

  /// No description provided for @calendarAllDay.
  ///
  /// In fa, this message translates to:
  /// **'تمام روز'**
  String get calendarAllDay;

  /// No description provided for @calendarKindTask.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه'**
  String get calendarKindTask;

  /// No description provided for @calendarKindMeeting.
  ///
  /// In fa, this message translates to:
  /// **'جلسه'**
  String get calendarKindMeeting;

  /// No description provided for @calendarKindReminder.
  ///
  /// In fa, this message translates to:
  /// **'یادآوری'**
  String get calendarKindReminder;

  /// No description provided for @calendarKindProject.
  ///
  /// In fa, this message translates to:
  /// **'پروژه'**
  String get calendarKindProject;

  /// No description provided for @calendarFilterProject.
  ///
  /// In fa, this message translates to:
  /// **'پروژه'**
  String get calendarFilterProject;

  /// No description provided for @calendarFilterLabel.
  ///
  /// In fa, this message translates to:
  /// **'برچسب'**
  String get calendarFilterLabel;

  /// No description provided for @calendarFilterPerson.
  ///
  /// In fa, this message translates to:
  /// **'فرد'**
  String get calendarFilterPerson;

  /// No description provided for @calendarFilterCustomer.
  ///
  /// In fa, this message translates to:
  /// **'مشتری'**
  String get calendarFilterCustomer;

  /// No description provided for @calendarFilterAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get calendarFilterAll;

  /// No description provided for @calendarFilterApply.
  ///
  /// In fa, this message translates to:
  /// **'اعمال'**
  String get calendarFilterApply;

  /// No description provided for @calendarFilterReset.
  ///
  /// In fa, this message translates to:
  /// **'پاک کردن فیلترها'**
  String get calendarFilterReset;

  /// No description provided for @calendarStatusAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get calendarStatusAll;

  /// No description provided for @calendarStatusOpen.
  ///
  /// In fa, this message translates to:
  /// **'باز'**
  String get calendarStatusOpen;

  /// No description provided for @calendarStatusDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام‌شده'**
  String get calendarStatusDone;

  /// No description provided for @calendarPickPerson.
  ///
  /// In fa, this message translates to:
  /// **'یک همکار را انتخاب کنید'**
  String get calendarPickPerson;

  /// No description provided for @calendarMonitorForbidden.
  ///
  /// In fa, this message translates to:
  /// **'اجازه مشاهده وظایف همکاران را ندارید.'**
  String get calendarMonitorForbidden;

  /// No description provided for @calendarColleagueEmpty.
  ///
  /// In fa, this message translates to:
  /// **'وظیفه فعالی نیست.'**
  String get calendarColleagueEmpty;

  /// No description provided for @settingsTitle.
  ///
  /// In fa, this message translates to:
  /// **'تنظیمات'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In fa, this message translates to:
  /// **'تم'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In fa, this message translates to:
  /// **'روشن'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In fa, this message translates to:
  /// **'تیره'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeAuto.
  ///
  /// In fa, this message translates to:
  /// **'خودکار'**
  String get settingsThemeAuto;

  /// No description provided for @settingsBackground.
  ///
  /// In fa, this message translates to:
  /// **'تصویر پس‌زمینه'**
  String get settingsBackground;

  /// No description provided for @settingsBackgroundChoose.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب تصویر'**
  String get settingsBackgroundChoose;

  /// No description provided for @settingsBackgroundRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف تصویر'**
  String get settingsBackgroundRemove;

  /// No description provided for @settingsTitleLabel.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get settingsTitleLabel;

  /// No description provided for @settingsStatus.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت'**
  String get settingsStatus;

  /// No description provided for @settingsBirthday.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ تولد'**
  String get settingsBirthday;

  /// No description provided for @settingsBirthdayVisible.
  ///
  /// In fa, this message translates to:
  /// **'نمایش تولد به همکاران'**
  String get settingsBirthdayVisible;

  /// No description provided for @settingsDnd.
  ///
  /// In fa, this message translates to:
  /// **'مزاحم نشوید'**
  String get settingsDnd;

  /// No description provided for @settingsDndOff.
  ///
  /// In fa, this message translates to:
  /// **'خاموش است'**
  String get settingsDndOff;

  /// No description provided for @settingsDndTurnOff.
  ///
  /// In fa, this message translates to:
  /// **'خاموش کردن'**
  String get settingsDndTurnOff;

  /// No description provided for @settingsDndUntil.
  ///
  /// In fa, this message translates to:
  /// **'تا {when}'**
  String settingsDndUntil(String when);

  /// No description provided for @settingsDndHours.
  ///
  /// In fa, this message translates to:
  /// **'{hours} ساعت'**
  String settingsDndHours(String hours);

  /// No description provided for @prefsFailed.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره تنظیمات ممکن نشد'**
  String get prefsFailed;

  /// No description provided for @personalEmailTitle.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل شخصی'**
  String get personalEmailTitle;

  /// No description provided for @personalEmailField.
  ///
  /// In fa, this message translates to:
  /// **'نشانی ایمیل'**
  String get personalEmailField;

  /// No description provided for @personalEmailSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال کد تأیید'**
  String get personalEmailSend;

  /// No description provided for @personalEmailToken.
  ///
  /// In fa, this message translates to:
  /// **'کد تأیید'**
  String get personalEmailToken;

  /// No description provided for @personalEmailVerify.
  ///
  /// In fa, this message translates to:
  /// **'تأیید ایمیل'**
  String get personalEmailVerify;

  /// No description provided for @personalEmailSent.
  ///
  /// In fa, this message translates to:
  /// **'کد تأیید به ایمیل ارسال شد.'**
  String get personalEmailSent;

  /// No description provided for @personalEmailFailed.
  ///
  /// In fa, this message translates to:
  /// **'ارسال ممکن نشد؛ نشانی را بررسی کنید.'**
  String get personalEmailFailed;

  /// No description provided for @personalEmailVerified.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل تأیید شد.'**
  String get personalEmailVerified;

  /// No description provided for @personalEmailBadToken.
  ///
  /// In fa, this message translates to:
  /// **'کد نامعتبر یا منقضی است.'**
  String get personalEmailBadToken;

  /// No description provided for @personalEmailVerifiedBadge.
  ///
  /// In fa, this message translates to:
  /// **'تأییدشده'**
  String get personalEmailVerifiedBadge;

  /// No description provided for @personalEmailUnverified.
  ///
  /// In fa, this message translates to:
  /// **'تأییدنشده'**
  String get personalEmailUnverified;

  /// No description provided for @notificationsTitle.
  ///
  /// In fa, this message translates to:
  /// **'اعلان‌ها'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAll.
  ///
  /// In fa, this message translates to:
  /// **'خوانده شد'**
  String get notificationsMarkAll;

  /// No description provided for @notificationsUnread.
  ///
  /// In fa, this message translates to:
  /// **'خوانده‌نشده'**
  String get notificationsUnread;

  /// No description provided for @notificationsMentions.
  ///
  /// In fa, this message translates to:
  /// **'اشاره‌ها'**
  String get notificationsMentions;

  /// No description provided for @notificationsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'اعلانی نیست'**
  String get notificationsEmpty;

  /// No description provided for @notificationsNoMentions.
  ///
  /// In fa, this message translates to:
  /// **'کسی شما را نام نبرده'**
  String get notificationsNoMentions;

  /// No description provided for @notificationsLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری اعلان‌ها ممکن نشد'**
  String get notificationsLoadFailed;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In fa, this message translates to:
  /// **'خوش آمدید'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'برای ادامه وارد شوید'**
  String get authWelcomeSubtitle;

  /// No description provided for @authNewHere.
  ///
  /// In fa, this message translates to:
  /// **'تازه آمده‌اید؟'**
  String get authNewHere;

  /// No description provided for @authCreateAccount.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد حساب'**
  String get authCreateAccount;

  /// No description provided for @authEnterPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور را وارد کنید'**
  String get authEnterPassword;

  /// No description provided for @authSignIn.
  ///
  /// In fa, this message translates to:
  /// **'ورود'**
  String get authSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In fa, this message translates to:
  /// **'فراموشی رمز عبور'**
  String get authForgotPassword;

  /// No description provided for @authServerUnreachable.
  ///
  /// In fa, this message translates to:
  /// **'اتصال به سرور برقرار نشد'**
  String get authServerUnreachable;

  /// No description provided for @authRegistered.
  ///
  /// In fa, this message translates to:
  /// **'ثبت‌نام انجام شد. اکنون وارد شوید.'**
  String get authRegistered;

  /// No description provided for @authEmailVerified.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل تأیید شد. اکنون وارد شوید.'**
  String get authEmailVerified;

  /// No description provided for @authCheckEmailTitle.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل خود را بررسی کنید'**
  String get authCheckEmailTitle;

  /// No description provided for @authCheckEmailSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'کد ارسال‌شده به ایمیل را برای تأیید نشانی خود وارد کنید.'**
  String get authCheckEmailSubtitle;

  /// No description provided for @authVerifyTokenLabel.
  ///
  /// In fa, this message translates to:
  /// **'کد تأیید'**
  String get authVerifyTokenLabel;

  /// No description provided for @authVerify.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get authVerify;

  /// No description provided for @authSignupSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'به فضای کاری شرکت بپیوندید'**
  String get authSignupSubtitle;

  /// No description provided for @authFullName.
  ///
  /// In fa, this message translates to:
  /// **'نام و نام خانوادگی'**
  String get authFullName;

  /// No description provided for @authEnterFullName.
  ///
  /// In fa, this message translates to:
  /// **'نام و نام خانوادگی را وارد کنید'**
  String get authEnterFullName;

  /// No description provided for @authInviteCodeOptional.
  ///
  /// In fa, this message translates to:
  /// **'کد دعوت (اختیاری)'**
  String get authInviteCodeOptional;

  /// No description provided for @authInviteHelper.
  ///
  /// In fa, this message translates to:
  /// **'برای ثبت‌نام با ایمیل سازمانی، خالی بگذارید'**
  String get authInviteHelper;

  /// No description provided for @authSignUp.
  ///
  /// In fa, this message translates to:
  /// **'ثبت‌نام'**
  String get authSignUp;

  /// No description provided for @authHaveAccount.
  ///
  /// In fa, this message translates to:
  /// **'حساب کاربری دارید؟'**
  String get authHaveAccount;

  /// No description provided for @authBackToSignIn.
  ///
  /// In fa, this message translates to:
  /// **'بازگشت به ورود'**
  String get authBackToSignIn;

  /// No description provided for @authResetTitle.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی رمز عبور'**
  String get authResetTitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'کدی به ایمیل شما می‌فرستیم، سپس رمز عبور جدید انتخاب می‌کنید.'**
  String get authResetSubtitle;

  /// No description provided for @authEmailMeToken.
  ///
  /// In fa, this message translates to:
  /// **'ارسال کد به ایمیل'**
  String get authEmailMeToken;

  /// No description provided for @authResetRequested.
  ///
  /// In fa, this message translates to:
  /// **'اگر حساب وجود داشته باشد، کد به ایمیل ارسال شد.'**
  String get authResetRequested;

  /// No description provided for @authHaveToken.
  ///
  /// In fa, this message translates to:
  /// **'کد دارید (ایمیل‌شده یا دریافتی از مدیر)؟'**
  String get authHaveToken;

  /// No description provided for @authToken.
  ///
  /// In fa, this message translates to:
  /// **'کد'**
  String get authToken;

  /// No description provided for @authEnterToken.
  ///
  /// In fa, this message translates to:
  /// **'کد را وارد کنید'**
  String get authEnterToken;

  /// No description provided for @authNewPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور جدید'**
  String get authNewPassword;

  /// No description provided for @authSetNewPassword.
  ///
  /// In fa, this message translates to:
  /// **'ثبت رمز عبور جدید'**
  String get authSetNewPassword;

  /// No description provided for @authPasswordChangedSignIn.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور تغییر کرد. اکنون وارد شوید.'**
  String get authPasswordChangedSignIn;

  /// No description provided for @authEmail.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور'**
  String get authPassword;

  /// No description provided for @authEnterEmail.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل را وارد کنید'**
  String get authEnterEmail;

  /// No description provided for @authEnterValidEmail.
  ///
  /// In fa, this message translates to:
  /// **'نشانی ایمیل معتبر وارد کنید'**
  String get authEnterValidEmail;

  /// No description provided for @authPasswordHint.
  ///
  /// In fa, this message translates to:
  /// **'حداقل {min} نویسه؛ از رمزهای رایج استفاده نکنید'**
  String authPasswordHint(String min);

  /// No description provided for @authPasswordTooShort.
  ///
  /// In fa, this message translates to:
  /// **'حداقل {min} نویسه وارد کنید'**
  String authPasswordTooShort(String min);

  /// No description provided for @authPinDigits.
  ///
  /// In fa, this message translates to:
  /// **'{count} رقم وارد کنید'**
  String authPinDigits(String count);

  /// No description provided for @authShowPassword.
  ///
  /// In fa, this message translates to:
  /// **'نمایش رمز عبور'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In fa, this message translates to:
  /// **'پنهان کردن رمز عبور'**
  String get authHidePassword;

  /// No description provided for @authSigningPin.
  ///
  /// In fa, this message translates to:
  /// **'رمز امضا'**
  String get authSigningPin;

  /// No description provided for @permMember.
  ///
  /// In fa, this message translates to:
  /// **'عضو'**
  String get permMember;

  /// No description provided for @permLetterCreate.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد نامه'**
  String get permLetterCreate;

  /// No description provided for @permLetterSee.
  ///
  /// In fa, this message translates to:
  /// **'مشاهده نامه‌ها'**
  String get permLetterSee;

  /// No description provided for @permLetterSign.
  ///
  /// In fa, this message translates to:
  /// **'امضای نامه'**
  String get permLetterSign;

  /// No description provided for @relTimeNow.
  ///
  /// In fa, this message translates to:
  /// **'هم‌اکنون'**
  String get relTimeNow;

  /// No description provided for @relTimeMinutes.
  ///
  /// In fa, this message translates to:
  /// **'{n} دقیقه پیش'**
  String relTimeMinutes(String n);

  /// No description provided for @relTimeHours.
  ///
  /// In fa, this message translates to:
  /// **'{n} ساعت پیش'**
  String relTimeHours(String n);

  /// No description provided for @relTimeDays.
  ///
  /// In fa, this message translates to:
  /// **'{n} روز پیش'**
  String relTimeDays(String n);

  /// No description provided for @pollsTitle.
  ///
  /// In fa, this message translates to:
  /// **'نظرسنجی‌ها'**
  String get pollsTitle;

  /// No description provided for @pollsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز نظرسنجی‌ای نیست'**
  String get pollsEmpty;

  /// No description provided for @pollNew.
  ///
  /// In fa, this message translates to:
  /// **'نظرسنجی جدید'**
  String get pollNew;

  /// No description provided for @pollTitleField.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get pollTitleField;

  /// No description provided for @pollKind.
  ///
  /// In fa, this message translates to:
  /// **'نوع'**
  String get pollKind;

  /// No description provided for @pollKindPoll.
  ///
  /// In fa, this message translates to:
  /// **'نظرسنجی'**
  String get pollKindPoll;

  /// No description provided for @pollKindQuiz.
  ///
  /// In fa, this message translates to:
  /// **'آزمون'**
  String get pollKindQuiz;

  /// No description provided for @pollAnonymity.
  ///
  /// In fa, this message translates to:
  /// **'ناشناس بودن'**
  String get pollAnonymity;

  /// No description provided for @pollAnonPublic.
  ///
  /// In fa, this message translates to:
  /// **'عمومی: نام رأی‌دهندگان دیده می‌شود'**
  String get pollAnonPublic;

  /// No description provided for @pollAnonUsers.
  ///
  /// In fa, this message translates to:
  /// **'ناشناس برای اعضا: فقط مدیر نام‌ها را می‌بیند'**
  String get pollAnonUsers;

  /// No description provided for @pollAnonAll.
  ///
  /// In fa, this message translates to:
  /// **'کاملاً ناشناس'**
  String get pollAnonAll;

  /// No description provided for @pollQuestionText.
  ///
  /// In fa, this message translates to:
  /// **'متن پرسش'**
  String get pollQuestionText;

  /// No description provided for @pollAddQuestion.
  ///
  /// In fa, this message translates to:
  /// **'افزودن پرسش'**
  String get pollAddQuestion;

  /// No description provided for @pollRemoveQuestion.
  ///
  /// In fa, this message translates to:
  /// **'حذف پرسش'**
  String get pollRemoveQuestion;

  /// No description provided for @pollAddOption.
  ///
  /// In fa, this message translates to:
  /// **'افزودن گزینه'**
  String get pollAddOption;

  /// No description provided for @pollRemoveOption.
  ///
  /// In fa, this message translates to:
  /// **'حذف گزینه'**
  String get pollRemoveOption;

  /// No description provided for @pollOptionHint.
  ///
  /// In fa, this message translates to:
  /// **'گزینه'**
  String get pollOptionHint;

  /// No description provided for @pollMultiple.
  ///
  /// In fa, this message translates to:
  /// **'چند پاسخ مجاز است'**
  String get pollMultiple;

  /// No description provided for @pollPoints.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز'**
  String get pollPoints;

  /// No description provided for @pollCorrectHint.
  ///
  /// In fa, this message translates to:
  /// **'گزینه‌های صحیح را علامت بزنید'**
  String get pollCorrectHint;

  /// No description provided for @pollCreate.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد'**
  String get pollCreate;

  /// No description provided for @pollTemplates.
  ///
  /// In fa, this message translates to:
  /// **'الگوها'**
  String get pollTemplates;

  /// No description provided for @pollNoTemplates.
  ///
  /// In fa, this message translates to:
  /// **'الگویی ذخیره نشده'**
  String get pollNoTemplates;

  /// No description provided for @pollSaveTemplate.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره به‌عنوان الگو'**
  String get pollSaveTemplate;

  /// No description provided for @pollTemplateName.
  ///
  /// In fa, this message translates to:
  /// **'نام الگو'**
  String get pollTemplateName;

  /// No description provided for @pollTemplateSaved.
  ///
  /// In fa, this message translates to:
  /// **'الگو ذخیره شد'**
  String get pollTemplateSaved;

  /// No description provided for @pollSubmit.
  ///
  /// In fa, this message translates to:
  /// **'ثبت پاسخ'**
  String get pollSubmit;

  /// No description provided for @pollChangeAnswer.
  ///
  /// In fa, this message translates to:
  /// **'تغییر پاسخ'**
  String get pollChangeAnswer;

  /// No description provided for @pollSubmitted.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ شما ثبت شد'**
  String get pollSubmitted;

  /// No description provided for @pollClose.
  ///
  /// In fa, this message translates to:
  /// **'پایان نظرسنجی'**
  String get pollClose;

  /// No description provided for @pollCloseConfirm.
  ///
  /// In fa, this message translates to:
  /// **'با پایان‌دادن، دیگر پاسخی ثبت نمی‌شود. ادامه می‌دهید؟'**
  String get pollCloseConfirm;

  /// No description provided for @pollClosedBadge.
  ///
  /// In fa, this message translates to:
  /// **'پایان‌یافته'**
  String get pollClosedBadge;

  /// No description provided for @pollOpenBadge.
  ///
  /// In fa, this message translates to:
  /// **'باز'**
  String get pollOpenBadge;

  /// No description provided for @pollResults.
  ///
  /// In fa, this message translates to:
  /// **'نتایج'**
  String get pollResults;

  /// No description provided for @pollVoteFirst.
  ///
  /// In fa, this message translates to:
  /// **'برای دیدن نتایج ابتدا پاسخ دهید'**
  String get pollVoteFirst;

  /// No description provided for @pollVoters.
  ///
  /// In fa, this message translates to:
  /// **'رأی‌دهندگان'**
  String get pollVoters;

  /// No description provided for @pollVotersHidden.
  ///
  /// In fa, this message translates to:
  /// **'نام رأی‌دهندگان نمایش داده نمی‌شود'**
  String get pollVotersHidden;

  /// No description provided for @pollScores.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز شرکت‌کنندگان'**
  String get pollScores;

  /// No description provided for @pollCorrect.
  ///
  /// In fa, this message translates to:
  /// **'پاسخ صحیح'**
  String get pollCorrect;

  /// No description provided for @pollPrint.
  ///
  /// In fa, this message translates to:
  /// **'چاپ'**
  String get pollPrint;

  /// No description provided for @pollPrintTitle.
  ///
  /// In fa, this message translates to:
  /// **'نتایج آزمون'**
  String get pollPrintTitle;

  /// No description provided for @pollPrintDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ'**
  String get pollPrintDate;

  /// No description provided for @pollLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری نظرسنجی ممکن نشد'**
  String get pollLoadFailed;

  /// No description provided for @pollActionFailed.
  ///
  /// In fa, this message translates to:
  /// **'انجام کار ممکن نشد'**
  String get pollActionFailed;

  /// No description provided for @pollForbidden.
  ///
  /// In fa, this message translates to:
  /// **'اجازهٔ این کار را ندارید'**
  String get pollForbidden;

  /// No description provided for @pollNoTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان را بنویسید'**
  String get pollNoTitle;

  /// No description provided for @pollNoQuestion.
  ///
  /// In fa, this message translates to:
  /// **'هر پرسش به متن نیاز دارد و دست‌کم یک پرسش لازم است'**
  String get pollNoQuestion;

  /// No description provided for @pollTooFewOptions.
  ///
  /// In fa, this message translates to:
  /// **'هر پرسش دست‌کم دو گزینهٔ پر دارد'**
  String get pollTooFewOptions;

  /// No description provided for @pollNoCorrect.
  ///
  /// In fa, this message translates to:
  /// **'برای هر پرسش آزمون پاسخ صحیح انتخاب کنید'**
  String get pollNoCorrect;

  /// No description provided for @pollOpenPoll.
  ///
  /// In fa, this message translates to:
  /// **'باز کردن'**
  String get pollOpenPoll;

  /// No description provided for @pollNeedAnswer.
  ///
  /// In fa, this message translates to:
  /// **'دست‌کم یک گزینه انتخاب کنید'**
  String get pollNeedAnswer;

  /// No description provided for @pollQuestionN.
  ///
  /// In fa, this message translates to:
  /// **'پرسش {n}'**
  String pollQuestionN(String n);

  /// No description provided for @pollParticipants.
  ///
  /// In fa, this message translates to:
  /// **'{count} شرکت‌کننده'**
  String pollParticipants(String count);

  /// No description provided for @pollMyScore.
  ///
  /// In fa, this message translates to:
  /// **'امتیاز شما: {score} از {max}'**
  String pollMyScore(String score, String max);

  /// No description provided for @pollScoreLine.
  ///
  /// In fa, this message translates to:
  /// **'{name}: {score} از {max}'**
  String pollScoreLine(String name, String score, String max);

  /// No description provided for @pinNewLabel.
  ///
  /// In fa, this message translates to:
  /// **'رمز امضای جدید (۶ رقم)'**
  String get pinNewLabel;

  /// No description provided for @pinRepeatLabel.
  ///
  /// In fa, this message translates to:
  /// **'تکرار رمز امضا'**
  String get pinRepeatLabel;

  /// No description provided for @pinLoginPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور ورود'**
  String get pinLoginPassword;

  /// No description provided for @pinEnterLoginPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور ورود را وارد کنید'**
  String get pinEnterLoginPassword;

  /// No description provided for @pinMismatch.
  ///
  /// In fa, this message translates to:
  /// **'رمزهای امضا یکسان نیستند'**
  String get pinMismatch;

  /// No description provided for @pinSave.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره رمز امضا'**
  String get pinSave;

  /// No description provided for @pinGateTitle.
  ///
  /// In fa, this message translates to:
  /// **'رمز امضای خود را تعیین کنید'**
  String get pinGateTitle;

  /// No description provided for @pinGateSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'هر امضا را با این رمز ۶ رقمی، روی همه دستگاه‌هایتان تأیید می‌کنید.'**
  String get pinGateSubtitle;

  /// No description provided for @bioCancelled.
  ///
  /// In fa, this message translates to:
  /// **'بررسی اثر انگشت / چهره لغو شد'**
  String get bioCancelled;

  /// No description provided for @bioDialogTitle.
  ///
  /// In fa, this message translates to:
  /// **'استفاده از اثر انگشت / چهره در این دستگاه'**
  String get bioDialogTitle;

  /// No description provided for @bioDialogBody.
  ///
  /// In fa, this message translates to:
  /// **'امضاها را بدون وارد کردن رمز امضا تأیید کنید و اجازه دهید دستگاه‌های دیگرتان از این دستگاه برای تأیید درخواست کنند. برای فعال‌سازی، یک بار رمز امضا را وارد کنید.'**
  String get bioDialogBody;

  /// No description provided for @bioNotNow.
  ///
  /// In fa, this message translates to:
  /// **'فعلاً نه'**
  String get bioNotNow;

  /// No description provided for @bioEnable.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی'**
  String get bioEnable;

  /// No description provided for @bioEnableOnDevice.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی اثر انگشت / چهره در این دستگاه'**
  String get bioEnableOnDevice;

  /// No description provided for @sessionsSignOutTitle.
  ///
  /// In fa, this message translates to:
  /// **'خروج این دستگاه؟'**
  String get sessionsSignOutTitle;

  /// No description provided for @sessionsSignOutBody.
  ///
  /// In fa, this message translates to:
  /// **'{name} باید دوباره وارد شود.'**
  String sessionsSignOutBody(String name);

  /// No description provided for @sessionsSignOutAction.
  ///
  /// In fa, this message translates to:
  /// **'خروج'**
  String get sessionsSignOutAction;

  /// No description provided for @sessionsLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری دستگاه‌ها ممکن نشد'**
  String get sessionsLoadFailed;

  /// No description provided for @sessionsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'دستگاهی وارد نشده است'**
  String get sessionsEmpty;

  /// No description provided for @sessionsThisDevice.
  ///
  /// In fa, this message translates to:
  /// **'این دستگاه'**
  String get sessionsThisDevice;

  /// No description provided for @sessionsBiometric.
  ///
  /// In fa, this message translates to:
  /// **'زیست‌سنجی'**
  String get sessionsBiometric;

  /// No description provided for @sessionsActive.
  ///
  /// In fa, this message translates to:
  /// **'آخرین فعالیت: {when}'**
  String sessionsActive(String when);

  /// No description provided for @sessionsEnableBiometric.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی اثر انگشت / چهره'**
  String get sessionsEnableBiometric;

  /// No description provided for @sessionsSignOutDevice.
  ///
  /// In fa, this message translates to:
  /// **'خروج این دستگاه'**
  String get sessionsSignOutDevice;

  /// No description provided for @profileSaved.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره شد'**
  String get profileSaved;

  /// No description provided for @profilePasswordChanged.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور تغییر کرد؛ از دستگاه‌های دیگر خارج شدید'**
  String get profilePasswordChanged;

  /// No description provided for @profileManager.
  ///
  /// In fa, this message translates to:
  /// **'مدیر'**
  String get profileManager;

  /// No description provided for @profileSection.
  ///
  /// In fa, this message translates to:
  /// **'پروفایل'**
  String get profileSection;

  /// No description provided for @profileEnterName.
  ///
  /// In fa, this message translates to:
  /// **'نام را وارد کنید'**
  String get profileEnterName;

  /// No description provided for @profileJobTitle.
  ///
  /// In fa, this message translates to:
  /// **'سمت'**
  String get profileJobTitle;

  /// No description provided for @profileDepartmentReadonly.
  ///
  /// In fa, this message translates to:
  /// **'دپارتمان (تعیین‌شده توسط مدیر)'**
  String get profileDepartmentReadonly;

  /// No description provided for @profilePinChangeSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'رمز ۶ رقمی تأییدکننده امضاهایتان را تغییر دهید'**
  String get profilePinChangeSubtitle;

  /// No description provided for @profilePinSetSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'رمز ۶ رقمی تأییدکننده امضاهایتان را تعیین کنید'**
  String get profilePinSetSubtitle;

  /// No description provided for @profilePinSaved.
  ///
  /// In fa, this message translates to:
  /// **'رمز امضا ذخیره شد'**
  String get profilePinSaved;

  /// No description provided for @profileChangePassword.
  ///
  /// In fa, this message translates to:
  /// **'تغییر رمز عبور'**
  String get profileChangePassword;

  /// No description provided for @profileChangePasswordSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'پس از آن از دستگاه‌های دیگر خارج می‌شوید'**
  String get profileChangePasswordSubtitle;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور فعلی'**
  String get profileCurrentPassword;

  /// No description provided for @profileEnterCurrentPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور فعلی را وارد کنید'**
  String get profileEnterCurrentPassword;

  /// No description provided for @adminResetTokenTitle.
  ///
  /// In fa, this message translates to:
  /// **'رمز بازیابی رمز عبور'**
  String get adminResetTokenTitle;

  /// No description provided for @adminResetTokenBody.
  ///
  /// In fa, this message translates to:
  /// **'این کد را به {email} بدهید. فقط یک بار نمایش داده می‌شود.'**
  String adminResetTokenBody(String email);

  /// No description provided for @adminTokenCopied.
  ///
  /// In fa, this message translates to:
  /// **'کد کپی شد'**
  String get adminTokenCopied;

  /// No description provided for @adminCodeCopied.
  ///
  /// In fa, this message translates to:
  /// **'کد دعوت کپی شد'**
  String get adminCodeCopied;

  /// No description provided for @commonCopy.
  ///
  /// In fa, this message translates to:
  /// **'کپی'**
  String get commonCopy;

  /// No description provided for @adminPermissions.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی‌ها'**
  String get adminPermissions;

  /// No description provided for @adminAlwaysGranted.
  ///
  /// In fa, this message translates to:
  /// **'همیشه فعال'**
  String get adminAlwaysGranted;

  /// No description provided for @adminNewInviteTitle.
  ///
  /// In fa, this message translates to:
  /// **'کد دعوت جدید'**
  String get adminNewInviteTitle;

  /// No description provided for @adminMaxUses.
  ///
  /// In fa, this message translates to:
  /// **'حداکثر تعداد استفاده'**
  String get adminMaxUses;

  /// No description provided for @adminUnlimitedHelper.
  ///
  /// In fa, this message translates to:
  /// **'برای نامحدود، خالی بگذارید'**
  String get adminUnlimitedHelper;

  /// No description provided for @adminDepartment.
  ///
  /// In fa, this message translates to:
  /// **'دپارتمان'**
  String get adminDepartment;

  /// No description provided for @adminNone.
  ///
  /// In fa, this message translates to:
  /// **'بدون دپارتمان'**
  String get adminNone;

  /// No description provided for @adminInvitePermsHeader.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی افرادی که با این کد وارد می‌شوند'**
  String get adminInvitePermsHeader;

  /// No description provided for @commonCreate.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد'**
  String get commonCreate;

  /// No description provided for @adminLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری اطلاعات مدیریت ممکن نشد'**
  String get adminLoadFailed;

  /// No description provided for @adminSignupSection.
  ///
  /// In fa, this message translates to:
  /// **'ثبت‌نام'**
  String get adminSignupSection;

  /// No description provided for @adminSignupSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'نحوه پیوستن افراد جدید'**
  String get adminSignupSubtitle;

  /// No description provided for @adminDomainSignup.
  ///
  /// In fa, this message translates to:
  /// **'ثبت‌نام با ایمیل سازمانی'**
  String get adminDomainSignup;

  /// No description provided for @adminDomainLabel.
  ///
  /// In fa, this message translates to:
  /// **'دامنه: {domain}'**
  String adminDomainLabel(String domain);

  /// No description provided for @adminNeedsEmail.
  ///
  /// In fa, this message translates to:
  /// **'نیازمند پیکربندی ایمیل توسط مدیرکل است'**
  String get adminNeedsEmail;

  /// No description provided for @adminInviteSignup.
  ///
  /// In fa, this message translates to:
  /// **'ثبت‌نام با کد دعوت'**
  String get adminInviteSignup;

  /// No description provided for @adminInvitesSection.
  ///
  /// In fa, this message translates to:
  /// **'کدهای دعوت'**
  String get adminInvitesSection;

  /// No description provided for @adminNewCode.
  ///
  /// In fa, this message translates to:
  /// **'کد جدید'**
  String get adminNewCode;

  /// No description provided for @adminNoCodes.
  ///
  /// In fa, this message translates to:
  /// **'هنوز کدی وجود ندارد'**
  String get adminNoCodes;

  /// No description provided for @adminPeopleSection.
  ///
  /// In fa, this message translates to:
  /// **'افراد'**
  String get adminPeopleSection;

  /// No description provided for @adminInviteUses.
  ///
  /// In fa, this message translates to:
  /// **'{uses} از {max} استفاده شده'**
  String adminInviteUses(String max, String uses);

  /// No description provided for @adminCopyCode.
  ///
  /// In fa, this message translates to:
  /// **'کپی کد'**
  String get adminCopyCode;

  /// No description provided for @adminDeactivate.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال‌سازی'**
  String get adminDeactivate;

  /// No description provided for @adminInactive.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال'**
  String get adminInactive;

  /// No description provided for @adminDeactivated.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال‌شده'**
  String get adminDeactivated;

  /// No description provided for @adminActions.
  ///
  /// In fa, this message translates to:
  /// **'عملیات'**
  String get adminActions;

  /// No description provided for @adminReactivate.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی مجدد'**
  String get adminReactivate;

  /// No description provided for @adminIssueResetToken.
  ///
  /// In fa, this message translates to:
  /// **'صدور کد بازیابی رمز'**
  String get adminIssueResetToken;

  /// No description provided for @deptNew.
  ///
  /// In fa, this message translates to:
  /// **'دپارتمان جدید'**
  String get deptNew;

  /// No description provided for @deptRename.
  ///
  /// In fa, this message translates to:
  /// **'تغییر نام دپارتمان'**
  String get deptRename;

  /// No description provided for @deptName.
  ///
  /// In fa, this message translates to:
  /// **'نام'**
  String get deptName;

  /// No description provided for @deptSection.
  ///
  /// In fa, this message translates to:
  /// **'دپارتمان‌ها'**
  String get deptSection;

  /// No description provided for @deptSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'فقط مدیر می‌تواند این‌ها را تغییر دهد'**
  String get deptSubtitle;

  /// No description provided for @deptNewShort.
  ///
  /// In fa, this message translates to:
  /// **'جدید'**
  String get deptNewShort;

  /// No description provided for @deptEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز دپارتمانی وجود ندارد'**
  String get deptEmpty;

  /// No description provided for @deptMembers.
  ///
  /// In fa, this message translates to:
  /// **'{count} نفر'**
  String deptMembers(String count);

  /// No description provided for @deptInactiveSuffix.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال'**
  String get deptInactiveSuffix;

  /// No description provided for @deptRenameTooltip.
  ///
  /// In fa, this message translates to:
  /// **'تغییر نام'**
  String get deptRenameTooltip;

  /// No description provided for @letterheadSaved.
  ///
  /// In fa, this message translates to:
  /// **'سربرگ ذخیره شد'**
  String get letterheadSaved;

  /// No description provided for @letterheadLogoInvalid.
  ///
  /// In fa, this message translates to:
  /// **'لوگو باید PNG یا JPEG و کمتر از ۲۰۰ کیلوبایت باشد'**
  String get letterheadLogoInvalid;

  /// No description provided for @letterheadCompanyName.
  ///
  /// In fa, this message translates to:
  /// **'نام شرکت'**
  String get letterheadCompanyName;

  /// No description provided for @letterheadTagline.
  ///
  /// In fa, this message translates to:
  /// **'زیرعنوان'**
  String get letterheadTagline;

  /// No description provided for @letterheadAddress.
  ///
  /// In fa, this message translates to:
  /// **'نشانی'**
  String get letterheadAddress;

  /// No description provided for @letterheadPhone.
  ///
  /// In fa, this message translates to:
  /// **'تلفن'**
  String get letterheadPhone;

  /// No description provided for @letterheadEmail.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل'**
  String get letterheadEmail;

  /// No description provided for @letterheadWebsite.
  ///
  /// In fa, this message translates to:
  /// **'وب‌سایت'**
  String get letterheadWebsite;

  /// No description provided for @letterheadFooter.
  ///
  /// In fa, this message translates to:
  /// **'نشانی / تلفن (پایین هر صفحه)'**
  String get letterheadFooter;

  /// No description provided for @letterheadTitle.
  ///
  /// In fa, this message translates to:
  /// **'سربرگ'**
  String get letterheadTitle;

  /// No description provided for @letterheadHint.
  ///
  /// In fa, this message translates to:
  /// **'در بالا و پایین هر نامه چاپ می‌شود.'**
  String get letterheadHint;

  /// No description provided for @letterheadAddLogo.
  ///
  /// In fa, this message translates to:
  /// **'افزودن لوگو'**
  String get letterheadAddLogo;

  /// No description provided for @letterheadChangeLogo.
  ///
  /// In fa, this message translates to:
  /// **'تغییر لوگو'**
  String get letterheadChangeLogo;

  /// No description provided for @letterheadRemoveLogo.
  ///
  /// In fa, this message translates to:
  /// **'حذف لوگو'**
  String get letterheadRemoveLogo;

  /// No description provided for @letterheadSave.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره سربرگ'**
  String get letterheadSave;

  /// No description provided for @lettersCreateSigners.
  ///
  /// In fa, this message translates to:
  /// **'امضاکنندگان'**
  String get lettersCreateSigners;

  /// No description provided for @lettersCreateViewers.
  ///
  /// In fa, this message translates to:
  /// **'بینندگان'**
  String get lettersCreateViewers;

  /// No description provided for @lettersCreateNoSignerCandidates.
  ///
  /// In fa, this message translates to:
  /// **'فعلاً کسی برای انتخاب نیست. امضاکننده باید کاربر دیگری با دسترسی امضای نامه (تعیین‌شده توسط مدیر) باشد.'**
  String get lettersCreateNoSignerCandidates;

  /// No description provided for @lettersCreateNoViewerCandidates.
  ///
  /// In fa, this message translates to:
  /// **'فعلاً کسی برای انتخاب نیست. بینندگان باید از همکاران دیگر باشند.'**
  String get lettersCreateNoViewerCandidates;

  /// No description provided for @lettersCreateTitleRequired.
  ///
  /// In fa, this message translates to:
  /// **'عنوان الزامی است'**
  String get lettersCreateTitleRequired;

  /// No description provided for @lettersCreateSignerRequired.
  ///
  /// In fa, this message translates to:
  /// **'دست‌کم یک امضاکننده اضافه کنید'**
  String get lettersCreateSignerRequired;

  /// No description provided for @lettersCreateDraftSaved.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نویس ذخیره شد'**
  String get lettersCreateDraftSaved;

  /// No description provided for @lettersCreateContent.
  ///
  /// In fa, this message translates to:
  /// **'محتوا'**
  String get lettersCreateContent;

  /// No description provided for @lettersCreateContentHint.
  ///
  /// In fa, this message translates to:
  /// **'عنوان در فهرست‌ها دیده می‌شود. متن نامه به‌صورت رمزنگاری‌شده روی سرور ذخیره می‌شود.'**
  String get lettersCreateContentHint;

  /// No description provided for @lettersCreateTitleLabel.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get lettersCreateTitleLabel;

  /// No description provided for @lettersCreateOnPaper.
  ///
  /// In fa, this message translates to:
  /// **'نوشتن روی کاغذ A4 (پیش‌نمایش و چاپ)'**
  String get lettersCreateOnPaper;

  /// No description provided for @lettersCreateAutosaved.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نویس به‌طور خودکار ذخیره شد: {time}'**
  String lettersCreateAutosaved(String time);

  /// No description provided for @lettersCreateBodyFormatted.
  ///
  /// In fa, this message translates to:
  /// **'متن (قالب‌بندی‌شده)'**
  String get lettersCreateBodyFormatted;

  /// No description provided for @lettersCreateBody.
  ///
  /// In fa, this message translates to:
  /// **'متن'**
  String get lettersCreateBody;

  /// No description provided for @lettersCreateAttachments.
  ///
  /// In fa, this message translates to:
  /// **'پیوست‌ها'**
  String get lettersCreateAttachments;

  /// No description provided for @lettersCreateAttachmentsHint.
  ///
  /// In fa, this message translates to:
  /// **'PDF یا تصویر، حداکثر ۲۵ مگابایت برای هر فایل. فایل‌ها رمزنگاری‌شده روی سرور ذخیره می‌شوند.'**
  String get lettersCreateAttachmentsHint;

  /// No description provided for @lettersCreateRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get lettersCreateRemove;

  /// No description provided for @lettersCreateAttach.
  ///
  /// In fa, this message translates to:
  /// **'افزودن PDF / تصویر (حداکثر ۲۵ مگابایت)'**
  String get lettersCreateAttach;

  /// No description provided for @lettersCreateNoSigners.
  ///
  /// In fa, this message translates to:
  /// **'هنوز امضاکننده‌ای انتخاب نشده'**
  String get lettersCreateNoSigners;

  /// No description provided for @lettersCreateSignerN.
  ///
  /// In fa, this message translates to:
  /// **'امضاکننده {n}'**
  String lettersCreateSignerN(String n);

  /// No description provided for @lettersCreatePeople.
  ///
  /// In fa, this message translates to:
  /// **'افراد'**
  String get lettersCreatePeople;

  /// No description provided for @lettersCreatePeopleHint.
  ///
  /// In fa, this message translates to:
  /// **'چه کسانی نامه را امضا می‌کنند و چه کسانی می‌توانند آن را بخوانند.'**
  String get lettersCreatePeopleHint;

  /// No description provided for @lettersCreateChooseSigners.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب امضاکنندگان'**
  String get lettersCreateChooseSigners;

  /// No description provided for @lettersCreateParallel.
  ///
  /// In fa, this message translates to:
  /// **'هم‌زمان'**
  String get lettersCreateParallel;

  /// No description provided for @lettersCreateSerial.
  ///
  /// In fa, this message translates to:
  /// **'به‌ترتیب'**
  String get lettersCreateSerial;

  /// No description provided for @lettersCreateSerialHelp.
  ///
  /// In fa, this message translates to:
  /// **'امضاکنندگان یکی‌یکی و از بالا به پایین امضا می‌کنند. برای تغییر ترتیب، بکشید.'**
  String get lettersCreateSerialHelp;

  /// No description provided for @lettersCreateParallelHelp.
  ///
  /// In fa, this message translates to:
  /// **'همه امضاکنندگان می‌توانند هم‌زمان امضا کنند.'**
  String get lettersCreateParallelHelp;

  /// No description provided for @lettersCreateVisibility.
  ///
  /// In fa, this message translates to:
  /// **'سطح دسترسی'**
  String get lettersCreateVisibility;

  /// No description provided for @lettersCreatePrivate.
  ///
  /// In fa, this message translates to:
  /// **'خصوصی'**
  String get lettersCreatePrivate;

  /// No description provided for @lettersCreatePublic.
  ///
  /// In fa, this message translates to:
  /// **'عمومی'**
  String get lettersCreatePublic;

  /// No description provided for @lettersCreatePublicHelp.
  ///
  /// In fa, this message translates to:
  /// **'پس از انتشار، همه افراد شرکت می‌توانند آن را بخوانند.'**
  String get lettersCreatePublicHelp;

  /// No description provided for @lettersCreatePrivateHelp.
  ///
  /// In fa, this message translates to:
  /// **'فقط ایجادکننده، امضاکنندگان و بینندگان انتخاب‌شده می‌توانند آن را بخوانند.'**
  String get lettersCreatePrivateHelp;

  /// No description provided for @lettersCreateNoViewers.
  ///
  /// In fa, this message translates to:
  /// **'بیننده اضافه‌ای نیست'**
  String get lettersCreateNoViewers;

  /// No description provided for @lettersCreateChooseViewers.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب بینندگان'**
  String get lettersCreateChooseViewers;

  /// No description provided for @lettersCreateDelivery.
  ///
  /// In fa, this message translates to:
  /// **'زمان نمایش'**
  String get lettersCreateDelivery;

  /// No description provided for @lettersCreateDeliveryHint.
  ///
  /// In fa, this message translates to:
  /// **'چه زمانی نامه برای مخاطبان قابل مشاهده می‌شود.'**
  String get lettersCreateDeliveryHint;

  /// No description provided for @lettersCreateAfterSign.
  ///
  /// In fa, this message translates to:
  /// **'پس از امضای همه'**
  String get lettersCreateAfterSign;

  /// No description provided for @lettersCreateRightAway.
  ///
  /// In fa, this message translates to:
  /// **'بلافاصله'**
  String get lettersCreateRightAway;

  /// No description provided for @lettersCreateNowHelp.
  ///
  /// In fa, this message translates to:
  /// **'بینندگان به‌محض ارسال، نامه را می‌بینند.'**
  String get lettersCreateNowHelp;

  /// No description provided for @lettersCreateAfterSignHelp.
  ///
  /// In fa, this message translates to:
  /// **'بینندگان فقط پس از تأیید همه امضاکنندگان نامه را می‌بینند.'**
  String get lettersCreateAfterSignHelp;

  /// No description provided for @lettersCreateSaveDraft.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره پیش‌نویس'**
  String get lettersCreateSaveDraft;

  /// No description provided for @lettersCreateWorking.
  ///
  /// In fa, this message translates to:
  /// **'در حال انجام...'**
  String get lettersCreateWorking;

  /// No description provided for @lettersCreateSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال'**
  String get lettersCreateSend;

  /// No description provided for @lettersCreateNew.
  ///
  /// In fa, this message translates to:
  /// **'نامه جدید'**
  String get lettersCreateNew;

  /// No description provided for @lettersCreateNewChained.
  ///
  /// In fa, this message translates to:
  /// **'نامه زنجیره‌ای جدید'**
  String get lettersCreateNewChained;

  /// No description provided for @lettersAdminLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری نامه‌ها ممکن نشد'**
  String get lettersAdminLoadFailed;

  /// No description provided for @lettersAdminEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'هنوز نامه‌ای نیست'**
  String get lettersAdminEmptyTitle;

  /// No description provided for @lettersAdminEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'عنوان و شرکت‌کنندگان همه نامه‌ها اینجا نمایش داده می‌شود.'**
  String get lettersAdminEmptyMessage;

  /// No description provided for @lettersAdminTitle.
  ///
  /// In fa, this message translates to:
  /// **'همه نامه‌ها (مدیر)'**
  String get lettersAdminTitle;

  /// No description provided for @lettersAdminBy.
  ///
  /// In fa, this message translates to:
  /// **'ایجادکننده: {email}  -  {date}'**
  String lettersAdminBy(String date, String email);

  /// No description provided for @lettersAdminRoleSigner.
  ///
  /// In fa, this message translates to:
  /// **'امضاکننده'**
  String get lettersAdminRoleSigner;

  /// No description provided for @lettersAdminRoleViewer.
  ///
  /// In fa, this message translates to:
  /// **'بیننده'**
  String get lettersAdminRoleViewer;

  /// No description provided for @lettersAdminRelist.
  ///
  /// In fa, this message translates to:
  /// **'نمایش مجدد در فهرست'**
  String get lettersAdminRelist;

  /// No description provided for @lettersAdminUnlist.
  ///
  /// In fa, this message translates to:
  /// **'حذف از فهرست'**
  String get lettersAdminUnlist;

  /// No description provided for @notifTooltip.
  ///
  /// In fa, this message translates to:
  /// **'اعلان‌ها'**
  String get notifTooltip;

  /// No description provided for @notifTitle.
  ///
  /// In fa, this message translates to:
  /// **'اعلان‌ها'**
  String get notifTitle;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In fa, this message translates to:
  /// **'خواندن همه'**
  String get notifMarkAllRead;

  /// No description provided for @notifLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری اعلان‌ها ممکن نشد'**
  String get notifLoadFailed;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'فعلاً چیزی نیست'**
  String get notifEmptyTitle;

  /// No description provided for @notifEmptyMessage.
  ///
  /// In fa, this message translates to:
  /// **'وقتی نامه‌ای نیازمند اقدام شما باشد، اطلاع داده می‌شود.'**
  String get notifEmptyMessage;

  /// No description provided for @approvalTitle.
  ///
  /// In fa, this message translates to:
  /// **'تأیید امضا؟'**
  String get approvalTitle;

  /// No description provided for @approvalDecisionApprove.
  ///
  /// In fa, this message translates to:
  /// **'تصمیم: تأیید'**
  String get approvalDecisionApprove;

  /// No description provided for @approvalDecisionReject.
  ///
  /// In fa, this message translates to:
  /// **'تصمیم: رد'**
  String get approvalDecisionReject;

  /// No description provided for @approvalNote.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت: «{note}»'**
  String approvalNote(String note);

  /// No description provided for @approvalRequestedFrom.
  ///
  /// In fa, this message translates to:
  /// **'درخواست از {device}. فقط اگر این درخواست از طرف شما بوده است تأیید کنید.'**
  String approvalRequestedFrom(String device);

  /// No description provided for @approvalAnotherDevice.
  ///
  /// In fa, this message translates to:
  /// **'دستگاه دیگر'**
  String get approvalAnotherDevice;

  /// No description provided for @approvalDecline.
  ///
  /// In fa, this message translates to:
  /// **'رد درخواست'**
  String get approvalDecline;

  /// No description provided for @approvalApprove.
  ///
  /// In fa, this message translates to:
  /// **'تأیید'**
  String get approvalApprove;

  /// No description provided for @approvalBioReasonApprove.
  ///
  /// In fa, this message translates to:
  /// **'تأیید امضا: {title}'**
  String approvalBioReasonApprove(String title);

  /// No description provided for @approvalBioReasonReject.
  ///
  /// In fa, this message translates to:
  /// **'رد امضا: {title}'**
  String approvalBioReasonReject(String title);

  /// No description provided for @approvalBioFailed.
  ///
  /// In fa, this message translates to:
  /// **'بررسی اثر انگشت / چهره ناموفق بود'**
  String get approvalBioFailed;

  /// No description provided for @paperInk.
  ///
  /// In fa, this message translates to:
  /// **'مشکی'**
  String get paperInk;

  /// No description provided for @paperBlue.
  ///
  /// In fa, this message translates to:
  /// **'آبی'**
  String get paperBlue;

  /// No description provided for @paperRed.
  ///
  /// In fa, this message translates to:
  /// **'قرمز'**
  String get paperRed;

  /// No description provided for @paperGreen.
  ///
  /// In fa, this message translates to:
  /// **'سبز'**
  String get paperGreen;

  /// No description provided for @paperNewNumber.
  ///
  /// In fa, this message translates to:
  /// **'(جدید)'**
  String get paperNewNumber;

  /// No description provided for @paperHint.
  ///
  /// In fa, this message translates to:
  /// **'متن نامه را اینجا بنویسید...'**
  String get paperHint;

  /// No description provided for @paperStatus.
  ///
  /// In fa, this message translates to:
  /// **'{words} کلمه  |  {chars} نویسه  |  {pages} صفحه A4 با اندازه {pt} پونت'**
  String paperStatus(String chars, String pages, String pt, String words);

  /// No description provided for @paperUndo.
  ///
  /// In fa, this message translates to:
  /// **'واگرد'**
  String get paperUndo;

  /// No description provided for @paperRedo.
  ///
  /// In fa, this message translates to:
  /// **'بازگرد'**
  String get paperRedo;

  /// No description provided for @paperBold.
  ///
  /// In fa, this message translates to:
  /// **'پررنگ'**
  String get paperBold;

  /// No description provided for @paperItalic.
  ///
  /// In fa, this message translates to:
  /// **'کج'**
  String get paperItalic;

  /// No description provided for @paperUnderline.
  ///
  /// In fa, this message translates to:
  /// **'زیرخط'**
  String get paperUnderline;

  /// No description provided for @paperHeading.
  ///
  /// In fa, this message translates to:
  /// **'عنوان'**
  String get paperHeading;

  /// No description provided for @paperSubheading.
  ///
  /// In fa, this message translates to:
  /// **'زیرعنوان'**
  String get paperSubheading;

  /// No description provided for @paperBullets.
  ///
  /// In fa, this message translates to:
  /// **'فهرست نقطه‌ای'**
  String get paperBullets;

  /// No description provided for @paperNumbered.
  ///
  /// In fa, this message translates to:
  /// **'فهرست شماره‌دار'**
  String get paperNumbered;

  /// No description provided for @paperSmaller.
  ///
  /// In fa, this message translates to:
  /// **'متن کوچک‌تر'**
  String get paperSmaller;

  /// No description provided for @paperLarger.
  ///
  /// In fa, this message translates to:
  /// **'متن بزرگ‌تر'**
  String get paperLarger;

  /// No description provided for @paperTextColor.
  ///
  /// In fa, this message translates to:
  /// **'رنگ متن'**
  String get paperTextColor;

  /// No description provided for @paperAlignStart.
  ///
  /// In fa, this message translates to:
  /// **'چین از ابتدا'**
  String get paperAlignStart;

  /// No description provided for @paperAlignCenter.
  ///
  /// In fa, this message translates to:
  /// **'وسط‌چین'**
  String get paperAlignCenter;

  /// No description provided for @paperAlignEnd.
  ///
  /// In fa, this message translates to:
  /// **'چین از انتها'**
  String get paperAlignEnd;

  /// No description provided for @paperJustify.
  ///
  /// In fa, this message translates to:
  /// **'تراز دوطرفه'**
  String get paperJustify;

  /// No description provided for @paperDirAllTooltip.
  ///
  /// In fa, this message translates to:
  /// **'جهت کل نامه'**
  String get paperDirAllTooltip;

  /// No description provided for @paperDirAllRtl.
  ///
  /// In fa, this message translates to:
  /// **'کل نامه راست‌به‌چپ'**
  String get paperDirAllRtl;

  /// No description provided for @paperDirAllLtr.
  ///
  /// In fa, this message translates to:
  /// **'کل نامه چپ‌به‌راست'**
  String get paperDirAllLtr;

  /// No description provided for @paperDirAllAuto.
  ///
  /// In fa, this message translates to:
  /// **'کل نامه خودکار'**
  String get paperDirAllAuto;

  /// No description provided for @paperDirParaLtr.
  ///
  /// In fa, this message translates to:
  /// **'بند چپ‌به‌راست'**
  String get paperDirParaLtr;

  /// No description provided for @paperDirParaRtl.
  ///
  /// In fa, this message translates to:
  /// **'بند راست‌به‌چپ'**
  String get paperDirParaRtl;

  /// No description provided for @paperTitle.
  ///
  /// In fa, this message translates to:
  /// **'نوشتن روی کاغذ'**
  String get paperTitle;

  /// No description provided for @paperDone.
  ///
  /// In fa, this message translates to:
  /// **'انجام شد'**
  String get paperDone;

  /// No description provided for @paperTabEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش'**
  String get paperTabEdit;

  /// No description provided for @paperTabPreview.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نمایش'**
  String get paperTabPreview;

  /// No description provided for @notifGroupEarlier.
  ///
  /// In fa, this message translates to:
  /// **'قدیمی‌تر'**
  String get notifGroupEarlier;

  /// No description provided for @notifGroupToday.
  ///
  /// In fa, this message translates to:
  /// **'امروز'**
  String get notifGroupToday;

  /// No description provided for @notifGroupYesterday.
  ///
  /// In fa, this message translates to:
  /// **'دیروز'**
  String get notifGroupYesterday;

  /// No description provided for @lettersAdminUnlisted.
  ///
  /// In fa, this message translates to:
  /// **'خارج از فهرست'**
  String get lettersAdminUnlisted;

  /// No description provided for @sessionsUnknownDevice.
  ///
  /// In fa, this message translates to:
  /// **'دستگاه ناشناس'**
  String get sessionsUnknownDevice;

  /// No description provided for @projectTabGantt.
  ///
  /// In fa, this message translates to:
  /// **'گانت'**
  String get projectTabGantt;

  /// No description provided for @secTitle.
  ///
  /// In fa, this message translates to:
  /// **'امنیت'**
  String get secTitle;

  /// No description provided for @secTwoFactor.
  ///
  /// In fa, this message translates to:
  /// **'ورود دومرحله‌ای'**
  String get secTwoFactor;

  /// No description provided for @secTwoFactorHelp.
  ///
  /// In fa, this message translates to:
  /// **'با یک برنامه احراز هویت (مثل Google Authenticator) هر ورود با یک کد ۶ رقمی تأیید می‌شود.'**
  String get secTwoFactorHelp;

  /// No description provided for @secOn.
  ///
  /// In fa, this message translates to:
  /// **'فعال'**
  String get secOn;

  /// No description provided for @secOff.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال'**
  String get secOff;

  /// No description provided for @secRequiredByCompany.
  ///
  /// In fa, this message translates to:
  /// **'شرکت فعال‌سازی ورود دومرحله‌ای را الزامی کرده است.'**
  String get secRequiredByCompany;

  /// No description provided for @secEnable.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی'**
  String get secEnable;

  /// No description provided for @secDisable.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال‌سازی'**
  String get secDisable;

  /// No description provided for @secDisabled.
  ///
  /// In fa, this message translates to:
  /// **'ورود دومرحله‌ای غیرفعال شد'**
  String get secDisabled;

  /// No description provided for @secNewCodes.
  ///
  /// In fa, this message translates to:
  /// **'کدهای بازیابی جدید'**
  String get secNewCodes;

  /// No description provided for @secCodesLeft.
  ///
  /// In fa, this message translates to:
  /// **'کدهای بازیابی باقی‌مانده: {count}'**
  String secCodesLeft(String count);

  /// No description provided for @secSetupSteps.
  ///
  /// In fa, this message translates to:
  /// **'کلید زیر را در برنامه احراز هویت وارد کنید (یا پیوند را باز کنید)، سپس کد ۶ رقمی نمایش‌داده‌شده را بنویسید.'**
  String get secSetupSteps;

  /// No description provided for @secSecretKey.
  ///
  /// In fa, this message translates to:
  /// **'کلید مخفی'**
  String get secSecretKey;

  /// No description provided for @secSetupLink.
  ///
  /// In fa, this message translates to:
  /// **'پیوند otpauth'**
  String get secSetupLink;

  /// No description provided for @secAuthCode.
  ///
  /// In fa, this message translates to:
  /// **'کد ۶ رقمی برنامه'**
  String get secAuthCode;

  /// No description provided for @secConfirmEnable.
  ///
  /// In fa, this message translates to:
  /// **'تأیید و فعال‌سازی'**
  String get secConfirmEnable;

  /// No description provided for @secCodeInvalid.
  ///
  /// In fa, this message translates to:
  /// **'کد باید ۶ رقم باشد'**
  String get secCodeInvalid;

  /// No description provided for @secCodeRecoveryInvalid.
  ///
  /// In fa, this message translates to:
  /// **'کد بازیابی را وارد کنید'**
  String get secCodeRecoveryInvalid;

  /// No description provided for @secCopy.
  ///
  /// In fa, this message translates to:
  /// **'کپی'**
  String get secCopy;

  /// No description provided for @secCopied.
  ///
  /// In fa, this message translates to:
  /// **'کپی شد'**
  String get secCopied;

  /// No description provided for @secProofMissing.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور و کد را وارد کنید'**
  String get secProofMissing;

  /// No description provided for @secPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور'**
  String get secPassword;

  /// No description provided for @secRecoveryCode.
  ///
  /// In fa, this message translates to:
  /// **'کد بازیابی'**
  String get secRecoveryCode;

  /// No description provided for @secUseRecoveryCode.
  ///
  /// In fa, this message translates to:
  /// **'استفاده از کد بازیابی'**
  String get secUseRecoveryCode;

  /// No description provided for @secUseAppCode.
  ///
  /// In fa, this message translates to:
  /// **'استفاده از کد برنامه'**
  String get secUseAppCode;

  /// No description provided for @secRecoveryTitle.
  ///
  /// In fa, this message translates to:
  /// **'کدهای بازیابی'**
  String get secRecoveryTitle;

  /// No description provided for @secRecoveryWarning.
  ///
  /// In fa, this message translates to:
  /// **'این ۱۰ کد فقط همین یک بار نمایش داده می‌شوند. هر کد یک بار مصرف است؛ آن‌ها را جای امن نگه دارید.'**
  String get secRecoveryWarning;

  /// No description provided for @secSavedThem.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره کردم'**
  String get secSavedThem;

  /// No description provided for @secLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری ممکن نشد'**
  String get secLoadFailed;

  /// No description provided for @secNoConnection.
  ///
  /// In fa, this message translates to:
  /// **'اتصال به سرور برقرار نشد'**
  String get secNoConnection;

  /// No description provided for @secLoginCodeTitle.
  ///
  /// In fa, this message translates to:
  /// **'تأیید ورود'**
  String get secLoginCodeTitle;

  /// No description provided for @secLoginCodeSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'کد ۶ رقمی برنامه احراز هویت را وارد کنید'**
  String get secLoginCodeSubtitle;

  /// No description provided for @secLoginRecoverySubtitle.
  ///
  /// In fa, this message translates to:
  /// **'یکی از کدهای بازیابی خود را وارد کنید'**
  String get secLoginRecoverySubtitle;

  /// No description provided for @secContinue.
  ///
  /// In fa, this message translates to:
  /// **'ادامه'**
  String get secContinue;

  /// No description provided for @secLoginHistory.
  ///
  /// In fa, this message translates to:
  /// **'تاریخچه ورود'**
  String get secLoginHistory;

  /// No description provided for @secHistoryEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز ورودی ثبت نشده است'**
  String get secHistoryEmpty;

  /// No description provided for @secLoginOk.
  ///
  /// In fa, this message translates to:
  /// **'ورود موفق'**
  String get secLoginOk;

  /// No description provided for @secLoginFailed.
  ///
  /// In fa, this message translates to:
  /// **'ورود ناموفق'**
  String get secLoginFailed;

  /// No description provided for @secReasonBadPassword.
  ///
  /// In fa, this message translates to:
  /// **'رمز عبور اشتباه'**
  String get secReasonBadPassword;

  /// No description provided for @secReasonBadCode.
  ///
  /// In fa, this message translates to:
  /// **'کد اشتباه'**
  String get secReasonBadCode;

  /// No description provided for @secReasonLocked.
  ///
  /// In fa, this message translates to:
  /// **'حساب موقتاً قفل بود'**
  String get secReasonLocked;

  /// No description provided for @secReasonGuestExpired.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی مهمان منقضی شده'**
  String get secReasonGuestExpired;

  /// No description provided for @secCloseOthers.
  ///
  /// In fa, this message translates to:
  /// **'بستن سایر نشست‌ها'**
  String get secCloseOthers;

  /// No description provided for @secCloseOthersTitle.
  ///
  /// In fa, this message translates to:
  /// **'بستن سایر نشست‌ها؟'**
  String get secCloseOthersTitle;

  /// No description provided for @secCloseOthersBody.
  ///
  /// In fa, this message translates to:
  /// **'همه دستگاه‌ها به‌جز این دستگاه از حساب خارج می‌شوند.'**
  String get secCloseOthersBody;

  /// No description provided for @secGuest.
  ///
  /// In fa, this message translates to:
  /// **'مهمان'**
  String get secGuest;

  /// No description provided for @secGuests.
  ///
  /// In fa, this message translates to:
  /// **'کاربران مهمان'**
  String get secGuests;

  /// No description provided for @secGuestsHelp.
  ///
  /// In fa, this message translates to:
  /// **'همکاران بیرونی؛ فقط وظایف، پروژه‌ها و گفتگوی مشترک را می‌بینند'**
  String get secGuestsHelp;

  /// No description provided for @secGuestsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'مهمانی وجود ندارد'**
  String get secGuestsEmpty;

  /// No description provided for @secGuestNew.
  ///
  /// In fa, this message translates to:
  /// **'مهمان جدید'**
  String get secGuestNew;

  /// No description provided for @secGuestInvite.
  ///
  /// In fa, this message translates to:
  /// **'کد دعوت مهمان'**
  String get secGuestInvite;

  /// No description provided for @secGuestInviteHelp.
  ///
  /// In fa, this message translates to:
  /// **'هر کسی با این کد ثبت‌نام کند، مهمان می‌شود.'**
  String get secGuestInviteHelp;

  /// No description provided for @secGuestInviteCode.
  ///
  /// In fa, this message translates to:
  /// **'کد دعوت مهمان'**
  String get secGuestInviteCode;

  /// No description provided for @secGuestInvalid.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل معتبر و رمز حداقل ۸ نویسه لازم است'**
  String get secGuestInvalid;

  /// No description provided for @secCreate.
  ///
  /// In fa, this message translates to:
  /// **'ایجاد'**
  String get secCreate;

  /// No description provided for @secEmail.
  ///
  /// In fa, this message translates to:
  /// **'ایمیل'**
  String get secEmail;

  /// No description provided for @secFullName.
  ///
  /// In fa, this message translates to:
  /// **'نام کامل'**
  String get secFullName;

  /// No description provided for @secNoExpiry.
  ///
  /// In fa, this message translates to:
  /// **'بدون انقضا'**
  String get secNoExpiry;

  /// No description provided for @secExpiresOn.
  ///
  /// In fa, this message translates to:
  /// **'انقضا: {date}'**
  String secExpiresOn(String date);

  /// No description provided for @secSetExpiry.
  ///
  /// In fa, this message translates to:
  /// **'تعیین انقضا'**
  String get secSetExpiry;

  /// No description provided for @secClearExpiry.
  ///
  /// In fa, this message translates to:
  /// **'حذف انقضا'**
  String get secClearExpiry;

  /// No description provided for @secActive.
  ///
  /// In fa, this message translates to:
  /// **'فعال'**
  String get secActive;

  /// No description provided for @secExpired.
  ///
  /// In fa, this message translates to:
  /// **'منقضی'**
  String get secExpired;

  /// No description provided for @secDeactivated.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال شده'**
  String get secDeactivated;

  /// No description provided for @secDeactivate.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال کردن'**
  String get secDeactivate;

  /// No description provided for @secReactivate.
  ///
  /// In fa, this message translates to:
  /// **'فعال کردن مجدد'**
  String get secReactivate;

  /// No description provided for @secGuestNotice.
  ///
  /// In fa, this message translates to:
  /// **'شما با حساب مهمان وارد شده‌اید و فقط به بخش‌های مجاز دسترسی دارید.'**
  String get secGuestNotice;

  /// No description provided for @secGuestNoticeUntil.
  ///
  /// In fa, this message translates to:
  /// **'شما مهمان هستید؛ دسترسی شما تا {date} معتبر است.'**
  String secGuestNoticeUntil(String date);

  /// No description provided for @secSetupRequiredNotice.
  ///
  /// In fa, this message translates to:
  /// **'شرکت ورود دومرحله‌ای را الزامی کرده است؛ آن را از پروفایل > امنیت فعال کنید.'**
  String get secSetupRequiredNotice;

  /// No description provided for @secAccess.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی‌ها'**
  String get secAccess;

  /// No description provided for @secAccessTitle.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی‌های {name}'**
  String secAccessTitle(String name);

  /// No description provided for @secAccessProjects.
  ///
  /// In fa, this message translates to:
  /// **'پروژه‌ها'**
  String get secAccessProjects;

  /// No description provided for @secAccessCustomers.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌های مشتری'**
  String get secAccessCustomers;

  /// No description provided for @secAccessChats.
  ///
  /// In fa, this message translates to:
  /// **'گروه‌های گفتگو'**
  String get secAccessChats;

  /// No description provided for @secAccessAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن'**
  String get secAccessAdd;

  /// No description provided for @secAccessEmpty.
  ///
  /// In fa, this message translates to:
  /// **'موردی نیست'**
  String get secAccessEmpty;

  /// No description provided for @secAccessNothingToAdd.
  ///
  /// In fa, this message translates to:
  /// **'موردی برای افزودن نیست'**
  String get secAccessNothingToAdd;

  /// No description provided for @secRoleManager.
  ///
  /// In fa, this message translates to:
  /// **'مدیر'**
  String get secRoleManager;

  /// No description provided for @secRoleMember.
  ///
  /// In fa, this message translates to:
  /// **'عضو'**
  String get secRoleMember;

  /// No description provided for @secRoleViewer.
  ///
  /// In fa, this message translates to:
  /// **'بیننده'**
  String get secRoleViewer;

  /// No description provided for @secRoleAdmin.
  ///
  /// In fa, this message translates to:
  /// **'ادمین'**
  String get secRoleAdmin;

  /// No description provided for @gnReadOnly.
  ///
  /// In fa, this message translates to:
  /// **'فقط مشاهده: شما اجازه ویرایش این نمودار را ندارید.'**
  String get gnReadOnly;

  /// No description provided for @gnLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری نمودار گانت ممکن نشد'**
  String get gnLoadFailed;

  /// No description provided for @gnEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز چیزی در برنامه نیست'**
  String get gnEmpty;

  /// No description provided for @gnEmptyEdit.
  ///
  /// In fa, this message translates to:
  /// **'یک فاز بسازید یا وظایف برنامه‌ریزی‌نشده را به برنامه اضافه کنید.'**
  String get gnEmptyEdit;

  /// No description provided for @gnZoomDaily.
  ///
  /// In fa, this message translates to:
  /// **'روزانه'**
  String get gnZoomDaily;

  /// No description provided for @gnZoomMonthly.
  ///
  /// In fa, this message translates to:
  /// **'ماهانه'**
  String get gnZoomMonthly;

  /// No description provided for @gnZoomQuarterly.
  ///
  /// In fa, this message translates to:
  /// **'فصلی'**
  String get gnZoomQuarterly;

  /// No description provided for @gnAddPhase.
  ///
  /// In fa, this message translates to:
  /// **'فاز جدید'**
  String get gnAddPhase;

  /// No description provided for @gnUnplanned.
  ///
  /// In fa, this message translates to:
  /// **'برنامه‌ریزی‌نشده ({count})'**
  String gnUnplanned(String count);

  /// No description provided for @gnNoUnplanned.
  ///
  /// In fa, this message translates to:
  /// **'همه وظایف در برنامه هستند'**
  String get gnNoUnplanned;

  /// No description provided for @gnAddToPlan.
  ///
  /// In fa, this message translates to:
  /// **'افزودن به برنامه'**
  String get gnAddToPlan;

  /// No description provided for @gnPrint.
  ///
  /// In fa, this message translates to:
  /// **'چاپ نمودار'**
  String get gnPrint;

  /// No description provided for @gnPrintTitle.
  ///
  /// In fa, this message translates to:
  /// **'نمودار گانت: {name}'**
  String gnPrintTitle(String name);

  /// No description provided for @gnProgress.
  ///
  /// In fa, this message translates to:
  /// **'پیشرفت {percent}٪'**
  String gnProgress(String percent);

  /// No description provided for @gnActions.
  ///
  /// In fa, this message translates to:
  /// **'عملیات'**
  String get gnActions;

  /// No description provided for @gnRename.
  ///
  /// In fa, this message translates to:
  /// **'تغییر نام'**
  String get gnRename;

  /// No description provided for @gnSetDates.
  ///
  /// In fa, this message translates to:
  /// **'تعیین تاریخ'**
  String get gnSetDates;

  /// No description provided for @gnStart.
  ///
  /// In fa, this message translates to:
  /// **'شروع'**
  String get gnStart;

  /// No description provided for @gnEnd.
  ///
  /// In fa, this message translates to:
  /// **'پایان'**
  String get gnEnd;

  /// No description provided for @gnDatesOrder.
  ///
  /// In fa, this message translates to:
  /// **'پایان نباید قبل از شروع باشد'**
  String get gnDatesOrder;

  /// No description provided for @gnPhase.
  ///
  /// In fa, this message translates to:
  /// **'فاز'**
  String get gnPhase;

  /// No description provided for @gnPhaseTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان فاز'**
  String get gnPhaseTitle;

  /// No description provided for @gnNoPhase.
  ///
  /// In fa, this message translates to:
  /// **'بدون فاز'**
  String get gnNoPhase;

  /// No description provided for @gnMoveToPhase.
  ///
  /// In fa, this message translates to:
  /// **'انتقال به فاز'**
  String get gnMoveToPhase;

  /// No description provided for @gnMoveUp.
  ///
  /// In fa, this message translates to:
  /// **'بالا بردن'**
  String get gnMoveUp;

  /// No description provided for @gnMoveDown.
  ///
  /// In fa, this message translates to:
  /// **'پایین بردن'**
  String get gnMoveDown;

  /// No description provided for @gnIndent.
  ///
  /// In fa, this message translates to:
  /// **'زیرمجموعه (تورفتگی)'**
  String get gnIndent;

  /// No description provided for @gnOutdent.
  ///
  /// In fa, this message translates to:
  /// **'خروج از زیرمجموعه'**
  String get gnOutdent;

  /// No description provided for @gnOpenTask.
  ///
  /// In fa, this message translates to:
  /// **'باز کردن وظیفه'**
  String get gnOpenTask;

  /// No description provided for @gnDeactivatePhase.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال کردن فاز'**
  String get gnDeactivatePhase;

  /// No description provided for @gnDeactivatePhaseBody.
  ///
  /// In fa, this message translates to:
  /// **'فاز «{title}» غیرفعال می‌شود و وظایفش به سطح بالا می‌روند.'**
  String gnDeactivatePhaseBody(String title);

  /// No description provided for @gnRemoveFromPlan.
  ///
  /// In fa, this message translates to:
  /// **'حذف از برنامه'**
  String get gnRemoveFromPlan;

  /// No description provided for @gnRemoveFromPlanBody.
  ///
  /// In fa, this message translates to:
  /// **'«{title}» از نمودار حذف می‌شود (خود وظیفه می‌ماند).'**
  String gnRemoveFromPlanBody(String title);

  /// No description provided for @gnDependencies.
  ///
  /// In fa, this message translates to:
  /// **'وابستگی‌ها'**
  String get gnDependencies;

  /// No description provided for @gnDependenciesHelp.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نیازهای «{title}» (باید تمام شوند تا این وظیفه شروع شود):'**
  String gnDependenciesHelp(String title);

  /// No description provided for @gnNoDependencies.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌نیازی ندارد'**
  String get gnNoDependencies;

  /// No description provided for @gnAddDependency.
  ///
  /// In fa, this message translates to:
  /// **'افزودن پیش‌نیاز'**
  String get gnAddDependency;

  /// No description provided for @gnRemoveDependency.
  ///
  /// In fa, this message translates to:
  /// **'حذف وابستگی'**
  String get gnRemoveDependency;

  /// No description provided for @gnConflict.
  ///
  /// In fa, this message translates to:
  /// **'تداخل: این وظیفه زودتر از پایان پیش‌نیاز شروع می‌شود'**
  String get gnConflict;

  /// No description provided for @gnTaskReady.
  ///
  /// In fa, this message translates to:
  /// **'آماده شروع: {title}'**
  String gnTaskReady(String title);

  /// No description provided for @customerPickTitle.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب پرونده مشتری'**
  String get customerPickTitle;

  /// No description provided for @customerPickSearch.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی نام مشتری'**
  String get customerPickSearch;

  /// No description provided for @customerPickEmpty.
  ///
  /// In fa, this message translates to:
  /// **'پرونده‌ای پیدا نشد'**
  String get customerPickEmpty;

  /// No description provided for @tasksFilterCustomer.
  ///
  /// In fa, this message translates to:
  /// **'پرونده مشتری'**
  String get tasksFilterCustomer;

  /// No description provided for @tasksFilterCustomerOf.
  ///
  /// In fa, this message translates to:
  /// **'مشتری: {name}'**
  String tasksFilterCustomerOf(String name);

  /// No description provided for @chatVoiceDenied.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی به میکروفون داده نشده است.'**
  String get chatVoiceDenied;

  /// No description provided for @chatVoiceSend.
  ///
  /// In fa, this message translates to:
  /// **'ارسال'**
  String get chatVoiceSend;

  /// No description provided for @chatAudioPlayFailed.
  ///
  /// In fa, this message translates to:
  /// **'پخش صدا ممکن نشد.'**
  String get chatAudioPlayFailed;

  /// No description provided for @chatEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش پیام'**
  String get chatEdit;

  /// No description provided for @chatEditSave.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره'**
  String get chatEditSave;

  /// No description provided for @chatSearchInConversation.
  ///
  /// In fa, this message translates to:
  /// **'جستجو در گفتگو'**
  String get chatSearchInConversation;

  /// No description provided for @chatSearchNoResults.
  ///
  /// In fa, this message translates to:
  /// **'پیامی پیدا نشد'**
  String get chatSearchNoResults;

  /// No description provided for @chatToTaskTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان وظیفه'**
  String get chatToTaskTitle;

  /// No description provided for @chatToTaskCreate.
  ///
  /// In fa, this message translates to:
  /// **'ساخت وظیفه'**
  String get chatToTaskCreate;

  /// No description provided for @videoJoin.
  ///
  /// In fa, this message translates to:
  /// **'ورود به جلسه آنلاین'**
  String get videoJoin;

  /// No description provided for @videoTitle.
  ///
  /// In fa, this message translates to:
  /// **'جلسه آنلاین'**
  String get videoTitle;

  /// No description provided for @videoConnecting.
  ///
  /// In fa, this message translates to:
  /// **'در حال اتصال…'**
  String get videoConnecting;

  /// No description provided for @videoNotConfigured.
  ///
  /// In fa, this message translates to:
  /// **'جلسه آنلاین روی این سرور فعال نیست.'**
  String get videoNotConfigured;

  /// No description provided for @videoJoinFailed.
  ///
  /// In fa, this message translates to:
  /// **'اتصال به جلسه ممکن نشد.'**
  String get videoJoinFailed;

  /// No description provided for @videoRetry.
  ///
  /// In fa, this message translates to:
  /// **'تلاش دوباره'**
  String get videoRetry;

  /// No description provided for @videoMic.
  ///
  /// In fa, this message translates to:
  /// **'میکروفون'**
  String get videoMic;

  /// No description provided for @videoCamera.
  ///
  /// In fa, this message translates to:
  /// **'دوربین'**
  String get videoCamera;

  /// No description provided for @videoShare.
  ///
  /// In fa, this message translates to:
  /// **'اشتراک صفحه'**
  String get videoShare;

  /// No description provided for @videoLeave.
  ///
  /// In fa, this message translates to:
  /// **'خروج'**
  String get videoLeave;

  /// No description provided for @videoParticipants.
  ///
  /// In fa, this message translates to:
  /// **'{count} نفر در جلسه'**
  String videoParticipants(int count);

  /// No description provided for @videoYou.
  ///
  /// In fa, this message translates to:
  /// **'شما'**
  String get videoYou;

  /// No description provided for @videoExperimental.
  ///
  /// In fa, this message translates to:
  /// **'آزمایشی'**
  String get videoExperimental;

  /// No description provided for @crmLetterLink.
  ///
  /// In fa, this message translates to:
  /// **'اتصال نامه'**
  String get crmLetterLink;

  /// No description provided for @crmLetterUnlink.
  ///
  /// In fa, this message translates to:
  /// **'قطع اتصال نامه'**
  String get crmLetterUnlink;

  /// No description provided for @crmLetterPickTitle.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب نامه'**
  String get crmLetterPickTitle;

  /// No description provided for @crmLetterLinkFailed.
  ///
  /// In fa, this message translates to:
  /// **'اتصال نامه ممکن نشد. فقط سازنده نامه یا دبیرخانه می‌تواند آن را وصل کند.'**
  String get crmLetterLinkFailed;

  /// No description provided for @crmLetterPickEmpty.
  ///
  /// In fa, this message translates to:
  /// **'نامه‌ای برای اتصال نیست'**
  String get crmLetterPickEmpty;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

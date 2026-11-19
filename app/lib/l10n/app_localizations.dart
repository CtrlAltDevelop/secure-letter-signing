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

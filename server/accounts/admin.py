"""Superuser (developer) admin. Staff access is the superuser only; the manager uses the app/API.
Nothing can be deleted here. Letters will never be registered in this admin."""
import base64
import csv
import json

from django import forms
from django.contrib import messages
from django.http import HttpResponse
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import Group
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from django.shortcuts import redirect
from django.template.response import TemplateResponse
from django.urls import path, reverse
from unfold.admin import ModelAdmin
from unfold.decorators import action
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from .api_manager import LETTERHEAD_MAX_LOGO, LETTERHEAD_TEXT_FIELDS, clean_letterhead
from .models import (
    BASE_PERMISSION, AuditEvent, audit, verify_audit_chain, CompanySettings, InviteCode, Permission, Session, User,
)


# Groups are not used (permissions come from `grants`): hide them from the admin.
if admin.site.is_registered(Group):
    admin.site.unregister(Group)


class NoDelete:
    def has_delete_permission(self, request, obj=None) -> bool:
        return False


class ReadOnly(NoDelete):
    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False


def _check_single_manager(form: forms.ModelForm):
    wants = form.cleaned_data.get("is_manager")
    others = User.objects.filter(is_manager=True).exclude(pk=form.instance.pk)
    if wants and others.exists():
        raise forms.ValidationError(f"{others.first().email} is already the manager. Remove that role first.")
    return wants


class UserCreateForm(UserCreationForm):
    class Meta:
        model = User
        fields = ("email",)

    def clean_is_manager(self):
        return _check_single_manager(self)


class UserEditForm(UserChangeForm):
    class Meta:
        model = User
        fields = "__all__"

    def clean_is_manager(self):
        return _check_single_manager(self)


@admin.register(User)
class UserAdmin(NoDelete, BaseUserAdmin, ModelAdmin):
    actions_list = ["import_users"]
    form = UserEditForm
    add_form = UserCreateForm
    change_password_form = AdminPasswordChangeForm
    ordering = ("email",)
    list_display = ("email", "full_name", "is_manager", "is_active", "is_superuser")
    list_filter = ("is_manager", "is_active", "is_superuser")
    search_fields = ("email", "full_name")
    filter_horizontal = ("grants", "user_permissions")
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("full_name", "title", "department", "email_verified")}),
        ("Roles", {"fields": ("is_manager", "is_active", "is_staff", "is_superuser")}),
        ("Permissions", {"fields": ("grants", "user_permissions")}),
    )
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("email", "password1", "password2", "is_manager")}),)

    @action(description="Import users from CSV", url_path="import-users", permissions=["add"])
    def import_users(self, request):
        report, form = None, ImportUsersForm(request.POST or None, request.FILES or None)
        if request.method == "POST" and form.is_valid():
            try:
                text = form.cleaned_data["file"].read().decode("utf-8-sig")
                report = import_users_from_csv(text)
                audit(request.user, "users_imported", "", created=len(report["created"]), via="admin")
            except (UnicodeDecodeError, ValidationError) as e:
                form.add_error("file", e if isinstance(e, ValidationError) else "File must be UTF-8 text")
        context = {**self.admin_site.each_context(request), "title": "Import users", "form": form, "report": report,
                   "opts": self.model._meta}
        return TemplateResponse(request, "admin/accounts/import_users.html", context)


IMPORT_COLUMNS = ("email", "full_name", "title", "department")
IMPORT_MAX_ROWS = 2000


def import_users_from_csv(text: str) -> dict:
    """Create users from CSV (header: email, full_name, title, department). Existing emails are skipped,
    new users get no password (they use password reset) and the base permission. Returns a report."""
    reader = csv.DictReader(text.splitlines())
    if not reader.fieldnames or "email" not in [f.strip().lower() for f in reader.fieldnames]:
        raise ValidationError("The first row must be a header containing at least: email")
    base = Permission.objects.filter(code=BASE_PERMISSION).first()
    report = {"created": [], "skipped": [], "invalid": []}
    for n, raw in enumerate(reader, start=2):
        if n > IMPORT_MAX_ROWS + 1:
            raise ValidationError(f"At most {IMPORT_MAX_ROWS} rows per file")
        row = {k.strip().lower(): (v or "").strip() for k, v in raw.items() if k}
        email = row.get("email", "").lower()
        try:
            validate_email(email)
        except ValidationError:
            report["invalid"].append(f"line {n}: {email or '(empty)'}")
            continue
        if User.objects.filter(email__iexact=email).exists():
            report["skipped"].append(email)
            continue
        user = User.objects.create_user(email, None, **{c: row.get(c, "") for c in IMPORT_COLUMNS[1:]})
        if base:
            user.grants.add(base)
        report["created"].append(email)
    return report


class ImportUsersForm(forms.Form):
    file = forms.FileField(help_text="CSV, UTF-8, header: email, full_name, title, department (only email is required).")


@admin.register(Permission)
class PermissionAdmin(ModelAdmin):
    list_display = ("code", "description")
    search_fields = ("code",)


LOGO_MAGIC = (b"\x89PNG", b"\xff\xd8\xff")


class CompanySettingsForm(forms.ModelForm):
    """Flattens the letterhead JSON into plain fields; the logo is an uploaded PNG/JPEG."""

    lh_name = forms.CharField(label="Company name", required=False, max_length=300)
    lh_tagline = forms.CharField(label="Tagline / department", required=False, max_length=300)
    lh_address = forms.CharField(label="Address", required=False, max_length=300)
    lh_phone = forms.CharField(label="Phone", required=False, max_length=300)
    lh_email = forms.CharField(label="Email", required=False, max_length=300)
    lh_website = forms.CharField(label="Website", required=False, max_length=300)
    lh_footer = forms.CharField(label="Footer text", required=False, max_length=300)
    lh_logo = forms.FileField(label="Logo (PNG or JPEG, max 200 KB)", required=False)
    lh_remove_logo = forms.BooleanField(label="Remove current logo", required=False)

    class Meta:
        model = CompanySettings
        exclude = ("letterhead",)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        head = self.instance.letterhead or {}
        for key in LETTERHEAD_TEXT_FIELDS:
            self.fields[f"lh_{key}"].initial = head.get(key, "")

    def clean_lh_logo(self):
        f = self.cleaned_data.get("lh_logo")
        if not f:
            return None
        data = f.read()
        if not data.startswith(LOGO_MAGIC) or len(data) * 4 // 3 + 30 > LETTERHEAD_MAX_LOGO:
            raise forms.ValidationError("The logo must be a PNG or JPEG of at most 200 KB")
        mime = "png" if data.startswith(LOGO_MAGIC[0]) else "jpeg"
        return f"data:image/{mime};base64," + base64.b64encode(data).decode()

    def save(self, commit=True):
        head = {key: self.cleaned_data.get(f"lh_{key}", "") for key in LETTERHEAD_TEXT_FIELDS}
        old = (self.instance.letterhead or {}).get("logo", "")
        head["logo"] = "" if self.cleaned_data["lh_remove_logo"] else (self.cleaned_data["lh_logo"] or old)
        self.instance.letterhead = clean_letterhead(head)
        return super().save(commit)


@admin.register(CompanySettings)
class CompanySettingsAdmin(NoDelete, ModelAdmin):
    """One row only. No list: empty -> the create form, otherwise straight to the edit form."""

    form = CompanySettingsForm
    fieldsets = (
        ("Letterhead (printed on every letter)", {"fields": (
            "lh_name", "lh_tagline", "lh_address", "lh_phone", "lh_email", "lh_website", "lh_footer",
            "lh_logo", "lh_remove_logo")}),
        ("Signup", {"fields": ("signup_domain_enabled", "allowed_domain", "signup_invite_enabled")}),
        ("Email (SMTP)", {"classes": ("collapse",), "fields": (
            "smtp_host", "smtp_port", "smtp_user", "smtp_password", "smtp_use_tls", "from_email")}),
    )

    def has_add_permission(self, request) -> bool:
        return not CompanySettings.objects.exists()

    def save_model(self, request, obj, form, change):
        obj.pk = 1  # the singleton row (CompanySettings.load uses pk=1)
        super().save_model(request, obj, form, change)
        audit(request.user, "company_settings_changed", "", via="admin")

    def changelist_view(self, request, extra_context=None):
        app = self.opts.app_label + "_" + self.opts.model_name
        row = CompanySettings.objects.first()
        if row:
            return redirect(reverse(f"admin:{app}_change", args=[row.pk]))
        return redirect(reverse(f"admin:{app}_add"))


@admin.register(InviteCode)
class InviteCodeAdmin(NoDelete, ModelAdmin):
    """The superuser may issue and deactivate codes (the manager does it in the app). Never deleted."""

    list_display = ("code", "created_by", "uses", "max_uses", "active", "expires_at")
    fields = ("code", "max_uses", "expires_at", "active", "uses", "created_by")
    readonly_fields = ("code", "uses", "created_by")

    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
        if not change:
            audit(request.user, "invite_created", str(obj.pk), max_uses=obj.max_uses, via="admin")


@admin.register(Session)
class SessionAdmin(ReadOnly, ModelAdmin):
    list_display = ("user", "device_name", "platform", "ip", "last_active", "revoked_at")
    exclude = ("refresh_hash", "prev_refresh_hash", "rotated_at")


@admin.action(description="Export selected events as CSV")
def export_audit_csv(modeladmin, request, queryset):
    response = HttpResponse(content_type="text/csv")
    response["Content-Disposition"] = 'attachment; filename="audit.csv"'
    writer = csv.writer(response)
    writer.writerow(["id", "at", "actor", "action", "target", "data", "prev_hash", "hash"])
    for e in queryset.order_by("id").select_related("actor"):
        writer.writerow([e.id, e.at.isoformat(), e.actor.email if e.actor else "", e.action, e.target,
                         json.dumps(e.data, sort_keys=True), e.prev_hash, e.hash])
    return response


@admin.register(AuditEvent)
class AuditEventAdmin(ReadOnly, ModelAdmin):
    list_display = ("id", "at", "actor", "action", "target")
    list_filter = ("action",)
    actions = [export_audit_csv]

    def changelist_view(self, request, extra_context=None):
        broken = verify_audit_chain()
        if broken is None:
            messages.success(request, "Audit chain verified: no tampering detected.")
        else:
            messages.error(request, f"AUDIT CHAIN BROKEN at event #{broken}: a row was altered or removed.")
        return super().changelist_view(request, extra_context)

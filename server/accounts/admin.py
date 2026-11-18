"""Superuser (developer) admin. Staff access is the superuser only; the manager uses the app/API.
Nothing can be deleted here. Letters will never be registered in this admin."""
from django import forms
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from .models import AuditEvent, CompanySettings, InviteCode, Permission, Session, User


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
    form = UserEditForm
    add_form = UserCreateForm
    change_password_form = AdminPasswordChangeForm
    ordering = ("email",)
    list_display = ("email", "full_name", "is_manager", "is_active", "is_superuser")
    list_filter = ("is_manager", "is_active", "is_superuser")
    search_fields = ("email", "full_name")
    filter_horizontal = ("grants", "groups", "user_permissions")
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("full_name", "title", "department", "email_verified")}),
        ("Roles", {"fields": ("is_manager", "is_active", "is_staff", "is_superuser")}),
        ("Permissions", {"fields": ("grants", "groups", "user_permissions")}),
    )
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("email", "password1", "password2", "is_manager")}),)


@admin.register(Permission)
class PermissionAdmin(ModelAdmin):
    list_display = ("code", "description")
    search_fields = ("code",)


@admin.register(CompanySettings)
class CompanySettingsAdmin(NoDelete, ModelAdmin):
    def has_add_permission(self, request) -> bool:
        return not CompanySettings.objects.exists()


@admin.register(InviteCode)
class InviteCodeAdmin(ReadOnly, ModelAdmin):
    list_display = ("code", "created_by", "uses", "max_uses", "active", "expires_at")


@admin.register(Session)
class SessionAdmin(ReadOnly, ModelAdmin):
    list_display = ("user", "device_name", "platform", "ip", "last_active", "revoked_at")
    exclude = ("refresh_hash", "prev_refresh_hash", "rotated_at")


@admin.register(AuditEvent)
class AuditEventAdmin(ReadOnly, ModelAdmin):
    list_display = ("at", "actor", "action", "target")
    list_filter = ("action",)

from typing import Any

from ninja import NinjaAPI

from accounts.api_auth import router as auth_router
from accounts.api_manager import router as manager_router
from accounts.api_me import router as me_router
from accounts.api_prefs import router as prefs_router

from letters.sign_requests import router as sign_requests_router
from letters.api import router as letters_router
from letters.api_v2 import router as letters_v2_router

from crm.api import router as crm_router
from finance.api import router as finance_router
from sales.api import router as sales_router
from meetings.api import router as meetings_router
from meetings.api_templates import router as meeting_templates_router
from notes.api import router as notes_router
from polls.api import router as polls_router
from polls.api_templates import router as poll_templates_router
from projects.api import router as projects_router
from projects.api_groups import router as project_groups_router
from chat.api import router as chat_router
from gantt.api import router as gantt_router
from monitor.api import router as monitor_router
from tasks.api import router as tasks_router
from tasks.api_templates import router as task_templates_router
from workspace.api import router as workspace_router

from .brand import load_brand

api = NinjaAPI(title="Letter Signing API", version="0.2.0")
api.add_router("/auth", auth_router)
api.add_router("/me", me_router)
api.add_router("/me", prefs_router)
api.add_router("/manage", manager_router)
api.add_router("/letters", letters_router)
api.add_router("/sign-requests", sign_requests_router)
api.add_router("", letters_v2_router)  # /referrals, /secretariat
api.add_router("", workspace_router)
api.add_router("/tasks", tasks_router)
api.add_router("", task_templates_router)  # /task-templates, /tasks/from-template
api.add_router("/customers", crm_router)
api.add_router("", finance_router)  # /finance/*, /customers/{id}/finance
api.add_router("", sales_router)  # /sales/*, /customers/{id}/leads
api.add_router("/meetings", meetings_router)
api.add_router("/meeting-templates", meeting_templates_router)
api.add_router("/notes", notes_router)
api.add_router("/polls", polls_router)
api.add_router("/poll-templates", poll_templates_router)
api.add_router("/projects", projects_router)
api.add_router("/project-groups", project_groups_router)
api.add_router("", chat_router)
api.add_router("", gantt_router)  # /projects/{id}/gantt/*
api.add_router("/monitor", monitor_router)


@api.get("/health", auth=None)
def health(request) -> dict[str, str]:
    return {"status": "ok"}


@api.get("/brand", auth=None)
def brand(request) -> dict[str, Any]:
    """Public brand info (name, colors, feature switches) for the app's splash/login."""
    return load_brand()

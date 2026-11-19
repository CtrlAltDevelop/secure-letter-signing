"""Everything the client needs to draw a printable chart, in one flat payload."""
from django.utils import timezone

from accounts.models import User
from projects.models import Project
from workspace import holidays

from . import plan
from .schemas import PrintHoliday, PrintLink, PrintOut, PrintRow


def build(user: User, project: Project) -> PrintOut:
    chart = plan.build(user, project)
    rows = [PrintRow(kind="phase", wbs=p.wbs, level=1, title=p.title, status="", progress=p.progress, start=p.start,
                     end=p.end, owners=[]) for p in chart.phases]
    rows += [PrintRow(kind="task", wbs=i.wbs, level=i.level, title=i.title, status=i.status, progress=i.progress,
                      start=i.start, end=i.end, owners=[o.full_name or o.email for o in i.owners])
             for i in chart.items]
    rows.sort(key=lambda r: [int(n) for n in r.wbs.split(".")])
    wbs = {i.task_id: i.wbs for i in chart.items}
    links = [PrintLink(from_wbs=wbs[lk.predecessor_task_id], to_wbs=wbs[lk.successor_task_id], conflict=lk.conflict)
             for lk in chart.links]
    days = (chart.end - chart.start).days + 1 if chart.start and chart.end else 0
    marks = holidays.in_range(chart.start, chart.end) if days else []
    return PrintOut(project_id=project.pk, name=project.name, generated_at=timezone.now(), start=chart.start,
                    end=chart.end, days=days, weekend=holidays.WEEKEND, progress=project.progress, rows=rows,
                    links=links, holidays=[PrintHoliday(date=h.date, title=h.title) for h in marks])

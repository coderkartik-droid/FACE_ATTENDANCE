"""
Root URL configuration for face_attendance ERP.

/ -> Home Status Message
/health/ -> System Health Check
/admin/ -> Django Administration
/api/auth/ -> Authentication & Profiles
/api/classes/ -> Academic Classes & Sections
/api/faces/ -> Face Registration & Verification
/api/attendance/ -> Attendance Tracking
/api/reports/ -> Analytics & PDF/Excel Exports
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import HttpResponse, JsonResponse
from django.urls import include, path

def home_view(request):
    return HttpResponse("Face Attendance ERP Backend Running Successfully", content_type="text/plain")

def health_check(request):
    return JsonResponse({"status": "ok"})

urlpatterns = [
    path("", home_view, name="home"),
    path("health/", health_check, name="health_check"),
    path("admin/", admin.site.urls),
    path("api/auth/", include("apps.accounts.urls")),
    path("api/academics/", include("apps.academics.urls")),
    path("api/classes/", include("apps.academics.urls")),
    path("api/sections/", include("apps.academics.urls")),
    path("api/faces/", include("apps.faces.urls")),
    path("api/attendance/", include("apps.attendance.urls")),
    path("api/dashboard/", include("apps.reports.urls")),
    path("api/reports/", include("apps.reports.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

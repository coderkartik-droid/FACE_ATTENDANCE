from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from apps.attendance.models import AttendanceRecord
from apps.reports.services import DashboardService, ReportExportService


class DashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        data = DashboardService.get_dashboard_summary(
            request.user,
            selected_date=request.query_params.get("date"),
            start_date=request.query_params.get("start_date"),
            end_date=request.query_params.get("end_date"),
        )
        return Response({"success": True, "data": data})


class ExcelExportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        queryset = AttendanceRecord.objects.select_related(
            "student",
            "student__student_profile",
            "session",
            "session__class_obj",
            "session__section_obj",
        ).order_by("-marked_at")

        # Filters
        class_id = request.query_params.get("class_id")
        date_param = request.query_params.get("date")
        if class_id:
            queryset = queryset.filter(session__class_obj_id=class_id)
        if date_param:
            queryset = queryset.filter(session__date=date_param)

        excel_bytes = ReportExportService.generate_excel_report(queryset)

        response = HttpResponse(
            excel_bytes,
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        response["Content-Disposition"] = (
            'attachment; filename="attendance_report.xlsx"'
        )
        return response


class PDFExportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        queryset = AttendanceRecord.objects.select_related(
            "student",
            "student__student_profile",
            "session",
            "session__class_obj",
            "session__section_obj",
        ).order_by("-marked_at")

        # Filters
        class_id = request.query_params.get("class_id")
        date_param = request.query_params.get("date")
        if class_id:
            queryset = queryset.filter(session__class_obj_id=class_id)
        if date_param:
            queryset = queryset.filter(session__date=date_param)

        pdf_bytes = ReportExportService.generate_pdf_report(queryset)

        response = HttpResponse(pdf_bytes, content_type="application/pdf")
        response["Content-Disposition"] = 'attachment; filename="attendance_report.pdf"'
        return response

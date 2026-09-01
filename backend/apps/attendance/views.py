import logging
from rest_framework import generics, status, viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth import get_user_model
from django.utils import timezone

from core.mixins import StandardResponseMixin
from core.permissions import IsAdminOrTeacher
from core.exceptions import BusinessValidationError
from apps.attendance.models import AttendanceSession, AttendanceRecord
from apps.attendance.serializers import (
    AttendanceSessionSerializer,
    AttendanceRecordSerializer,
    MarkAttendanceRequestSerializer,
    BulkMarkAttendanceSerializer,
)
from apps.faces.services import FaceRecognitionService

logger = logging.getLogger(__name__)
User = get_user_model()


class AttendanceSessionViewSet(StandardResponseMixin, viewsets.ModelViewSet):
    permission_classes = [IsAdminOrTeacher]
    serializer_class = AttendanceSessionSerializer
    queryset = AttendanceSession.objects.select_related(
        "class_obj", "section_obj", "teacher"
    ).prefetch_related("records__student").all()
    filterset_fields = ["class_obj", "section_obj", "teacher", "date", "is_active"]
    search_fields = ["session_name", "class_obj__name", "section_obj__name"]

    def perform_create(self, serializer):
        serializer.save(teacher=self.request.user)


class MarkAttendanceView(generics.CreateAPIView):
    permission_classes = [IsAdminOrTeacher]
    serializer_class = MarkAttendanceRequestSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        session_id = serializer.validated_data["session_id"]
        try:
            session = AttendanceSession.objects.get(id=session_id)
        except AttendanceSession.DoesNotExist:
            logger.warning(f"Mark attendance failed: Session ID {session_id} not found.")
            raise BusinessValidationError("Attendance session not found.")

        image_file = serializer.validated_data.get("image")
        student_id = serializer.validated_data.get("student_id")
        status_choice = serializer.validated_data.get("status", AttendanceRecord.Status.PRESENT)
        remarks = serializer.validated_data.get("remarks", "")

        student = None
        method = AttendanceRecord.Method.MANUAL
        confidence = None

        if image_file:
            # Face recognition path
            face_results = FaceRecognitionService.extract_face_embeddings(image_file)
            best_face = max(face_results, key=lambda x: x["score"])

            matched_user, confidence = FaceRecognitionService.match_face(
                best_face["embedding"]
            )
            student = matched_user
            method = AttendanceRecord.Method.FACE_RECOGNITION
        elif student_id:
            try:
                student = User.objects.get(id=student_id, role=User.Role.STUDENT)
            except User.DoesNotExist:
                raise BusinessValidationError("Specified student not found.")
        else:
            raise BusinessValidationError("Either camera image or student_id must be provided.")

        record, created = AttendanceRecord.objects.update_or_create(
            session=session,
            student=student,
            defaults={
                "status": status_choice,
                "verification_method": method,
                "confidence_score": confidence,
                "remarks": remarks,
            },
        )

        logger.info(
            f"Attendance marked for {student.username} (ID: {student.id}) in Session {session.id} as {status_choice} via {method}."
        )

        return Response(
            {
                "success": True,
                "message": f"Attendance marked for {student.full_name} as {status_choice}.",
                "data": AttendanceRecordSerializer(record).data,
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class BulkMarkAttendanceView(generics.CreateAPIView):
    permission_classes = [IsAdminOrTeacher]
    serializer_class = BulkMarkAttendanceSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        session_id = serializer.validated_data["session_id"]
        records_data = serializer.validated_data["records"]

        try:
            session = AttendanceSession.objects.get(id=session_id)
        except AttendanceSession.DoesNotExist:
            raise BusinessValidationError("Attendance session not found.")

        updated_records = []
        for item in records_data:
            s_id = item.get("student_id")
            s_status = item.get("status", AttendanceRecord.Status.PRESENT)
            s_remarks = item.get("remarks", "")

            try:
                student_user = User.objects.get(id=s_id)
                rec, _ = AttendanceRecord.objects.update_or_create(
                    session=session,
                    student=student_user,
                    defaults={
                        "status": s_status,
                        "verification_method": AttendanceRecord.Method.MANUAL,
                        "remarks": s_remarks,
                    },
                )
                updated_records.append(rec)
            except User.DoesNotExist:
                continue

        logger.info(f"Bulk attendance updated for {len(updated_records)} students in Session {session.id}.")

        return Response(
            {
                "success": True,
                "message": f"Bulk attendance updated for {len(updated_records)} students.",
                "data": {
                    "session_id": session.id,
                    "updated_count": len(updated_records),
                },
            }
        )


class AttendanceHistoryView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = AttendanceRecordSerializer

    def get_queryset(self):
        user = self.request.user
        queryset = AttendanceRecord.objects.select_related(
            "session", "student", "student__student_profile"
        )

        if user.is_student():
            queryset = queryset.filter(student=user)
        elif user.is_teacher():
            queryset = queryset.filter(session__teacher=user)

        # Filters
        class_id = self.request.query_params.get("class_id")
        section_id = self.request.query_params.get("section_id")
        date_param = self.request.query_params.get("date")
        status_param = self.request.query_params.get("status")

        if class_id:
            queryset = queryset.filter(session__class_obj_id=class_id)
        if section_id:
            queryset = queryset.filter(session__section_obj_id=section_id)
        if date_param:
            queryset = queryset.filter(session__date=date_param)
        if status_param:
            queryset = queryset.filter(status=status_param)

        return queryset


class TodayAttendanceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        today = timezone.localdate()
        user = request.user
        queryset = AttendanceRecord.objects.select_related(
            "session", "student", "session__class_obj"
        ).filter(session__date=today)

        if user.is_student():
            queryset = queryset.filter(student=user)
        elif user.is_teacher():
            queryset = queryset.filter(session__teacher=user)

        serializer = AttendanceRecordSerializer(queryset, many=True)
        return Response({
            "success": True,
            "date": str(today),
            "count": queryset.count(),
            "data": serializer.data,
        })


class MonthlyAttendanceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        now = timezone.localdate()
        year = int(request.query_params.get("year", now.year))
        month = int(request.query_params.get("month", now.month))

        user = request.user
        queryset = AttendanceRecord.objects.select_related(
            "session", "student"
        ).filter(session__date__year=year, session__date__month=month)

        if user.is_student():
            queryset = queryset.filter(student=user)
        elif user.is_teacher():
            queryset = queryset.filter(session__teacher=user)

        total = queryset.count()
        present = queryset.filter(status=AttendanceRecord.Status.PRESENT).count()
        absent = queryset.filter(status=AttendanceRecord.Status.ABSENT).count()
        late = queryset.filter(status=AttendanceRecord.Status.LATE).count()

        serializer = AttendanceRecordSerializer(queryset[:100], many=True)
        return Response({
            "success": True,
            "year": year,
            "month": month,
            "summary": {
                "total": total,
                "present": present,
                "absent": absent,
                "late": late,
                "attendance_percentage": round((present / total * 100), 1) if total > 0 else 0.0,
            },
            "records": serializer.data,
        })


class StudentHistoryView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = AttendanceRecordSerializer

    def get_queryset(self):
        user = self.request.user
        student_id = self.request.query_params.get("student_id")

        queryset = AttendanceRecord.objects.select_related("session", "student")
        if user.is_student():
            return queryset.filter(student=user)
        elif student_id:
            return queryset.filter(student_id=student_id)
        return queryset


class TeacherHistoryView(generics.ListAPIView):
    permission_classes = [IsAdminOrTeacher]
    serializer_class = AttendanceRecordSerializer

    def get_queryset(self):
        user = self.request.user
        teacher_id = self.request.query_params.get("teacher_id")

        queryset = AttendanceRecord.objects.select_related("session", "student")
        if user.is_teacher():
            return queryset.filter(session__teacher=user)
        elif teacher_id:
            return queryset.filter(session__teacher_id=teacher_id)
        return queryset

from django.conf import settings
from django.db import models
from django.utils import timezone


class AttendanceSession(models.Model):
    class_obj = models.ForeignKey(
        "academics.Class", on_delete=models.CASCADE, related_name="sessions"
    )
    section_obj = models.ForeignKey(
        "academics.Section", on_delete=models.CASCADE, related_name="sessions"
    )
    teacher = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="managed_sessions",
    )
    date = models.DateField(default=timezone.now)
    session_name = models.CharField(max_length=100, default="Daily Attendance")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date", "-created_at"]
        unique_together = ("class_obj", "section_obj", "date", "session_name")

    def __str__(self):
        return f"{self.class_obj.name}-{self.section_obj.name} ({self.date})"


class AttendanceRecord(models.Model):
    class Status(models.TextChoices):
        PRESENT = "PRESENT", "Present"
        ABSENT = "ABSENT", "Absent"
        LATE = "LATE", "Late"

    class Method(models.TextChoices):
        FACE_RECOGNITION = "FACE_RECOGNITION", "Face Recognition"
        MANUAL = "MANUAL", "Manual"

    session = models.ForeignKey(
        AttendanceSession, on_delete=models.CASCADE, related_name="records"
    )
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="attendance_records",
    )
    status = models.CharField(
        max_length=15, choices=Status.choices, default=Status.ABSENT
    )
    verification_method = models.CharField(
        max_length=20, choices=Method.choices, default=Method.FACE_RECOGNITION
    )
    confidence_score = models.FloatField(null=True, blank=True)
    marked_at = models.DateTimeField(auto_now=True)
    remarks = models.CharField(max_length=255, blank=True)

    class Meta:
        unique_together = ("session", "student")
        ordering = ["student__first_name"]

    def __str__(self):
        return f"{self.student.username} - {self.status} ({self.session.date})"

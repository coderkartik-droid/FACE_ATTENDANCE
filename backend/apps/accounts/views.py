from rest_framework import generics, status, viewsets
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth import get_user_model

from core.mixins import StandardResponseMixin
from core.permissions import IsAdmin, IsAdminOrTeacher, IsSelfOrAdminOrTeacher
from apps.accounts.models import TeacherProfile, StudentProfile
from apps.accounts.serializers import (
    RoleTokenObtainPairSerializer,
    UserSerializer,
    TeacherProfileSerializer,
    TeacherRegisterSerializer,
    StudentProfileSerializer,
    StudentRegisterSerializer,
    ChangePasswordSerializer,
)

User = get_user_model()


class RoleTokenObtainPairView(TokenObtainPairView):
    serializer_class = RoleTokenObtainPairSerializer


class MeView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user

    def retrieve(self, request, *args, **kwargs):
        user = self.get_object()
        user_data = UserSerializer(user, context={"request": request}).data

        profile_data = None
        if user.is_teacher() and hasattr(user, "teacher_profile"):
            profile_data = TeacherProfileSerializer(user.teacher_profile).data
        elif user.is_student() and hasattr(user, "student_profile"):
            profile_data = StudentProfileSerializer(user.student_profile).data

        return Response(
            {
                "success": True,
                "message": "User profile fetched successfully.",
                "data": {
                    "user": user_data,
                    "profile": profile_data,
                },
            }
        )


class RegisterTeacherView(generics.CreateAPIView):
    permission_classes = [IsAdmin]
    serializer_class = TeacherRegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            {
                "success": True,
                "message": "Teacher registered successfully.",
                "data": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


class RegisterStudentView(generics.CreateAPIView):
    permission_classes = [IsAdminOrTeacher]
    serializer_class = StudentRegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            {
                "success": True,
                "message": "Student registered successfully.",
                "data": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


class ChangePasswordView(generics.UpdateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ChangePasswordSerializer

    def update(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.check_password(serializer.validated_data["old_password"]):
            return Response(
                {"success": False, "message": "Incorrect old password."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(serializer.validated_data["new_password"])
        user.save()
        return Response(
            {"success": True, "message": "Password changed successfully."}
        )


class StudentViewSet(StandardResponseMixin, viewsets.ModelViewSet):
    permission_classes = [IsAdminOrTeacher]
    serializer_class = StudentProfileSerializer
    queryset = StudentProfile.objects.select_related("user", "class_obj", "section_obj").all()
    filterset_fields = ["class_obj", "section_obj", "gender"]
    search_fields = ["user__first_name", "user__last_name", "user__username", "roll_number"]


class TeacherViewSet(StandardResponseMixin, viewsets.ModelViewSet):
    permission_classes = [IsAdmin]
    serializer_class = TeacherProfileSerializer
    queryset = TeacherProfile.objects.select_related("user").all()
    filterset_fields = ["department"]
    search_fields = ["user__first_name", "user__last_name", "user__username", "employee_id"]

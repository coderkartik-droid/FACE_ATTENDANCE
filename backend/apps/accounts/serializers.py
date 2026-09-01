from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.db import transaction
from apps.accounts.models import TeacherProfile, StudentProfile
from apps.academics.models import Class, Section

User = get_user_model()


class RoleTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["role"] = user.role
        token["username"] = user.username
        token["full_name"] = user.full_name
        token["email"] = user.email
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["role"] = self.user.role
        data["username"] = self.user.username
        data["full_name"] = self.user.full_name
        data["email"] = self.user.email
        data["user_id"] = self.user.id
        return data


class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "role",
            "phone",
            "profile_picture",
        )
        read_only_fields = ("id", "role")


class TeacherProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = TeacherProfile
        fields = (
            "id",
            "user",
            "employee_id",
            "department",
            "qualification",
            "created_at",
        )


class TeacherRegisterSerializer(serializers.ModelSerializer):
    username = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True, validators=[validate_password])
    email = serializers.EmailField(write_only=True)
    first_name = serializers.CharField(write_only=True)
    last_name = serializers.CharField(write_only=True)
    phone = serializers.CharField(write_only=True, required=False, allow_blank=True)
    employee_id = serializers.CharField(write_only=True)
    department = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = (
            "username",
            "password",
            "email",
            "first_name",
            "last_name",
            "phone",
        )

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError(
                "A user with this username already exists."
            )
        return value

    def validate_email(self, value):
        if value and User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value

    def validate_employee_id(self, value):
        if TeacherProfile.objects.filter(employee_id=value).exists():
            raise serializers.ValidationError(
                "A teacher with this employee ID already exists."
            )
        return value

    @transaction.atomic
    def create(self, validated_data):
        emp_id = validated_data.pop("employee_id")
        dept = validated_data.pop("department")
        phone = validated_data.pop("phone", "")

        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data["email"],
            password=validated_data["password"],
            first_name=validated_data["first_name"],
            last_name=validated_data["last_name"],
            phone=phone,
            role=User.Role.TEACHER,
        )
        TeacherProfile.objects.create(user=user, employee_id=emp_id, department=dept)
        return user


class StudentProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    class_name = serializers.CharField(source="class_obj.name", read_only=True)
    section_name = serializers.CharField(source="section_obj.name", read_only=True)

    class Meta:
        model = StudentProfile
        fields = (
            "id",
            "user",
            "roll_number",
            "father_name",
            "mother_name",
            "class_obj",
            "class_name",
            "section_obj",
            "section_name",
            "date_of_birth",
            "gender",
            "guardian_name",
            "guardian_phone",
            "address",
            "is_registration_complete",
            "created_at",
        )


class StudentRegisterSerializer(serializers.ModelSerializer):
    username = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True, validators=[validate_password])
    email = serializers.EmailField(write_only=True)
    first_name = serializers.CharField(write_only=True)
    last_name = serializers.CharField(write_only=True)
    father_name = serializers.CharField(
        write_only=True, required=False, allow_blank=True
    )
    mother_name = serializers.CharField(
        write_only=True, required=False, allow_blank=True
    )
    phone = serializers.CharField(write_only=True, required=False, allow_blank=True)
    roll_number = serializers.CharField(write_only=True)
    class_id = serializers.IntegerField(
        write_only=True, required=False, allow_null=True
    )
    section_id = serializers.IntegerField(
        write_only=True, required=False, allow_null=True
    )
    date_of_birth = serializers.DateField(
        write_only=True, required=False, allow_null=True
    )
    gender = serializers.CharField(write_only=True, default="male")
    guardian_name = serializers.CharField(
        write_only=True, required=False, allow_blank=True
    )
    guardian_phone = serializers.CharField(
        write_only=True, required=False, allow_blank=True
    )
    address = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = User
        fields = (
            "username",
            "password",
            "email",
            "first_name",
            "last_name",
            "phone",
            "father_name",
            "mother_name",
            "roll_number",
            "class_id",
            "section_id",
            "date_of_birth",
            "gender",
            "guardian_name",
            "guardian_phone",
            "address",
        )

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError(
                "A user with this username already exists."
            )
        return value

    def validate_email(self, value):
        if value and User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value

    def validate_roll_number(self, value):
        if StudentProfile.objects.filter(roll_number=value).exists():
            raise serializers.ValidationError(
                "A student with this roll number already exists."
            )
        return value

    @transaction.atomic
    def create(self, validated_data):
        roll_number = validated_data.pop("roll_number")
        father_name = validated_data.pop("father_name", "")
        mother_name = validated_data.pop("mother_name", "")
        class_id = validated_data.pop("class_id", None)
        section_id = validated_data.pop("section_id", None)
        dob = validated_data.pop("date_of_birth", None)
        gender = validated_data.pop("gender", "male")
        phone = validated_data.pop("phone", "")
        guardian_name = validated_data.pop("guardian_name", "")
        guardian_phone = validated_data.pop("guardian_phone", "")
        address = validated_data.pop("address", "")

        if class_id and not Class.objects.filter(id=class_id).exists():
            class_id = None
        if section_id and not Section.objects.filter(id=section_id).exists():
            section_id = None

        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data["email"],
            password=validated_data["password"],
            first_name=validated_data["first_name"],
            last_name=validated_data["last_name"],
            phone=phone,
            role=User.Role.STUDENT,
        )
        StudentProfile.objects.create(
            user=user,
            roll_number=roll_number,
            father_name=father_name,
            mother_name=mother_name,
            class_obj_id=class_id,
            section_obj_id=section_id,
            date_of_birth=dob,
            gender=gender,
            guardian_name=guardian_name,
            guardian_phone=guardian_phone,
            address=address,
            is_registration_complete=False,
        )
        return user


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])

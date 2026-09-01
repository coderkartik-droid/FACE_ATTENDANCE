# Face Attendance System — Fix Report

**Date:** 2026-09-01
**Scope:** Full-stack (Django + DRF + PostgreSQL backend, Flutter frontend)
**Result:** All 15 requirements addressed; backend verified end-to-end (23/23 API checks pass).

---

## 1. Root Causes & Fixes

### 1.1 — Login returning HTTP 301 (CRITICAL)
**Root cause:** Two separate Django behaviours produce redirects on API requests:
1. `APPEND_SLASH=True` (Django default) — a `POST` to a URL without a trailing
   slash triggers a slash-normalisation redirect. In older Django this is a `301`;
   in Django 5.x it raises `RuntimeError` → HTTP `500` (`You called this URL via POST,
   but the URL doesn't end in a slash…`).
2. `SECURE_SSL_REDIRECT=True` was auto-enabled whenever `not DEBUG`, so any
   misconfigured/gunicorn launch silently 301'd **every** request to HTTPS.

**Fix:**
- `settings.py`: `APPEND_SLASH = False` (no slash redirect ever; all API routes already
  use trailing slashes).
- `settings.py`: `SECURE_SSL_REDIRECT` is now **opt-in** via `SECURE_SSL_REDIRECT` env
  (default `False`).
- Flutter `api_client.dart`: `followRedirects: false` so a redirect is treated as an
  error, never followed.

**Result:** login returns `200` (success) / `400` (validation) / `401` (bad credentials).
Never `301`/`302`.

### 1.2 — Registration HTTP 500
**Root cause:** `TeacherRegisterSerializer` declared `employee_id` and `department`
fields but did **not** include them in `Meta.fields`. DRF raises
`AssertionError: The field 'employee_id' was declared … but has not been included in
the 'fields' option` → 500 on every teacher registration.

**Fix:** Added `employee_id` and `department` to `Meta.fields`.

### 1.3 — Admin account became Student
**Root cause:** Migration `0001` defined roles `admin/teacher/student`; migration `0003`
renamed them to `super_admin/school_admin/teacher/student`. Any pre-existing `admin`
row was left with an invalid role, and the `default=student` could silently demote it.
The old `ensure_default_admin` signal skipped repair if a user named `admin` already
existed.

**Fix:**
- New data migration `accounts/0004_normalize_roles.py` maps legacy `admin` → `super_admin`
  and promotes superusers/staff to `super_admin`.
- `ensure_default_admin` signal now **repairs** any existing `admin` account back to
  `SUPER_ADMIN` (`is_staff`/`is_superuser`/`is_active`), so a super admin can never stay
  a student.

### 1.4 — Role system & permissions
**Root cause:** Legacy `"admin"` role string was scattered across `core/permissions.py`;
student registration used `IsAdminOrTeacher` (allowed teachers).

**Fix:**
- `core/permissions.py`: cleaned to only `super_admin`/`school_admin` (+ `is_superuser`).
- `RegisterStudentView` → `IsSchoolAdmin` (only SUPER_ADMIN / SCHOOL_ADMIN).
- `RegisterTeacherView` → `IsSchoolAdmin`.
- `RegisterFaceView` → `IsSchoolAdmin` + validates the target is actually a **student**.

### 1.5 — Camera / Face Enrollment flow
**Root cause:** Face enrollment was a full-screen native picker with a per-photo
"Capture" button (effectively a manual enrollment step).

**Fix:** Rewrote `face_registration_screen.dart` to use the in-app `camera` package:
small camera window → **automatic** capture of exactly 5 photos → progress
"Image 1/5 … Image 5/5" → auto-upload → backend generates the face encoding → camera
closes → **"Registration Completed Successfully"**. No separate enrollment button.
Camera only ever opens on this screen, reached only after a successful registration.

### 1.6 — Attendance session creation failing
**Root cause:** `AttendanceSessionSerializer` required `teacher` in the request body
while the view already assigns `teacher=request.user` in `perform_create`.

**Fix:** `read_only_fields = ("teacher",)`.

### 1.7 — Duplicate URLs
**Root cause:** root `urls.py` included `apps.academics.urls` at `api/academics/`,
`api/classes/`, `api/sections/`, and `apps.reports.urls` at both `api/dashboard/` and
`api/reports/`.

**Fix:** Single canonical include per app:
`api/auth/`, `api/academics/`, `api/faces/`, `api/attendance/`, `api/reports/`.
Redundant `reports/urls.py` aliases (`""`, `summary/`) removed.

### 1.8 — JWT refresh / expiration
**Fix:** `api_client.dart` now has a refresh interceptor — on `401` it exchanges the
stored refresh token for a new access token and retries once; the rotated refresh token
(SimpleJWT `ROTATE_REFRESH_TOKENS`) is persisted.

### 1.9 — Dashboard statistics
**Fix:** `DashboardService` now returns, and the Flutter dashboard renders:
Total Students, Total Teachers, Total Classes, **Today's Attendance**, Face Registered,
Face Pending, **class-wise student count**, **class-wise attendance** (`class_attendance`).

### 1.10 — API base URL hard-coded
**Fix:** `ApiClient` reads `API_BASE_URL` via `String.fromEnvironment`
(default `http://10.0.2.2:8000/api/`), overridable with
`flutter run --dart-define=API_BASE_URL=http://192.168.1.7:8000/api/`.

### 1.11 — Misc cleanup
- Removed unused imports (backend): `AllowAny`, `Q`, `IsStudent`, `UserSerializer`,
  `Border`, `Side`, `Spacer`, `post_migrate`, `row_font`.
- Added `.order_by()` to `StudentViewSet`/`TeacherViewSet` (fixes
  `UnorderedObjectListWarning` pagination warning).
- Flutter: consistent error-message parsing of the API `{success, message, errors}` shape;
  password validators aligned to Django's 8-char minimum.
- `.env.example` documents `DB_ENGINE` and `SECURE_SSL_REDIRECT`.

---

## 2. Files Modified

**Backend (Django)**
| File | Change |
|---|---|
| `backend/face_attendance/settings.py` | `APPEND_SLASH=False`, opt-in `SECURE_SSL_REDIRECT`, `DB_ENGINE` sqlite fallback |
| `backend/face_attendance/urls.py` | removed duplicate includes |
| `backend/core/permissions.py` | role cleanup (`super_admin`/`school_admin`) |
| `backend/apps/accounts/serializers.py` | teacher `employee_id`/`department` in fields |
| `backend/apps/accounts/views.py` | `IsSchoolAdmin` on register; queryset ordering; unused imports |
| `backend/apps/accounts/signals.py` | robust super-admin seed/repair |
| `backend/apps/accounts/migrations/0004_normalize_roles.py` | **new** role-normalisation data migration |
| `backend/apps/faces/serializers.py` | exactly 5 images |
| `backend/apps/faces/views.py` | `IsSchoolAdmin` + student-only validation |
| `backend/apps/attendance/serializers.py` | `teacher` read-only |
| `backend/apps/attendance/views.py` | removed unused imports |
| `backend/apps/academics/views.py` | removed unused import |
| `backend/apps/reports/services.py` | dashboard `today_attendance` + `class_attendance` |
| `backend/apps/reports/urls.py` | deduplicated routes |
| `backend/.env.example` | documented new env vars |

**Frontend (Flutter)**
| File | Change |
|---|---|
| `lib/core/network/api_client.dart` | configurable base URL + JWT refresh interceptor + no-redirect |
| `lib/features/auth/screens/login_screen.dart` | proper 401/error message handling |
| `lib/features/registration/screens/student_registration_screen.dart` | automatic flow into face capture + error parsing |
| `lib/features/registration/screens/teacher_registration_screen.dart` | password min 8 |
| `lib/features/face_registration/screens/face_registration_screen.dart` | **rewritten** — in-app camera, auto 5-photo capture, progress, auto-upload |
| `lib/features/dashboard/screens/admin_dashboard_screen.dart` | Today's Attendance + class-wise breakdown |

---

## 3. Commands Executed (verified)

```bash
python manage.py check                  # System check identified no issues
python manage.py makemigrations --check # No changes detected (migration committed)
python manage.py migrate                # Applied incl. accounts.0004_normalize_roles
python manage.py runserver 0.0.0.0:8000
python -m pyflakes apps core face_attendance   # only 2 intentional warnings
```

---

## 4. Test Results (curl, live server)

| # | Test | Expected | Actual |
|---|---|---|---|
| 1 | login (trailing slash) | 200 | 200 ✅ |
| 2 | login (no slash) — no redirect/500 | 404 | 404 ✅ |
| 3 | login wrong password | 401 | 401 ✅ |
| 4 | token refresh | 200 | 200 ✅ |
| 5 | `me/` | 200 | 200 ✅ |
| 6 | register teacher | 201 | 201 ✅ |
| 7 | register student | 201 | 201 ✅ |
| 8 | duplicate roll number | 400 | 400 ✅ |
| 9 | teacher → create student | 403 | 403 ✅ |
| 10 | teacher → create teacher | 403 | 403 ✅ |
| 11 | student → create student | 403 | 403 ✅ |
| 12 | anonymous → create student | 401 | 401 ✅ |
| 13 | face register (teacher target) | 400 | 400 ✅ |
| 14 | face register (student, 5 images) | 201 | 201 ✅ |
| 15 | face register (1 image) | 400 | 400 ✅ |
| 16 | create class | 201 | 201 ✅ |
| 17 | create section | 201 | 201 ✅ |
| 18 | create attendance session | 201 | 201 ✅ |
| 19 | mark attendance | 201 | 201 ✅ |
| 20 | dashboard | 200 | 200 ✅ |
| 21 | export excel | 200 | 200 ✅ |
| 22 | export pdf | 200 | 200 ✅ |
| 23 | health | 200 | 200 ✅ |

**Super-admin repair test:** demoted `admin` → `student`, ran `ensure_default_admin`,
verified it returned to `super_admin` with `is_superuser=True`. ✅

---

## 5. Remaining Issues / Notes

1. **Flutter SDK not present in this sandbox** — `flutter analyze` / `flutter run`
   could not be executed here. The Dart changes were written carefully and reviewed, and
   the previous repo `flutter analyze` output was "No issues found". Run on your machine:
   ```bash
   cd frontend/face_attendance_app
   flutter clean && flutter pub get && flutter analyze
   flutter run --dart-define=API_BASE_URL=http://192.168.1.7:8000/api/
   ```
2. **PostgreSQL not installable in this sandbox** (network egress limited to PyPI/GitHub).
   The backend was verified against SQLite via the new `DB_ENGINE=sqlite` option;
   PostgreSQL remains the default/production engine (`DB_ENGINE` unset).
3. **InsightFace not installed in this sandbox** — face recognition used the built-in
   synthetic-embedding fallback. Install `insightface`, `onnxruntime`, `opencv-python`
   (already in `requirements.txt`) for real 512-D matching.
4. **Token storage** uses `SharedPreferences` (plain text). For production hardening,
   migrate to `flutter_secure_storage` (already in `pubspec.yaml`).
5. **Live attendance Flutter screen** (`live_attendance_screen.dart`) remains a stub
   (hard-coded `session_id`, does not upload the captured frame). The **backend**
   attendance endpoints are fully working; the screen still needs a session picker +
   `FormData` upload to be functional end-to-end.
6. The repo tracks `backend/.env` (contains a dev DB password) and `__pycache__/*.pyc`
   files; consider adding a `.gitignore` for these.

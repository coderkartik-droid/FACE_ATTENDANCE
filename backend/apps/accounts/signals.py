import logging
from django.db.models.signals import post_save, post_migrate
from django.dispatch import receiver
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)
User = get_user_model()


@receiver(post_save, sender=User)
def log_user_creation(sender, instance, created, **kwargs):
    if created:
        logger.info(
            f"New user registered: Username '{instance.username}', Role '{instance.role}', ID {instance.id}"
        )


def ensure_default_admin(sender, **kwargs):
    """Automatically seeds default Super Admin account (admin / admin123) if no admin user exists."""
    try:
        if not User.objects.filter(role__in=[User.Role.SUPER_ADMIN, User.Role.SCHOOL_ADMIN]).exists() and not User.objects.filter(username="admin").exists():
            admin_user = User.objects.create_user(
                username="admin",
                email="admin@school.com",
                password="admin123",
                first_name="Super",
                last_name="Admin",
                role=User.Role.SUPER_ADMIN,
                is_staff=True,
                is_superuser=True,
            )
            logger.info("Default Super Admin account created successfully (Username: admin, Password: admin123).")
    except Exception as e:
        logger.warning(f"Default admin initialization skipped: {e}")

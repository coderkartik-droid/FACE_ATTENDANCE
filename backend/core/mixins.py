"""Reusable viewset mixins."""

from rest_framework import status
from rest_framework.response import Response


class StandardResponseMixin:
    """Wraps list/retrieve/create/update payloads into a {success, message, data} envelope."""

    message = "Success."

    def _envelope(self, data, message=None, status_code=None):
        return Response(
            {
                "success": status_code is None or status_code < 400,
                "message": message or self.message,
                "data": data,
            },
            status=status_code or status.HTTP_200_OK,
        )

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        return self._envelope(response.data)

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(request, *args, **kwargs)
        return self._envelope(response.data)

    def create(self, request, *args, **kwargs):
        response = super().create(request, *args, **kwargs)
        return self._envelope(
            response.data, "Created successfully.", status.HTTP_201_CREATED
        )

    def update(self, request, *args, **kwargs):
        response = super().update(request, *args, **kwargs)
        return self._envelope(response.data, "Updated successfully.")

    def partial_update(self, request, *args, **kwargs):
        response = super().partial_update(request, *args, **kwargs)
        return self._envelope(response.data, "Updated successfully.")

    def destroy(self, request, *args, **kwargs):
        super().destroy(request, *args, **kwargs)
        return self._envelope(None, "Deleted successfully.", status.HTTP_200_OK)

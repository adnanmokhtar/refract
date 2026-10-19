from celery.result import AsyncResult
from rest_framework.response import Response
from rest_framework.views import APIView

from .reports_tasks import build_ar_aging_report


class AgingReportStart(APIView):
    def post(self, request):
        task = build_ar_aging_report.delay(request.data["as_of"])
        return Response({"task_id": task.id}, status=202)


class AgingReportStatus(APIView):
    def get(self, request, task_id):
        result = AsyncResult(task_id)
        return Response({"state": result.state, "report_id": result.result if result.ready() else None})

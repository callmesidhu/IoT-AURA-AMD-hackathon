from fastapi import APIRouter
from services.threat_detector import alert_history

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("")
def get_alerts(limit: int = 20):
    """Return the most recent alerts."""
    return list(alert_history)[:limit]


@router.get("/latest")
def get_latest_alert():
    """Return the single most recent alert, or null."""
    if alert_history:
        return alert_history[0]
    return {"message": "No alerts"}


@router.get("/active")
def get_active_alerts():
    """Return only WARNING and CRITICAL alerts (non-safe)."""
    return [a for a in alert_history if a["severity"] != "safe"]

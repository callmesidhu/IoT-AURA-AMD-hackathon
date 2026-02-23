"""
Evacuation Route Service
Calculates escape routes from danger zones to safe exit points.
For the hackathon prototype, safe exits are predefined.
"""
import math
from typing import List, Tuple


# Predefined safe exit points (for prototype demo)
# These represent known safe zones / evacuation assembly points
SAFE_EXITS = [
    {"id": 1, "name": "Safe Zone Alpha", "lat": 11.6700, "lng": 76.1200, "type": "assembly_point"},
    {"id": 2, "name": "Safe Zone Bravo", "lat": 11.6900, "lng": 76.1450, "type": "assembly_point"},
    {"id": 3, "name": "Hospital Emergency", "lat": 11.6750, "lng": 76.1400, "type": "hospital"},
    {"id": 4, "name": "Fire Station", "lat": 11.6820, "lng": 76.1150, "type": "fire_station"},
]


def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance between two points in meters."""
    R = 6371000  # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def find_nearest_exit(lat: float, lng: float, avoid_lat: float = None, avoid_lng: float = None) -> dict:
    """Find the nearest safe exit point, optionally avoiding a danger zone."""
    best = None
    best_dist = float('inf')

    for exit_pt in SAFE_EXITS:
        dist = haversine(lat, lng, exit_pt["lat"], exit_pt["lng"])

        # If avoiding a danger zone, penalize exits that are close to it
        if avoid_lat and avoid_lng:
            danger_dist = haversine(exit_pt["lat"], exit_pt["lng"], avoid_lat, avoid_lng)
            if danger_dist < 300:  # exit is within 300m of danger — skip
                continue

        if dist < best_dist:
            best_dist = dist
            best = exit_pt

    if best is None:
        best = SAFE_EXITS[0]  # fallback
        best_dist = haversine(lat, lng, best["lat"], best["lng"])

    return {
        **best,
        "distance_m": round(best_dist),
        "estimated_time_min": round(best_dist / 80, 1),  # ~80m/min walking speed
    }


def get_evacuation_route(danger_lat: float, danger_lng: float, user_lat: float = None, user_lng: float = None) -> dict:
    """
    Generate an evacuation route from a danger zone.
    Returns:
    - danger_zone: the threat location
    - safe_exit: nearest safe assembly point
    - route_points: list of [lat, lng] waypoints for the escape route
    - blocked_route: the route through the danger zone (to show as blocked)
    """
    # Use user location or default to slightly offset from danger
    if user_lat is None:
        user_lat = danger_lat - 0.005
    if user_lng is None:
        user_lng = danger_lng - 0.002

    # Find nearest safe exit avoiding the danger zone
    safe_exit = find_nearest_exit(user_lat, user_lng, avoid_lat=danger_lat, avoid_lng=danger_lng)

    # Create a simple waypoint route that avoids the danger zone
    # Offset the midpoint away from the danger zone
    mid_lat = (user_lat + safe_exit["lat"]) / 2
    mid_lng = (user_lng + safe_exit["lng"]) / 2

    # Push midpoint away from danger
    offset_lat = mid_lat - danger_lat
    offset_lng = mid_lng - danger_lng
    magnitude = max(math.sqrt(offset_lat ** 2 + offset_lng ** 2), 0.001)
    push_factor = 0.003 / magnitude  # push 300m away

    safe_mid_lat = mid_lat + offset_lat * push_factor
    safe_mid_lng = mid_lng + offset_lng * push_factor

    return {
        "danger_zone": {"lat": danger_lat, "lng": danger_lng},
        "user_location": {"lat": user_lat, "lng": user_lng},
        "safe_exit": safe_exit,
        "safe_route": [
            [user_lat, user_lng],
            [safe_mid_lat, safe_mid_lng],
            [safe_exit["lat"], safe_exit["lng"]],
        ],
        "blocked_route": [
            [user_lat, user_lng],
            [danger_lat, danger_lng],
            [safe_exit["lat"], safe_exit["lng"]],
        ],
    }

"""Bounded presentation and response validation for T3 orchestration protocol 2."""
import datetime
import hashlib
import json
import re
import time

LIMIT = 30
RETENTION = 1800
BUSY = {"preparing", "starting", "queued", "running", "waiting"}
TERMINAL = {"completed", "failed", "cancelled", "interrupted", "rolled_back"}


def identifier(value):
    return isinstance(value, str) and value not in {"__proto__", "constructor", "prototype"} and bool(re.fullmatch(r"[A-Za-z0-9_:.-]{1,256}", value))


def request_identifier(value):
    # Runtime IDs embed URI-encoded provider IDs. Keep their exact bytes; they
    # are JSON data, not paths or commands, and must never be URL-decoded here.
    return (isinstance(value, str) and 0 < len(value) <= 2048
            and value not in {"__proto__", "constructor", "prototype"}
            and not re.search(r"[\x00-\x20\x7f]", value))


def text(value, limit=2048):
    return value[:limit] if isinstance(value, str) else ""


def timestamp(value):
    try:
        return datetime.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except (AttributeError, TypeError, ValueError, OverflowError):
        return 0


def select_threads(threads, now=None):
    now = time.time() if now is None else now
    result = []
    for row in threads:
        if not isinstance(row, dict) or not identifier(row.get("id")):
            continue
        if row.get("archivedAt") or row.get("settledOverride") == "settled":
            continue
        # Children and side chats are represented by their parent in T3, too.
        lineage = row.get("lineage") or {}
        if lineage.get("relationshipToParent") == "subagent" or lineage.get("sideChat") or row.get("delegatedFrom"):
            continue
        pending = row.get("pendingRuntimeRequest")
        active = row.get("status") in BUSY or row.get("activityRunStatus") in BUSY
        recent = row.get("status") in TERMINAL and timestamp(row.get("latestRunCompletedAt") or row.get("updatedAt")) > now - RETENTION
        if pending or active or recent:
            result.append(row)
    result.sort(key=lambda r: (0 if r.get("pendingRuntimeRequest") else 1 if r.get("status") in BUSY or r.get("activityRunStatus") in BUSY else 2,
                               -timestamp(r.get("updatedAt")), r["id"]))
    return result[:LIMIT]


def request_view(projection, request_id):
    """Never partially render a form and then silently answer omitted questions."""
    pending = next((r for r in projection.get("runtimeRequests", [])
                    if isinstance(r, dict) and r.get("id") == request_id and r.get("status") == "pending"), None)
    if not pending:
        return None
    item = next((i for i in projection.get("turnItems", []) if isinstance(i, dict) and i.get("requestId") == request_id
                 and i.get("type") in ("user_input_request", "approval_request")), {})
    kind = pending.get("kind", "unknown")
    result = {"id": request_id, "kind": kind, "questions": [], "canRespond": False,
              "prompt": text(item.get("prompt"), 4096), "reason": text(item.get("reason"), 2048)}
    if request_identifier(request_id) and kind == "user_input" and (pending.get("responseCapability") or {}).get("type") in ("live", "message"):
        questions = item.get("questions", [])
        valid = isinstance(questions, list) and 0 < len(questions) <= 8
        seen = set()
        for question in questions if valid else []:
            if not isinstance(question, dict):
                valid = False
                break
            qid = question.get("id")
            options = question.get("options", [])
            if (not identifier(qid) or qid in seen or not isinstance(options, list) or len(options) > 24
                    or not isinstance(question.get("question"), str) or len(question["question"]) > 8192):
                valid = False
                break
            seen.add(qid)
            choices = []
            for option in options:
                if not isinstance(option, dict):
                    valid = False
                    break
                label = option.get("label")
                value = option.get("value", label)
                if (not isinstance(label, str) or not label.strip() or len(label) > 1024
                        or not isinstance(value, str) or not value.strip() or len(value) > 2048
                        or any(choice["value"] == value for choice in choices)):
                    valid = False
                    break
                choices.append({"label": label, "value": value, "description": text(option.get("description"))})
            result["questions"].append({"id": qid, "text": question["question"], "options": choices,
                                        "multiSelect": question.get("multiSelect") is True,
                                        "allowCustomAnswer": question.get("allowCustomAnswer") is not False,
                                        "required": question.get("required") is not False})
        # Large forms belong in T3; keep the entire 30-card snapshot bounded.
        valid = valid and len(json.dumps(result)) <= 65536
        result["canRespond"] = valid
        if not valid:
            result["questions"] = []
    # Approvals and secret/auth requests stay in T3, with their full command/diff context.
    result["revision"] = hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()
    return result


def validate_answers(request, answers):
    if not request or not request["canRespond"] or not isinstance(answers, dict):
        raise ValueError("unsupported")
    questions = request["questions"]
    if any(key not in {q["id"] for q in questions} for key in answers):
        raise ValueError("invalid")
    result = {}
    for question in questions:
        value = answers.get(question["id"], [])
        if not isinstance(value, list) or len(value) > 25:
            raise ValueError("invalid")
        if any(not isinstance(v, str) or not v.strip() or len(v) > 4096 for v in value):
            raise ValueError("invalid")
        if len(set(value)) != len(value) or (not question["multiSelect"] and len(value) > 1):
            raise ValueError("invalid")
        allowed = {o["value"] for o in question["options"]}
        if not question["allowCustomAnswer"] and any(v not in allowed for v in value):
            raise ValueError("invalid")
        if not value and question["required"]:
            raise ValueError("invalid")
        if value:
            result[question["id"]] = value
    if not result:
        raise ValueError("invalid")
    return result


def project_icon(value):
    if not isinstance(value, dict):
        return None
    kind = value.get("kind")
    if kind == "lucide":
        name = value.get("name", "")
        if isinstance(name, str) and re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name) and len(name) <= 64:
            return {"kind": kind, "name": name}
    elif kind in ("emoji", "monogram"):
        key = "emoji" if kind == "emoji" else "text"
        content = value.get(key)
        if isinstance(content, str) and 0 < len(content) <= 32 and not any(ord(c) < 32 for c in content):
            return {"kind": kind, key: content}
    return None


def session_view(row, projects, request=None, project_icons=None):
    pending = row.get("pendingRuntimeRequest")
    status = row.get("activityRunStatus") or row.get("status", "idle")
    return {"id": row["id"], "title": text(row.get("title"), 256),
            "project": text(projects.get(row.get("projectId"), ""), 256),
            "projectIcon": project_icon((project_icons or {}).get(row.get("projectId"))),
            "status": status if status in BUSY | TERMINAL else "idle",
            "startedAt": timestamp(row.get("activityRunStartedAt") or row.get("latestRunStartedAt")),
            "finishedAt": 0 if status in BUSY else timestamp(row.get("latestRunCompletedAt")),
            "requestId": pending.get("id", "") if pending else "",
            "requestKind": pending.get("kind", "") if pending else "",
            "request": request,
            "summary": text((row.get("latestVisibleMessage") or {}).get("text"), 2048)}

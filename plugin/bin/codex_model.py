"""Bounded Codex v2 -> Island session model. No transcript/cache writes."""
import os
import time

MAX_TEXT = 16000


def text(value, limit=MAX_TEXT):
    return value[:limit] if isinstance(value, str) else ''


def row(thread, previous=None):
    if not isinstance(thread, dict) or not isinstance(thread.get('id'), str) or thread.get('parentThreadId'):
        return None
    source = thread.get('source')
    if (isinstance(source, dict) and 'subAgent' in source) or (isinstance(source, str) and source.startswith('subAgent')):
        return None
    previous = previous or {}
    status = thread.get('status', {}).get('type')
    state = {'active': 'running', 'systemError': 'failed', 'idle': 'idle'}.get(status, 'unloaded')
    if state == 'idle' and previous.get('status') in ('completed', 'interrupted', 'failed'):
        state = previous['status']
    result = dict(previous, id=thread['id'], title=text(thread.get('name') or thread.get('preview') or thread['id'], 200),
                  project=os.path.basename(text(thread.get('cwd'))), status=state,
                  summary=previous.get('summary', ''), startedAt=previous.get('startedAt', 0),
                  finishedAt=previous.get('finishedAt', 0), attached=previous.get('attached', False),
                  requestId=previous.get('requestId', ''), requestKind=previous.get('requestKind', ''),
                  request=previous.get('request'), turnId=previous.get('turnId', ''))
    for turn in thread.get('turns', [])[-1:]:
        apply_turn(result, turn)
        for item in turn.get('items', []):
            if item.get('type') == 'agentMessage':
                result['summary'] = text(item.get('text'))
    result['pendingHint'] = status == 'active' and bool(set(thread.get('status', {}).get('activeFlags', [])) & {'waitingOnApproval', 'waitingOnUserInput'})
    if state == 'unloaded':
        result.update(attached=False, attachState='', request=None, requestId='', requestKind='', turnId='')
    attention(result)
    return result


def attention(result):
    if result.get('request'):
        return
    result['requestId'] = 'status:' + result['id'] if result.get('pendingHint') else ''
    result['requestKind'] = 'external' if result.get('pendingHint') else ''


def apply_turn(result, turn):
    previous = result.get('turnId')
    result['turnId'] = text(turn.get('id'), 200)
    status = turn.get('status')
    result['status'] = {'inProgress': 'running', 'completed': 'completed', 'interrupted': 'interrupted', 'failed': 'failed'}.get(status, 'idle')
    if status == 'inProgress':
        result['startedAt'] = turn.get('startedAt') or (result.get('startedAt') if previous == result['turnId'] else 0) or time.time()
        result['finishedAt'] = 0
    else:
        result['startedAt'] = turn.get('startedAt') or result.get('startedAt', 0)
        result['finishedAt'] = turn.get('completedAt') or time.time()
        result['pendingHint'] = False


def question_request(key, params, writable):
    questions = params.get('questions')
    valid = isinstance(questions, list) and 0 < len(questions) <= 3
    normalized = []
    if valid:
        for q in questions:
            if not isinstance(q, dict) or q.get('isSecret') or not isinstance(q.get('id'), str) or not isinstance(q.get('question'), str) or len(q['question']) > MAX_TEXT:
                valid = False
                break
            options = q.get('options') or []
            if not isinstance(options, list) or len(options) > 12 or any(not isinstance(o, dict) or not isinstance(o.get('label'), str) or len(o['label']) > 1000 for o in options):
                valid = False
                break
            normalized.append(dict(id=q['id'], text=q['question'], required=True, multiSelect=False,
                                   allowCustomAnswer=bool(q.get('isOther')) or not options,
                                   options=[dict(label=o['label'], value=o['label'], description=text(o.get('description'), 2000)) for o in options]))
    valid = valid and len({q['id'] for q in normalized}) == len(normalized)
    return dict(id=key, revision=key, kind='user_input', canRespond=bool(valid and writable), questions=normalized if valid else [])


def validate_answers(request, answers):
    if not request.get('canRespond') or not isinstance(answers, dict):
        return False
    questions = request['questions']
    if set(answers) != {q['id'] for q in questions}:
        return False
    for q in questions:
        values = answers[q['id']]
        if not isinstance(values, list) or len(values) != 1 or not isinstance(values[0], str) or not values[0].strip() or len(values[0]) > MAX_TEXT:
            return False
        if not q['allowCustomAnswer'] and values[0] not in [o['value'] for o in q['options']]:
            return False
    return True

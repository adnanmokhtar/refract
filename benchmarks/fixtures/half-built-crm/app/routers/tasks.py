from fastapi import APIRouter, HTTPException

from ..db import execute, query
from ..schemas import TaskIn, TaskOut

router = APIRouter(prefix="/api/tasks", tags=["tasks"])


@router.get("", response_model=list[TaskOut])
def list_tasks(done: bool | None = None):
    if done is None:
        return query(
            "SELECT id, title, due_on, contact_id, deal_id, done FROM tasks ORDER BY due_on"
        )
    return query(
        "SELECT id, title, due_on, contact_id, deal_id, done FROM tasks "
        "WHERE done = ? ORDER BY due_on",
        (1 if done else 0,),
    )


@router.get("/{task_id}", response_model=TaskOut)
def get_task(task_id: int):
    rows = query(
        "SELECT id, title, due_on, contact_id, deal_id, done FROM tasks WHERE id = ?",
        (task_id,),
    )
    if not rows:
        raise HTTPException(status_code=404, detail="task_not_found")
    return rows[0]


@router.post("", response_model=TaskOut, status_code=201)
def create_task(payload: TaskIn):
    new_id = execute(
        "INSERT INTO tasks (title, due_on, contact_id, deal_id, done) VALUES (?, ?, ?, ?, 0)",
        (payload.title, payload.due_on.isoformat(), payload.contact_id, payload.deal_id),
    )
    return {"id": new_id, "done": False, **payload.model_dump()}


@router.put("/{task_id}", response_model=TaskOut)
def update_task(task_id: int, payload: TaskIn):
    existing = get_task(task_id)
    execute(
        "UPDATE tasks SET title = ?, due_on = ?, contact_id = ?, deal_id = ? WHERE id = ?",
        (payload.title, payload.due_on.isoformat(), payload.contact_id, payload.deal_id, task_id),
    )
    return {"id": task_id, "done": existing["done"], **payload.model_dump()}

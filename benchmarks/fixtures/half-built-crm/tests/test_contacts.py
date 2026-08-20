from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_and_get_contact():
    created = client.post(
        "/api/contacts",
        json={"email": "ada@example.com", "display_name": "Ada Lovelace"},
    )
    assert created.status_code == 201
    contact_id = created.json()["id"]

    fetched = client.get(f"/api/contacts/{contact_id}")
    assert fetched.status_code == 200
    assert fetched.json()["display_name"] == "Ada Lovelace"


def test_create_contact_rejects_bad_email():
    res = client.post("/api/contacts", json={"email": "nope", "display_name": "X"})
    assert res.status_code == 422


def test_update_contact():
    created = client.post(
        "/api/contacts",
        json={"email": "grace@example.com", "display_name": "Grace Hopper"},
    ).json()
    res = client.put(
        f"/api/contacts/{created['id']}",
        json={"email": "grace@example.com", "display_name": "Rear Adm. Hopper"},
    )
    assert res.status_code == 200
    assert res.json()["display_name"] == "Rear Adm. Hopper"


def test_delete_contact():
    created = client.post(
        "/api/contacts",
        json={"email": "alan@example.com", "display_name": "Alan Turing"},
    ).json()
    assert client.delete(f"/api/contacts/{created['id']}").status_code == 204
    assert client.get(f"/api/contacts/{created['id']}").status_code == 404


def test_list_contacts_search():
    res = client.get("/api/contacts", params={"q": "Hopper"})
    assert res.status_code == 200
    assert isinstance(res.json(), list)

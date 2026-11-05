"""Tests for the gallery, including regression tests for path traversal
and the Werkzeug debugger (both were exploitable before 2.0.0)."""

import pytest

import app as gallery


@pytest.fixture
def client(tmp_path, monkeypatch):
    pictures = tmp_path / "pictures"
    (pictures / "Ferien 2025").mkdir(parents=True)
    (pictures / "a.jpg").write_bytes(b"jpg")
    (pictures / "Ferien 2025" / "b c.png").write_bytes(b"png")
    (pictures / "it's.jpg").write_bytes(b"jpg")
    (pictures / "notes.txt").write_text("not an image")
    # A secret next to the picture folder that must never be served
    (tmp_path / "secret.jpg").write_text("secret")
    monkeypatch.setattr(gallery, "IMAGE_FOLDER", str(pictures))
    gallery.app.config["TESTING"] = True
    return gallery.app.test_client()


def test_index_lists_images_and_folders(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"a.jpg" in response.data
    assert b"Ferien 2025" in response.data


def test_subfolder(client):
    response = client.get("/Ferien%202025")
    assert response.status_code == 200
    assert b"b%20c.png" in response.data


def test_serves_image(client):
    response = client.get("/image/Ferien%202025/b%20c.png")
    assert response.status_code == 200
    assert response.data == b"png"


@pytest.mark.parametrize(
    "path",
    [
        "/image/..%2fsecret.jpg",
        "/image/%2e%2e/secret.jpg",
        "/image/..%2f..%2f..%2fetc%2fpasswd",
        "/image/%2fetc%2fpasswd",
    ],
)
def test_image_path_traversal_is_rejected(client, path):
    response = client.get(path)
    assert response.status_code == 404
    assert b"secret" not in response.data
    assert b"root:" not in response.data


@pytest.mark.parametrize("path", ["/..%2f", "/%2e%2e", "/..%2f..%2fetc"])
def test_folder_path_traversal_is_rejected(client, path):
    assert client.get(path).status_code == 404


def test_only_images_are_served(client):
    assert client.get("/image/notes.txt").status_code == 404


def test_debug_is_off(client):
    assert gallery.app.debug is False
    response = client.get("/image/missing.jpg")
    assert response.status_code == 404
    assert b"Werkzeug Debugger" not in response.data


def test_quote_in_filename_does_not_break_out_of_javascript(client):
    html = client.get("/").data.decode()
    # The file name is only used URL-encoded in attributes, never inside an
    # inline JavaScript string
    assert 'data-src="/image/it%27s.jpg"' in html
    assert "openLightbox('" not in html

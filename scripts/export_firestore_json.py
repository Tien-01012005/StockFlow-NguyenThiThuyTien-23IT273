import json
import re
import sys
from pathlib import Path
import requests

ROOT = Path(__file__).resolve().parent.parent
FIREBASE_OPTIONS = ROOT / "lib" / "firebase_options.dart"
EXPORT_PATH = ROOT / "database" / "products.json"


def read_web_firebase_config():
    text = FIREBASE_OPTIONS.read_text(encoding="utf-8")
    web_block = text.split("static const FirebaseOptions web")[1].split(");")[0]
    api_key = re.search(r"apiKey:\s*'([^']+)'", web_block).group(1)
    project_id = re.search(r"projectId:\s*'([^']+)'", web_block).group(1)
    return api_key, project_id


def sign_in(api_key: str, email: str, password: str) -> str:
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}"
    resp = requests.post(
        url,
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()["idToken"]


def decode_firestore_value(val: dict):
    if "stringValue" in val:
        return val["stringValue"]
    if "integerValue" in val:
        return int(val["integerValue"])
    if "doubleValue" in val:
        num = float(val["doubleValue"])
        return int(num) if num.is_integer() else num
    return None


def main():
    email = sys.argv[1] if len(sys.argv) > 1 else "admin@stockflow.vn"
    password = sys.argv[2] if len(sys.argv) > 2 else "Admin@23IT273"

    api_key, project_id = read_web_firebase_config()
    token = sign_in(api_key, email, password)
    headers = {"Authorization": f"Bearer {token}"}

    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/products?pageSize=200"
    docs = []
    next_page = None
    while True:
        req_url = url if not next_page else f"{url}&pageToken={next_page}"
        resp = requests.get(req_url, headers=headers, timeout=20)
        resp.raise_for_status()
        data = resp.json()
        docs.extend(data.get("documents", []))
        next_page = data.get("nextPageToken")
        if not next_page:
            break

    exported = {}
    for doc in docs:
        doc_id = doc["name"].rsplit("/", 1)[-1]
        fields = doc.get("fields", {})
        exported[doc_id] = {
            "name": decode_firestore_value(fields.get("name", {})),
            "price": decode_firestore_value(fields.get("price", {})),
            "soluong": decode_firestore_value(fields.get("soluong", {})),
            "image": decode_firestore_value(fields.get("image", {})),
        }

    EXPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    EXPORT_PATH.write_text(
        json.dumps({"products": exported}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Exported {len(exported)} documents to {EXPORT_PATH}")


if __name__ == "__main__":
    main()

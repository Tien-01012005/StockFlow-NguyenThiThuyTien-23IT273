import json
import re
import sys
from pathlib import Path
import requests

ROOT = Path(__file__).resolve().parent.parent
FIREBASE_OPTIONS = ROOT / "lib" / "firebase_options.dart"

SAMPLE_PRODUCTS = [
    {
        "name": "MacBook Air M3 13 inch 256GB",
        "price": 26990000,
        "soluong": 12,
        "image": "https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=800&q=80",
    },
    {
        "name": "Bàn phím cơ Keychron K2 Pro",
        "price": 2350000,
        "soluong": 25,
        "image": "https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=800&q=80",
    },
    {
        "name": "Chuột không dây Logitech MX Master 3S",
        "price": 2490000,
        "soluong": 4,
        "image": "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?auto=format&fit=crop&w=800&q=80",
    },
    {
        "name": "Tai nghe Sony WH-1000XM5",
        "price": 6490000,
        "soluong": 9,
        "image": "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=800&q=80",
    },
    {
        "name": "Màn hình Dell UltraSharp 27 inch 4K",
        "price": 12900000,
        "soluong": 3,
        "image": "https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?auto=format&fit=crop&w=800&q=80",
    },
    {
        "name": "Đồng hồ thông minh Apple Watch Series 10",
        "price": 10490000,
        "soluong": 0,
        "image": "https://images.unsplash.com/photo-1546868871-7041f2a55e12?auto=format&fit=crop&w=800&q=80",
    },
]


def read_web_firebase_config():
    text = FIREBASE_OPTIONS.read_text(encoding="utf-8")
    web_block = text.split("static const FirebaseOptions web")[1].split(");")[0]
    api_key = re.search(r"apiKey:\s*'([^']+)'", web_block).group(1)
    project_id = re.search(r"projectId:\s*'([^']+)'", web_block).group(1)
    return api_key, project_id


def authenticate_admin(api_key: str, email: str, password: str) -> str:
    sign_in_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}"
    resp = requests.post(
        sign_in_url,
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=20,
    )
    if resp.status_code == 200:
        return resp.json()["idToken"]

    sign_up_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key}"
    resp2 = requests.post(
        sign_up_url,
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=20,
    )
    if resp2.status_code == 200:
        print(f"Created admin user: {email}")
        return resp2.json()["idToken"]

    raise RuntimeError(f"Auth failed: {resp.text} | {resp2.text}")


def main():
    email = sys.argv[1] if len(sys.argv) > 1 else "admin@stockflow.vn"
    password = sys.argv[2] if len(sys.argv) > 2 else "Admin@23IT273"

    api_key, project_id = read_web_firebase_config()
    if api_key == "PLACEHOLDER":
        raise RuntimeError("Run flutterfire configure first.")

    token = authenticate_admin(api_key, email, password)
    headers = {"Authorization": f"Bearer {token}"}
    base_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/products"

    existing = requests.get(base_url, headers=headers, timeout=20).json()
    existing_names = {
        doc["fields"]["name"]["stringValue"]
        for doc in existing.get("documents", [])
        if "fields" in doc and "name" in doc["fields"]
    }

    inserted = 0
    for item in SAMPLE_PRODUCTS:
        if item["name"] in existing_names:
            continue
        payload = {
            "fields": {
                "name": {"stringValue": item["name"]},
                "price": {"doubleValue": float(item["price"])},
                "soluong": {"integerValue": str(item["soluong"])},
                "image": {"stringValue": item["image"]},
            }
        }
        r = requests.post(base_url, headers=headers, json=payload, timeout=20)
        if r.status_code not in (200, 201):
            raise RuntimeError(f"Failed adding {item['name']}: {r.status_code} {r.text}")
        inserted += 1
        print(f"Added: {item['name']}")

    print(f"Done. Inserted {inserted} new products into project '{project_id}'.")


if __name__ == "__main__":
    main()

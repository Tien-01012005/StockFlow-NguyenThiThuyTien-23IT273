# StockFlow Admin - Quản lý sản phẩm đa nền tảng (Flutter & Firebase)

- **Sinh viên thực hiện:** Nguyễn Thị Thủy Tiên
- **Mã sinh viên:** 23IT273
- **Môn học:** Lập trình đa nền tảng
- **Công nghệ:** Flutter (Web + Android), Cloud Firestore, Firebase Authentication, Firebase Hosting

## Cấu trúc dữ liệu Firestore (Chuẩn 4 trường)

Collection `products` chỉ lưu đúng 4 trường theo yêu cầu đề bài:

- `name` (`String`): Tên sản phẩm
- `price` (`num`): Giá sản phẩm (VNĐ)
- `soluong` (`int`): Số lượng tồn kho
- `image` (`String`): URL hình ảnh hoặc chuỗi Base64 nén từ ảnh chụp/thư viện

## Chạy ứng dụng

```bash
flutter pub get
flutter run -d chrome
flutter run -d android
```

## Xuất cơ sở dữ liệu Firestore ra JSON

```bash
python scripts/export_firestore_json.py
```

Kết quả được lưu tại `database/products.json`.

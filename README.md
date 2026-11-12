# Mochy-Music iOS 🎵

Bản tái sinh 90% vẻ đẹp và tính năng của **Mochy-Music** (Android) dành riêng cho hệ điều hành iOS, được viết hoàn toàn bằng **Swift & SwiftUI** kết hợp cùng `AVFoundation` và kiến trúc tự động hóa GitHub Actions.

## ✨ Điểm Nổi Bật
- **Giao diện thuần SwiftUI**: Dynamic Mesh Blur theo bìa album, Dark/Amoled theme cực kỳ nịnh mắt.
- **Nguồn nhạc phong phú**: Kết nối trực tiếp vào dịch vụ YouTube Music (InnerTube) để tìm kiếm và stream nhạc chất lượng cao mà không cần tài khoản hay API key trả phí.
- **Lời bài hát đồng bộ (Synced Lyrics)**: Tự động tìm và cuộn mượt mà theo thời gian thực (LRC format) lấy từ LRCLib.
- **Tích hợp iOS sâu**:
  - Hỗ trợ phát nhạc nền (`UIBackgroundModes: audio`).
  - Hiển thị metadata, bìa bài hát và thanh trượt trên Màn hình khóa (Lock Screen), Trung tâm điều khiển (Control Center) và Dynamic Island.
- **Tự động đóng gói `.ipa` (CI/CD)**: Tích hợp sẵn workflow GitHub Actions. Chỉ cần đẩy code lên GitHub, máy ảo macOS sẽ tự động biên dịch và nhả ra file `.ipa` Unsigned để cài qua AltStore / Sideloadly / TrollStore.

---

## 🚀 Cách Đưa Lên GitHub & Tải Về File IPA

### Bước 1: Khởi tạo Git Repo & Push lên GitHub
Mở Terminal / PowerShell tại thư mục `Mochy-iOS`:
```bash
git init
git add .
git commit -m "Initial commit: Mochy-Music iOS core"
git branch -M main
git remote add origin https://github.com/<tai-khoan-github-cua-anh>/Mochy-iOS.git
git push -u origin main
```

### Bước 2: Tải file IPA từ GitHub Actions
1. Truy cập vào GitHub repo của anh trên trình duyệt.
2. Bấm vào tab **Actions**.
3. Chọn workflow **Build Mochy iOS (Unsigned IPA)** đang chạy (hoặc bấm **Run workflow**).
4. Khi quá trình build kết thúc (tầm 2-3 phút), cuộn xuống mục **Artifacts** và bấm tải về file **`MochyMusic-Unsigned-IPA`** (giải nén sẽ có file `MochyMusic.ipa`).

### Bước 3: Cài vào iPhone
- Dùng **AltStore**, **Sideloadly** trên máy tính hoặc **TrollStore** (nếu máy hỗ trợ) để cài file `MochyMusic.ipa` vào iPhone của anh.

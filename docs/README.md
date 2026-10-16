# Tài liệu

Tài liệu gồm sơ đồ kiến trúc, hướng dẫn tìm hiểu cấu hình, quy trình luyện cài đặt trong máy ảo và ghi chú riêng cho laptop của tác giả.

## Chọn hướng dẫn

| Nhu cầu | Tài liệu |
|---|---|
| Hiểu tổng thể module, service, workflow và dữ liệu | [Hướng dẫn hệ thống](system-guide.md) |
| Hiểu luồng module và desktop | [Sơ đồ kiến trúc](architecture.md) |
| Tìm hiểu repo và cách bắt đầu | [README chính](../README.md) |
| Luyện cài NixOS trong môi trường riêng | [Cài đặt bằng QEMU/KVM](06-Luyen-Tap-VM.md) |
| Cài lại laptop của tác giả | [Ghi chú cài laptop cá nhân](personal/cai-laptop.md) |

## Lưu ý

Ghi chú laptop cá nhân gắn với phần cứng, tên người dùng và bố cục đĩa cụ thể; không áp dụng nguyên xi cho máy khác. Khi luyện tập, hãy dùng hướng dẫn QEMU và bản clone tạm theo các bước trong tài liệu đó.

Sau khi cấu hình thay đổi, áp dụng trên máy đã cài NixOS bằng:

```bash
sudo nixos-rebuild switch --flake .#laptop
```

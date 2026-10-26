# Hướng dẫn hệ thống

> Tài liệu này giải thích cách cấu hình được lắp ghép và chạy trên máy. Repo hiện mô tả một máy NixOS laptop, kiến trúc x86_64-linux, một tài khoản người dùng. Cấu hình phần cứng, tên user và một số đường dẫn còn gắn với máy hiện tại; cần rà soát trước khi dùng cho máy khác.

## 1. Bản đồ tổng thể

flake.nix ghim các đầu vào bằng flake.lock và khai báo cấu hình nixosConfigurations.laptop. Host kết hợp module hệ thống NixOS với một cấu hình Home Manager cho user:

~~~text
flake.nix + flake.lock
└── hosts/laptop/default.nix
    ├── hosts/laptop/hardware-configuration.nix
    ├── modules/nixos/*.nix       Cấu hình hệ điều hành và dịch vụ hệ thống
    └── Home Manager user
        └── home/default.nix
            ├── shell/            Bash và công cụ dòng lệnh
            ├── programs/         Cấu hình ứng dụng
            ├── desktop/          Sway và tích hợp desktop
            ├── features/         Workflow có script hoặc dịch vụ riêng
            └── scripts/          Lệnh người dùng theo nhóm chức năng
~~~

Luồng đăng nhập và khởi chạy desktop:

~~~text
UEFI / systemd-boot → NixOS / Plymouth → greetd / tuigreet → Sway
                                                   └── sway-session.target
                                                       ├── Waybar, swayidle, swayrd
                                                       ├── Fcitx5, swaybg
                                                       └── service của các workflow
~~~

NixOS quản lý kernel, driver, user, mạng và dịch vụ cấp máy. Home Manager quản lý môi trường của user: package, cấu hình ứng dụng, script và user service. Cấu hình được tạo trong Nix store rồi liên kết vào profile; dữ liệu cần thay đổi khi sử dụng như wallpaper, lịch sử timer và cache được lưu ngoài repo.

## 2. Flake, host và phiên bản

- [flake.nix](../flake.nix) chọn x86_64-linux, xuất cấu hình laptop và formatter nix fmt.
- [flake.lock](../flake.lock) ghi chính xác revision của Nixpkgs và Home Manager để lần dựng sau dùng cùng đầu vào.
- Home Manager theo cùng đầu vào Nixpkgs với NixOS. Gói bộ gõ Lotus được tự đóng gói từ GitHub tại [fcitx5-lotus.nix](../pkgs/fcitx5-lotus.nix); phiên bản hiện ghim là v6.0.0.
- system.stateVersion và home.stateVersion hiện là 26.05. Đây là mốc tương thích của cấu hình đã cài, không phải phiên bản Nixpkgs đang chạy. Không tăng giá trị này chỉ để cập nhật package.
- [hosts/laptop/hardware-configuration.nix](../hosts/laptop/hardware-configuration.nix) được sinh từ phần cứng và filesystem của máy cài đặt. Khi cài máy khác, phải tạo lại file này và kiểm tra UUID, mount point, swap.

## 3. Module NixOS

Host import rõ các module trong [hosts/laptop/default.nix](../hosts/laptop/default.nix):

| File | Trách nhiệm |
|---|---|
| [core.nix](../modules/nixos/core.nix) | Nix flakes, garbage collection, bootloader, Plymouth, locale, mạng, user chính và công cụ nền tảng. Cũng khai báo đường dẫn flake mặc định cho nh. |
| [desktop.nix](../modules/nixos/desktop.nix) | Sway, greetd/tuigreet, giao diện Catppuccin, PipeWire, Bluetooth, portal Wayland, đồ họa, Thunar và font hệ thống. |
| [input-method.nix](../modules/nixos/input-method.nix) | Fcitx5, Lotus, biến môi trường nhập liệu và user service chạy Fcitx5 trong phiên Sway. |
| [laptop.nix](../modules/nixos/laptop.nix) | Driver Intel sớm, zram, resume từ swap có nhãn swap, chế độ ngủ sâu, keyd, fwupd và ngưỡng sạc pin 85–90%. |
| [development.nix](../modules/nixos/development.nix) | Bật Podman. |
| [virtualisation.nix](../modules/nixos/virtualisation.nix) | Libvirt, virt-manager và quyền nhóm kvm/libvirtd. |
| [system-tweaks.nix](../modules/nixos/system-tweaks.nix) | earlyoom, TRIM hàng tuần và nix-ld cho một số binary dựng sẵn. |

Home Manager được cấu hình từ host, dùng chung bộ package Nixpkgs của hệ thống. extraSpecialArgs chuyển inputs và userName vào các module user. Tài khoản hiện tại được đặt trong flake.nix; một số cấu hình cá nhân cũng dùng đường dẫn /home/doxuantuyen, nên cần cập nhật đồng bộ khi đổi user.

## 4. Cấu hình Home Manager

home/default.nix là điểm vào của cấu hình user. Các mục import tương ứng với nhóm trách nhiệm:

| Thư mục/file | Nội dung |
|---|---|
| [home/packages.nix](../home/packages.nix) | Package ứng dụng và công cụ user. Package nội bộ swayview được tách ở [pkgs/swayview.nix](../pkgs/swayview.nix) và hiện chỉ hỗ trợ x86_64-linux. |
| home/xdg.nix | Bật XDG user directories và tạo các thư mục chuẩn như Documents, Downloads, Pictures. |
| home/shell/ | Bash, alias nswitch, hàm nt mở terminal tại thư mục hiện tại, hàm y mở Yazi, direnv, zoxide và fzf. Có thêm [reset-generations.sh](../home/shell/scripts/reset-generations.sh), script bảo trì phải chạy thủ công; script xóa các generation cũ và thu gom Nix store nên sẽ mất khả năng rollback về các generation đã xóa. |
| home/programs/ | Cấu hình Foot, Git, Neovim và Starship. |
| home/desktop/ | Sway, Waybar, Mako, Rofi, GTK, Fcitx5 profile, MIME mặc định và tích hợp Thunar. |
| home/features/ | Countdown, Sioyek, wallpaper và Yazi; mỗi feature gom module và phần triển khai liên quan. |
| home/scripts/ | Lệnh desktop, media, session, system và utilities. Các default.nix trong nhóm chỉ tập hợp module con. |

Trong một tính năng, file .nix thường khai báo package/path, cấu hình Home Manager hoặc systemd service; phần Bash/Python dài được để trong file .sh/.py cùng thư mục để dễ đọc và chỉnh bằng editor phù hợp.

## 5. Phiên Sway và các service

greetd mở tuigreet, sau đó chạy Sway. Khi khởi động, Sway đưa WAYLAND_DISPLAY, SWAYSOCK và biến nhập liệu vào môi trường D-Bus/systemd rồi khởi chạy sway-session.target. Các user service gắn với target này sẽ dừng theo phiên desktop.

| Service | Khai báo | Vai trò |
|---|---|---|
| swayidle | [sway.nix](../home/desktop/sway.nix) | Sau 300 giây idle thì khóa màn hình; 310 giây tắt màn hình; 900 giây gọi idle-suspend. Khi có hoạt động, bật màn hình lại. |
| swayrd | [sway.nix](../home/desktop/sway.nix) | Ghi lịch sử focus cho chuyển cửa sổ theo thứ tự dùng gần đây. |
| swaybg | [wallpaper/module.nix](../home/features/wallpaper/module.nix) | Hiển thị một ảnh nền cố định trong phiên Sway; không có menu hoặc thao tác đổi ảnh. |
| sway-waybar-window-events | [window-management.nix](../home/scripts/desktop/window-management.nix) | Nghe sự kiện cửa sổ/workspace từ Sway và gửi tín hiệu để Waybar cập nhật danh sách cửa sổ đang ở workspace khác hoặc scratchpad. |
| countdown-sleep-watch | [countdown/services.nix](../home/features/countdown/services.nix) | Nghe PrepareForSleep qua system bus, tạm dừng timer khi máy ngủ và thông báo khi máy thức. |
| countdown-lock-on-sleep | [countdown/services.nix](../home/features/countdown/services.nix) | Một swayidle riêng thực hiện khóa trước khi suspend; vẫn hoạt động khi Countdown tạm dừng service idle chính. |
| fcitx5-daemon | [input-method.nix](../modules/nixos/input-method.nix) | Chạy Fcitx5 trong phiên Sway với đường dẫn addon rõ ràng. |
| trash-clean.timer | [trash-clean.nix](../home/scripts/utilities/trash-clean.nix) | Mỗi ngày lúc 03:00 xóa file trong thùng rác cũ hơn 30 ngày; timer persistent nên có thể chạy bù sau khi máy tắt. |

### Idle, nguồn điện và Countdown

Sau 900 giây idle, idle-suspend chỉ suspend nếu có pin báo `Discharging`. Khi cắm điện hoặc không có pin, máy tiếp tục idle với màn hình tắt; nếu rút sạc khi vẫn idle, máy không suspend cho đến chu kỳ idle tiếp theo. Không có watcher pin chạy nền.

Countdown có thể tự ngăn swayidle để phiên tập trung không bị tắt màn hình/suspend do idle. Nút inhibit thủ công dùng cùng cơ chế. Dịch vụ khóa trước sleep tách riêng để máy vẫn khóa khi lid hoặc thao tác khác yêu cầu sleep. Timer lưu thời gian còn lại, pause khi nhận sự kiện ngủ và giữ trạng thái pause sau khi thức; người dùng chủ động tiếp tục lại.

## 6. Các workflow chính

| Workflow | Điểm ghép cấu hình | Phần triển khai và hành vi |
|---|---|---|
| Countdown | [countdown/default.nix](../home/features/countdown/default.nix), [waybar.nix](../home/desktop/waybar.nix) | countdown-menu.sh điều khiển menu; countdown-engine.sh quản lý timer, lịch sử và idle inhibit; countdown-sleep-watch.sh xử lý sự kiện ngủ. Hỗ trợ di trú state cũ tên study/pomodoro. |
| Quản lý cửa sổ | [window-management.nix](../home/scripts/desktop/window-management.nix), [waybar.nix](../home/desktop/waybar.nix) | window-menu.py liệt kê cửa sổ thường, scratchpad và cửa sổ ở workspace khác; sway-window-events.py duy trì thứ tự focus và làm mới Waybar theo sự kiện thay vì polling. |
| Wallpaper | [wallpaper/default.nix](../home/features/wallpaper/default.nix), [wallpaper/module.nix](../home/features/wallpaper/module.nix) | swaybg hiển thị ảnh Gruvbox cố định từ `home/assets/wallpapers/` trong phiên Sway. Không cài công cụ đổi nền, menu, thumbnail hay thư mục ảnh ngoài repo. |
| Yazi | [yazi/default.nix](../home/features/yazi/default.nix), [bash.nix](../home/shell/bash.nix) | Flavor Gruvbox Dark upstream được ghim revision bằng Nix; mục Yazi trong Rofi mở popup, Bash function `y` đổi về thư mục cuối cùng sau khi thoát. |
| Sioyek | [sioyek/default.nix](../home/features/sioyek/default.nix), [mimeapps.nix](../home/desktop/mimeapps.nix) | Wrapper sioyek-open đưa PDF về cửa sổ đang mở nếu nhận diện được duy nhất một tài liệu khớp; MIME PDF mặc định mở bằng Sioyek. |
| Session/power | home/scripts/session/, home/scripts/system/, home/scripts/utilities/ | lock-screen và idle-suspend quản lý session idle; refresh-session nạp lại cấu hình Sway; power-profile-menu chọn profile; vm-nixos chạy máy ảo; daily-menu và dict-toggle mở tiện ích; trash-clean dọn thùng rác. |
| Desktop/media | home/scripts/desktop/, home/scripts/media/ | scratchpad-terminal bật terminal ẩn; screenshot và screenshot-menu chụp màn hình; toggle-touchpad đổi trạng thái touchpad; wlsunset-menu/wlsunset-apply chọn ánh sáng màn hình; media-notify điều khiển âm lượng và độ sáng, cập nhật thông báo. |
| Ngôn ngữ | home/scripts/utilities/quick-lang.nix | Dịch hoặc sửa văn bản qua menu; khóa API nếu cần được đọc từ ~/.config/quick-lang/api.key, không lưu trong repo. |

Một số dữ liệu đầu vào và kết quả nằm trong thư mục user, ví dụ ảnh chụp ở ~/Pictures/Screenshots và VM luyện tập ở ~/VMs. Wallpaper cấu hình được quản lý trong repo và đưa vào Nix store.

## 7. Dữ liệu, trạng thái và cache

| Đường dẫn | Mục đích | Lưu ý |
|---|---|---|
| XDG_RUNTIME_DIR/countdown-state; nếu biến này không có thì ~/.local/state/countdown-state | Trạng thái timer đang chạy/tạm dừng; trên phiên Linux thông thường XDG_RUNTIME_DIR nằm dưới /run/user/$UID. | Xóa sẽ làm mất phiên timer hiện tại. Runtime state thường mất sau reboot. |
| XDG_STATE_HOME/countdown-state.lock; mặc định ~/.local/state/countdown-state.lock | Khóa đồng bộ giữa menu, Waybar và daemon khi thay đổi trạng thái timer. | Không xóa file khi Countdown đang chạy. |
| XDG_RUNTIME_DIR/countdown-sleep-paused và XDG_RUNTIME_DIR/inhibit-manual | Marker runtime cho việc pause do sleep và inhibit thủ công. | Runtime marker có thể mất sau reboot; có thể bỏ khi không có phiên đang chạy. |
| XDG_STATE_HOME/countdown-history.log; mặc định ~/.local/state/countdown-history.log | Lịch sử các phiên Countdown. | Dữ liệu lưu qua reboot. |
| XDG_STATE_HOME/countdown-sleep-watch.log; mặc định ~/.local/state/countdown-sleep-watch.log | Nhật ký watcher sleep/wake. | Có thể xóa để dọn log cũ. |
| ~/.local/state/wlsunset-mode | Chế độ ánh sáng màn hình được chọn lần cuối. | Xóa thì lần chạy tiếp theo dùng mặc định natural. |
| /run/user/$UID/sway-window-focus-mru.json | Thứ tự focus gần đây, gắn với socket Sway; runtime và có thể tái tạo. | Có thể xóa khi đóng Sway. |
| XDG_CACHE_HOME/window-menu/index.json; mặc định ~/.cache/window-menu/index.json | Cache tên ứng dụng/icon của menu cửa sổ. | Có thể xóa; sẽ được tạo lại. |
| ~/.config/quick-lang/api.key | API key riêng của người dùng nếu tính năng dịch cần đến. | Không đưa nội dung file này lên Git. |
| ~/Pictures/Screenshots | Screenshot tạo ra. | Đây là dữ liệu cá nhân; tự sao lưu nếu cần. |
| ~/.local/share/Trash/ | Thùng rác GIO; các mục cũ hơn 30 ngày bị timer dọn. | Kiểm tra trước khi khôi phục file cũ. |

Nix store và Home Manager profile chứa cấu hình/package bất biến. Không sửa file trong store trực tiếp; thay đổi source trong repo rồi áp dụng cấu hình. Các file trạng thái do chương trình tạo khi chạy không cần khai báo trong Git.

## 8. Lần theo hoặc mở rộng cấu hình

Khi tìm một hành vi, đi theo đường từ nơi kích hoạt đến phần thực thi:

1. Tìm entry ở home/desktop/, home/features/ hoặc systemd service.
2. Tìm tên command trong .nix của nhóm script/feature.
3. Nếu Nix chỉ cài một script, đọc phần .sh/.py cùng thư mục hoặc nội dung text của module.
4. Nếu hành vi phụ thuộc service, đọc systemd.* và xem service đó được gắn với sway-session.target hay system target nào.

Ví dụ: Waybar gọi countdown-engine status; command được cài bởi home/features/countdown/engine.nix; logic nằm trong countdown-engine.sh; service và sự kiện sleep được khai báo ở services.nix.

Khi thêm cấu hình:

- Thiết lập cho kernel, user hệ thống, mạng hoặc dịch vụ toàn máy: thêm vào module modules/nixos/ phù hợp rồi import từ hosts/laptop/default.nix.
- Thiết lập ứng dụng hoặc tiện ích của user: đặt trong nhóm tương ứng dưới home/.
- Feature có nhiều phần: tạo thư mục feature, thêm các module vào default.nix, để logic script dài trong .sh/.py, và khai báo dependency/service trong .nix.
- Tài liệu và asset tĩnh được đặt trong docs/ và home/assets/; dữ liệu cá nhân có thể thay đổi khi chạy để ngoài repo.

## 9. Áp dụng, định dạng và kiểm tra

Trên máy đang dùng cấu hình này:

~~~bash
sudo nixos-rebuild switch --flake .#laptop
~~~

Alias Bash nswitch chuyển vào ~/nix-config và rebuild target theo hostname. nh os switch cũng được cấu hình trỏ đến thư mục repo này.

Định dạng Nix:

~~~bash
nix fmt
~~~

Có thể kiểm tra định dạng và đánh giá các flake output mà không build closure:

~~~bash
nix fmt -- --check
nix flake check --no-build
~~~

Repo có .githooks/pre-push. Hook tạo snapshot của commit sắp push, chạy hai lệnh kiểm tra trên và từ chối push nếu thất bại. Cấu hình hook path thuộc từng bản clone Git; để bật hook trong clone hiện tại:

~~~bash
git config core.hooksPath .githooks
~~~

Hook chỉ format-check và đánh giá cấu hình, không thay cho việc thử các hành vi trên desktop. Khi cập nhật đầu vào, xem xét diff flake.lock cùng thay đổi package/module.

## 10. Chẩn đoán nhanh

| Tình huống | Kiểm tra |
|---|---|
| Flake không đánh giá được | Chạy nix flake check --no-build; đọc lỗi đầu tiên và đường dẫn module liên quan. |
| Không vào được Sway | Xem journalctl -b -u greetd; sau khi đăng nhập, xem systemctl --user --failed. |
| User service không chạy | Dùng systemctl --user status tên-service và journalctl --user -b -u tên-service. Ví dụ: swayidle, swaybg, countdown-sleep-watch. |
| Countdown không cập nhật | Kiểm tra countdown-engine status, service countdown-sleep-watch và ~/.local/state/countdown-sleep-watch.log. |
| Hibernate không tiếp tục từ swap | So sánh swap đang bật bằng swapon --show với nhãn swap trong lsblk -f; kiểm tra /sys/power/mem_sleep. |
| Fcitx không xuất hiện trong desktop | Kiểm tra fcitx5-daemon, profile home/desktop/fcitx5.nix và biến QT_IM_MODULE/XMODIFIERS. |
| Waybar không thấy cửa sổ ở workspace khác | Kiểm tra service sway-waybar-window-events, SWAYSOCK trong môi trường systemd user và log service. |

## Tài liệu liên quan

- [Sơ đồ kiến trúc](architecture.md) — bản đồ import và các luồng desktop chính.
- [Luyện cài bằng QEMU/KVM](06-Luyen-Tap-VM.md) — thực hành trên đĩa ảo.
- [Ghi chú cài laptop cá nhân](personal/cai-laptop.md) — quy trình riêng cho phần cứng hiện tại.

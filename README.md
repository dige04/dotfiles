# dotfiles

Dotfiles và toàn bộ setup cho máy Mac của Hiếu, chạy bằng
[`mise bootstrap`](https://mise.jdx.dev/bootstrap.html), theo kiểu của
[samhvw8/dotfiles](https://github.com/samhvw8/dotfiles). Chỉ một lệnh là cài xong
app, brew package, CLI/runtime, dotfile và chỉnh luôn macOS.

> Nhánh `master` là bản chezmoi cũ, giữ lại cho MacBook đang dùng. Nhánh `main` là bản mise này.

## Cài trên máy mới

Mở Terminal, dán:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/dige04/dotfiles/main/setup.sh)"
```

Script sẽ hỏi mật khẩu máy một lần, rồi hỏi git name/email (Enter để giữ mặc định).
Lần đầu chạy mất khoảng 15–40 phút, tuỳ mạng. Xong thì mở terminal mới.

`setup.sh` làm lần lượt:

1. Cài Xcode Command Line Tools (có git).
2. Cài mise vào `~/.local/bin`.
3. Clone repo này vào `~/.dotfiles`.
4. Lưu git name/email vào `~/.config/mise/config.local.toml` (không commit).
5. Link `~/.config/mise/config.toml` → `~/.dotfiles/mise/config.toml`.
6. Copy mọi file sắp bị thay vào `~/.dotfiles-backup-<thời gian>/`.
7. Chạy `mise bootstrap`: brew formula + cask app → link dotfile → macOS defaults → tool trong `[tools]`.

Chạy lại bao nhiêu lần cũng được, bước nào xong rồi thì tự bỏ qua.

## Sau khi cài xong (làm tay)

- `gh auth login`, rồi tạo SSH key nếu cần (`ssh-keygen -t ed25519`, thêm vào GitHub).
- Đăng nhập các app: Claude, ChatGPT, Chrome, Telegram, Zalo, Tailscale, Cloudflare WARP…
- Karabiner-Elements: mở app, cấp quyền Input Monitoring / Driver Extension theo hướng dẫn.
- VS Code: bật Settings Sync (settings có mật khẩu DB local nên không đưa lên repo public).
- Muốn có lệnh `brew` (để `brew services`, cài từ tap ngoài): cài Homebrew theo
  [brew.sh](https://brew.sh). Nó dùng chung `/opt/homebrew` với những gì mise đã cài.
  Sau đó:
  ```bash
  brew install --cask datlechin/tap/pitboard-app
  brew install greptileai/tap/greptile
  ```

## Cấu trúc

| Đường dẫn | Dùng để |
|---|---|
| `setup.sh` | Script cài máy mới |
| `mise/config.toml` | Mọi thứ: `[tools]`, `[dotfiles]`, `[bootstrap.packages]` (brew/cask), macOS defaults, hooks, tasks |
| `mise/snippets/git-identity.tera` | Khối `[user]` trong `~/.gitconfig`, lấy từ `config.local.toml` |
| `mise/scripts/` | Hook chuẩn bị máy (thư mục, Rosetta) và script `dot:save` |
| `home/` | Dotfile, link vào đúng đường dẫn đó dưới `~` |

Dotfile được **symlink**, nên sửa `~/.zshrc` là sửa thẳng file trong `~/.dotfiles`.

## Dùng hằng ngày

```bash
mise run dot:status   # dotfile nào chưa link, file nào trong repo chưa commit
mise run dot:save     # commit + push mọi thay đổi trong ~/.dotfiles
mise run dot:update   # máy khác: pull bản mới nhất rồi chạy lại mise bootstrap
mise run dot:up       # nâng cấp mise, mọi tool mise và brew package
mise run dot:cd       # mở shell trong ~/.dotfiles
```

Thêm thứ mới:

- CLI / runtime: thêm dòng vào `[tools]` trong `mise/config.toml`, rồi `mise install`.
- App / brew package: thêm dòng `"brew-cask:<tên>"` hoặc `"brew:<tên>"` vào
  `[bootstrap.packages]`, rồi `mise bootstrap packages apply`.
- Dotfile mới: chép vào `home/…`, thêm một dòng trong `[dotfiles]`, rồi `mise dot apply`.
- Giá trị riêng từng máy: `~/.zshrc.local` (zsh) hoặc `~/.config/mise/config.local.toml` (mise). Cả hai không commit.

Rồi `mise run dot:save`.

## Gỡ / quay lại

File gốc trước lần cài đầu nằm trong `~/.dotfiles-backup-*`: xoá symlink rồi chép file cũ về là xong.

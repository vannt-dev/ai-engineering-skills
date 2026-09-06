# Handoff triển khai multi-agent skills v0.2.0 (Archived)

> **Trạng thái: đã hoàn tất và archived.** Tài liệu này là note bàn giao gốc, giữ lại để tham khảo lịch sử thiết kế. Toàn bộ hạng mục "chưa hoàn tất" liệt kê bên dưới đã được triển khai và commit vào `main` (`991c416`, 2026-09-06). Xem `CHANGELOG.md` cho trạng thái hiện hành.

Ngày ghi nhận: 2026-09-05

## Trạng thái source chính

- Source: `F:\ai-agent\ai-engineering-skills`
- Branch: `main`
- Baseline commit: `d2d49d6 feat: add cross-language engineering skill set`
- Các thay đổi kỹ thuật v0.2.0 chưa được áp dụng vào source chính.
- File note này là thay đổi duy nhất dự kiến được thêm vào source chính trong lần tạm dừng này.

## Draft đang thực hiện

Draft tạm thời đang nằm tại:

```text
F:\prod\logios-apis\.multi-agent-staging
```

Không xem draft này là source of truth và không commit nó trong repository `logios-apis`.

Các phần đã draft:

- README cho Codex, Claude Code, OpenCode và Google Antigravity.
- `skillset.json` schema version 2, collection version `0.2.0`.
- Workflow skill mới `implement-change`.
- Codex plugin manifest tại `.codex-plugin/plugin.json`.
- Claude plugin manifest tại `.claude-plugin/plugin.json`.
- GitHub Actions matrix cho Windows và Linux.
- `.gitattributes` chuẩn hóa line ending.

Các phần chưa hoàn tất:

- Viết lại `scripts/install-skills.ps1`.
- Viết lại `scripts/validate-skills.ps1`.
- Thêm `scripts/test-tooling.ps1`.
- Chạy validator, parser checks và functional installer tests.
- Review diff cuối cùng.
- Đồng bộ draft vào source chính.
- Commit và push; cần yêu cầu riêng trước khi publish.

## Kết quả đã xác minh

### Đường dẫn skill chính thức

| Product | User scope | Project/workspace scope |
| --- | --- | --- |
| Codex | `~/.agents/skills` | `<repo>/.agents/skills` |
| Claude Code | `~/.claude/skills` | `<repo>/.claude/skills` |
| OpenCode | `~/.config/opencode/skills` | `<repo>/.opencode/skills` |
| Antigravity IDE | `~/.gemini/antigravity/skills` | `<repo>/.agents/skills` |

OpenCode còn tự đọc `.agents/skills` và `.claude/skills`. Không cài cùng một tên skill vào cả hai vị trí theo layout phẳng vì OpenCode yêu cầu tên duy nhất giữa các nguồn discovery.

### Thiết kế Universal đã chọn

- Cài canonical skill vào `.agents/skills` cho Codex và OpenCode; Antigravity dùng cùng đường dẫn ở project scope.
- Ở user scope, cài thêm canonical skill vào `~/.gemini/antigravity/skills`.
- Cài Claude dưới dạng nested skills-directory plugin tại `.claude/skills/ai-engineering-skills`.
- Claude plugin chứa `skills/<name>/SKILL.md` và không có `SKILL.md` ngay ở plugin root. Vì vậy OpenCode không phát hiện từng skill Claude như bản trùng layout phẳng.
- Repository canonical giữ một thư mục `skills/`; adapter chỉ thay đổi cách phân phối, không fork nội dung skill.

## Vấn đề của phiên bản 0.1.0 cần sửa

1. Installer đang dùng `~/.codex/skills`; tài liệu Codex hiện tại chỉ định user skills tại `~/.agents/skills`.
2. Validator chỉ dùng regex nên YAML sai và tên trùng trong manifest vẫn có thể trả exit code `0`.
3. `-Overwrite` chỉ merge và để lại stale files.
4. Installer không chạy validator trước khi cài.
5. Nơi cài không có receipt để truy vết version.
6. `agents/openai.yaml` đang bị validator coi là bắt buộc dù đây là metadata Codex tùy chọn.
7. Thiếu workflow `implement-change` và hướng dẫn stack routing rõ ràng.
8. Chưa có CI và `.gitattributes`.
9. Chưa chọn license. Không tự thêm license nếu chưa có quyết định của chủ repository.

## Yêu cầu cho installer v0.2.0

- Targets: `Codex`, `Claude`, `OpenCode`, `Antigravity`, `Universal`.
- Scopes: `User`, `Project`.
- Bắt buộc `ProjectRoot` khi scope là Project.
- Chạy validator trước mọi thay đổi.
- Preflight toàn bộ collision trước khi copy để tránh cài dở dang.
- Không ghi ngoài destination root đã resolve.
- `-Overwrite` thay nguyên managed skill directory, không merge, để loại stale files.
- Không xóa skill không thuộc collection.
- Ghi `.ai-engineering-skills.receipt.json` gồm collection, version, target, scope, thời gian và danh sách skill.
- Hỗ trợ `-WhatIf`.
- Universal không tạo duplicate mà OpenCode cùng discover.

## Yêu cầu cho validator v0.2.0

- Không phụ thuộc Python hoặc module bên ngoài.
- Canonical `SKILL.md` chỉ chấp nhận portable frontmatter `name` và `description`.
- Phát hiện duplicate field và duplicate skill name.
- Kiểm tra folder name khớp `name`.
- Kiểm tra category và semantic version trong `skillset.json`.
- `agents/openai.yaml` là tùy chọn; nếu tồn tại phải kiểm tra interface metadata.
- Kiểm tra relative Markdown references tồn tại.
- Parse và kiểm tra hai JSON plugin manifests.
- In toàn bộ lỗi và trả non-zero/throw khi có lỗi.

## Verification cần chạy trước khi áp dụng

```powershell
.\scripts\validate-skills.ps1
.\scripts\test-tooling.ps1
git diff --check
```

Functional tests tối thiểu:

- Universal User cài đúng số lượng skill vào `.agents/skills`.
- Antigravity User cài đúng vào `.gemini/antigravity/skills`.
- Claude nested plugin chứa manifest và toàn bộ skill.
- Universal không tạo OpenCode duplicate layout.
- Receipts khớp version `0.2.0`.
- Thêm stale file, chạy lại với `-Overwrite`, stale file phải bị xóa.
- Không `-Overwrite` thì collision phải fail trước khi thay đổi bất kỳ destination nào.

## Tài liệu đã dùng

- Codex Build Skills: `https://learn.chatgpt.com/docs/build-skills.md`
- Claude Code Skills: `https://code.claude.com/docs/en/skills`
- Claude Plugin Reference: `https://code.claude.com/docs/en/plugins-reference`
- OpenCode Agent Skills: `https://opencode.ai/docs/skills/`
- Antigravity Skills: `https://antigravity.google/docs/ide/skills/`
- Agent Skills specification: `https://agentskills.io/specification`

## Bước tiếp tục đề xuất

1. Đọc lại note này và kiểm tra source chính vẫn dựa trên commit `d2d49d6`.
2. Kiểm tra draft staging trước khi tái sử dụng; bỏ draft nếu source chính đã thay đổi theo hướng khác.
3. Hoàn tất ba script còn thiếu trong staging.
4. Chạy toàn bộ verification trong staging.
5. So sánh hash/diff với source chính và chỉ copy các file đã kiểm thử.
6. Chạy verification lần nữa tại source chính.
7. Chọn license với chủ repository.
8. Chỉ commit/push khi được yêu cầu rõ ràng.


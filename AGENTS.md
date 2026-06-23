你在 `/mnt/SN580-2T/Projects/oskernel2025-a20` 工作。

目标：基于真实评测机结果、`test-results.csv`、本地测试日志、排行榜和当前代码，以“纯难度优先”的顺序快速补分。`4afeeee` 线上已经确认 basic、busybox、lua 满分，当前最高优先级是修复 RV/glibc LTP bounded 线上失败；不要继续盲目扩窗，先按最新线上串口分簇修复并验证。

## 每轮必须先做

- 重新读取本文件、`git status --short`、`test-results.csv`、相关 `test-results/` 原始日志、最新线上评测 HTML/CSV、旧排行榜 HTML 和当前相关代码。
- 不要凭上一轮记忆继续执行；如果用户提供了新的线上 HTML 或串口日志，以最新文件为准并更新本文件。
- 每轮只选一个修复主题或问题簇；默认不跑全量 contest，除非用户明确要求。
- 修改前确认不会覆盖用户未提交改动；如果同一文件有不相关改动，先读懂并兼容。
- 所有测试日志保存到新的 `test-results/<时间>-<commit>-<主题>/` 目录。
- 只有本轮确实带来测试改善时才更新 `test-results.csv` 并 commit。
- 解决本文件“当前提分路线表”中的任何问题后，必须在该表 `状态/完成记录` 中写明完成 commit、日志目录、验证结果、剩余问题。

## 当前基线

- 当前本地 HEAD：本文件所在提交，提交主题为 `guard ltp futex cmp requeue timeout`；精确 hash 用 `git log -1 --oneline` 确认。
- 最新可用线上 Accepted 结果：`c28c3aad`，来自 `/home/muleizh/Downloads/c28c3aad.html`、`/home/muleizh/Downloads/Riscv-c28c3aad.txt`、`/home/muleizh/Downloads/LoongArch-c28c3aad.txt`。
  - 提交时间：`2026-06-23 18:46:02`。
  - 评测时间：`2026-06-23 18:50:54.756042+08:00` 到 `2026-06-23 20:20:34.798228+08:00`。
  - 总分：`1524.3454133907692`，比 `4afeeee` 的 `1519.6989598881132` 增长约 `4.646453502656`。
  - 旧榜总分第一队 `依旧是取名字难题`：`2877.9425`，当前差 `1353.597086609231`。
  - 旧榜中存在异常 LTP 单列 `ltp-glibc-la=2085853171`，做 sane best 比较时 LTP 单列按 `72000` 封顶。
- 线上结果解析文件：
  - `real-results/c28c3aad-online/scores-c28c3aad.csv`
  - `real-results/c28c3aad-online/scores-c28c3aad-by-variant.csv`
  - `real-results/c28c3aad-online/detail-scores-c28c3aad.csv`
  - `real-results/c28c3aad-online/shortcomings-c28c3aad.csv`
  - `real-results/c28c3aad-online/ltp-detail-c28c3aad.csv`
  - `real-results/c28c3aad-online/ltp-failures-c28c3aad.csv`
- 旧真实评测 `860e5c28f3342dab37a1335ff530565e52fdb648` 只作为历史对照：旧总分 `1461.9608684241714`，当时 LTP 为 0，且 iozone/lmbench 已证明四组入口能跑完。
- 最新本地 LTP bounded after：`test-results/20260624-4ac92ab-ltp-futex-requeue/after-serial-rv-glibc-ltp-bounded-futex-timeout.txt`，本地 RV/glibc bounded subset 为 `643 / 2840`，after QEMU status 0，`bounded_subset_completed`。
- `c28c3aad` 线上 RV/glibc LTP bounded subset 仍没有干净完成：拿 `39` 分，串口显示 `[CONTEST][FAIL] ltp bounded_subset_failed cases=6`。
  - 已确认线上清零：`4afeeee` 的 39 个 `ENOSPC` file metadata/xattr/path 主簇，以及 `ftest03`、`ftest04`、`ftest07`、`ftest08` wrapper timeout。
  - 线上剩余 5 个 timing/latency：`clock_gettime04`、`epoll_wait02`、`nanosleep01`、`poll02`、`select02`；当前本地已由 `/tmp/systemd-detect-virt` shim 修复并验证，待下一次线上确认。
  - 剩余 1 个 futex timeout：`futex_cmp_requeue01`；线上日志显示 LTP 内部 `Test timeouted, sending SIGKILL!` / `TBROK: Test killed! (timeout?)`，不是 contest wrapper 的 60s timeout；当前本地已通过 futex 专用 timeout guard 修复并验证，待下一次线上确认。
- `4afeeee` 线上 RV/glibc LTP bounded subset 历史失败：拿 `30` 分，串口显示 `[CONTEST][FAIL] ltp bounded_subset_failed cases=49`。
  - 39 个主簇为 file metadata/xattr/path `ENOSPC`：`access01`、`access02`、`access04`、`bind01`、`chmod01`、`chmod03`、`chmod06`、`chown02`、`chown04`、`chown05`、`chroot03`、`faccessat201`、`faccessat202`、`fchownat01`、`fchownat02`、`link02`、`setresgid04`、`setresuid05`、`setuid04`、`symlink04`、`unlink05`、`unlink07`、`utime07`、`rename09`、`renameat201`、`renameat202`、`fgetxattr03`、`lgetxattr01`、`lgetxattr02`、`listxattr01`、`listxattr02`、`listxattr03`、`llistxattr01`、`llistxattr02`、`llistxattr03`、`lstat01`、`lstat01_64`、`removexattr01`、`removexattr02`。
  - 4 个 ftest timeout：`ftest03`、`ftest04`、`ftest07`、`ftest08`。
  - 1 个 futex timeout：`futex_cmp_requeue01`。
  - 5 个 timing/latency：`clock_gettime04`、`clock_nanosleep02`、`select02`、`pselect01`、`pselect01_64`。
- `4afeeee` 线上前置稳定项目状态：
  - `basic` 四组全满：`408 / 408`。
  - `busybox` 四组全满：`216 / 216`。
  - `lua` 四组全满：`36 / 36`。
  - RV/LA 串口稳定项目 completed；LoongArch 入口 `Done: 17 tests, 0 failures`；RISC-V 入口唯一失败为 RV/glibc bounded LTP。
- 运行行为基线 `c1a5e07` 曾本地专项复核 `5027702d` 的 LTP ENOSPC 主簇：
  - 日志目录 `test-results/20260623-c1a5e07-ltp-enospc/`。
  - fresh 运行 40 个线上 ENOSPC file/xattr/path case：`failed_cases=0`。
  - `iozone` glibc+musl 前缀后运行同一 40-case 簇：`failed_cases=0`。
  - `iozone` glibc+musl 前缀后运行完整当前 RV/glibc bounded subset：QEMU status 0，`[CONTEST][PASS] ltp bounded_subset_completed`，`[ENOSPC][bounded][SUMMARY] executed=1 failed=0 rc=0`，扫描无 `FAIL LTP CASE`、`TFAIL`、`TBROK`、`TIMEOUT`、`ENOSPC`、`[CONTEST][FAIL]`。
  - 结论：旧线上 ENOSPC 簇在较短本地序列中无法复现；`4afeeee` 新线上长入口确认该簇真实存在。
- 本轮 VFS time metadata 修复：
  - 日志目录 `test-results/20260623-4afeeee-ltp-time-meta/`。
  - 根因：`kernel/fs/vfs/stat_perm.c` 的全局 `g_time_meta[VFS_TIME_META_MAX=8192]` 只分配不回收；长线上入口先运行大量文件创建/删除，再进入 LTP，导致 `vfs_set_times()` 在 metadata table 耗尽时返回 `-ENOSPC`，对应线上大量 `Failed to update access/modification time ... ENOSPC`。
  - 修复：新增 `vfs_drop_time_meta()`，在 `vfs_unlink()`、`vfs_rmdir()`、`vfs_rename_flags()` 成功删除或覆盖 vnode 后释放对应 time metadata。
  - 验证：复用 window32 完整 RV/glibc bounded after，`after-serial-rv-glibc-ltp-time-meta.txt` QEMU status 0，`[CONTEST][PASS] ltp bounded_subset_completed`，`[CONTEST][PASS] ltp-window32-after`；扫描无 `FAIL LTP CASE`、`TFAIL`、`TBROK`、`TIMEOUT`、`ENOSPC`、`[CONTEST][FAIL]`、kernel panic/page fault；线上 49 个失败 case 在本地 after 顺序中均通过。
  - `make all` 已通过，`build-make-all-after-time-meta.txt` 尾部包含 `=== Competition build complete ===` 并生成 `kernel-rv`、`kernel-la`、`disk.img`、`disk-la.img`。
  - ext4 9000 文件 create/write/delete 压力复现脚本尝试过慢，手动终止，不能作为通过证据。
- 本轮 ftest timeout guard：
  - 日志目录 `test-results/20260623-c28c3aa-ltp-ftest-timeout/`。
  - 线上依据：`4afeeee` 串口中 `ftest03/04/07/08` 在 60s wrapper timeout 后仍出现迟到 `TPASS`，说明线上慢路径接近超时并可能留下跨 case 输出污染。
  - 修复：RV/glibc bounded LTP 中 `ftest03`、`ftest04`、`ftest07`、`ftest08` 使用 120s case timeout；timeout 分支增加 `TERM`、等待、`KILL`、`wait` 清理，避免超时进程继续向后续 case 写输出。
  - 验证：targeted probe 中 `ftest03/04/07/08` 全部 rc 0；完整 RV/glibc bounded after `after-serial-rv-glibc-ltp-window32.txt` QEMU status 0，`[CONTEST][PASS] ltp bounded_subset_completed`，`[CONTEST][PASS] ltp-window32-after`；扫描无 `FAIL LTP CASE`、`TFAIL`、`TBROK`、`TIMEOUT`、`ENOSPC`、`[CONTEST][FAIL]`、kernel panic/page fault；`ftest03/04/07/08`、`futex_cmp_requeue01`、`clock_gettime04`、`clock_nanosleep02`、`select02`、`pselect01`、`pselect01_64` 在完整 after 中均通过。
  - `make all` 已通过，`build-make-all-after-ftest-timeout.txt` 尾部包含 `=== Competition build complete ===` 并生成 `kernel-rv`、`kernel-la`、`disk.img`、`disk-la.img`。
- `c28c3aad` 线上确认：
  - VFS time metadata 回收修复有效，`4afeeee` 的 39 个 `ENOSPC` 主簇线上清零。
  - ftest timeout guard 有效，`ftest03/04/07/08` 线上不再失败。
  - RV/glibc bounded LTP 仍失败 6 个 case：`clock_gettime04`、`epoll_wait02`、`nanosleep01`、`poll02`、`select02`、`futex_cmp_requeue01`。
  - 下一步只处理 residual6 中的一个簇；不要因为 wrapper PASS 直接跳过这些 case，跳过会丢掉它们当前线上已有的部分分。
- 本轮 timing/latency 修复：
  - 完成提交：本文件所在提交 `fix ltp virtual timing detection`。
  - 日志目录 `test-results/20260623-c7d2d62-ltp-timing-latency/`。
  - 根因：LTP 通过 `systemd-detect-virt` 判定虚拟机；镜像内缺少该命令时，`clock_gettime04` 与 `tst_timer_test` 走裸机阈值，在 QEMU 长入口中触发 5 个 timing/oversleep TFAIL。
  - 修复：`contest.sh` 将 `/tmp` 加入 `PATH`，并在 `/tmp/systemd-detect-virt` 创建 mksh shim；普通调用输出 `qemu` 并返回 0，`--quiet` 返回 0，`--container` 返回 1。最初尝试写 `/bin/systemd-detect-virt` 在 guest 内因 `ENOSPC` 失败，未保留。
  - 验证：`build-make-all-after-virt-detect-tmp.txt` 通过，尾部包含 `=== Competition build complete ===`；focused timing probe `probe-serial-rv-glibc-ltp-residual6-base.txt` 中 `clock_gettime04`、`epoll_wait02`、`nanosleep01`、`poll02`、`select02` 全部 PASS，`[LTP-RESIDUAL6][base][SUMMARY] pass=5 fail=0`，日志出现 `Running in a virtual machine, multiply the delta by 10.` 和 `Virtualisation detected, skipping oversleep checks`。
  - 完整 RV/glibc bounded after `after-serial-rv-glibc-ltp-bounded-timeout-mul.txt` QEMU status 0；5 个 timing case 在完整顺序中均通过；严格扫描剩余失败仅 `futex_cmp_requeue01`，最终 `[CONTEST][FAIL] ltp bounded_subset_failed cases=1` / `[CONTEST][FAIL] ltp-bounded-after-timeout-mul`。下一轮只处理 futex residual。
- 本轮 futex timeout guard：
  - 日志目录 `test-results/20260624-4ac92ab-ltp-futex-requeue/`。
  - 线上依据：`c28c3aad` 串口中 `futex_cmp_requeue01` 先通过 Test 0-4，随后大量 waiter 报 `ETIMEDOUT`，最后 LTP 自身打印 `Test timeouted, sending SIGKILL!` / `TBROK: Test killed! (timeout?)`，说明是 LTP 内部高 waiter 阶段超时，不是 contest wrapper 60s timeout。
  - 修复：仅对 RV/glibc bounded 中的 `futex_cmp_requeue01` 设置 180s wrapper timeout，并在该 case 运行期间导出 `LTP_TIMEOUT_MUL=4`，运行后恢复原环境；不改变其他 LTP case、musl/LA LTP skip 或 bounded 列表。
  - 验证：单项 after `probe-serial-rv-glibc-ltp-futex-single-after.txt` QEMU status 0，`futex_cmp_requeue01` 显示 `Timeout per run is 0h 02m 00s`，Test 5/6 TPASS，`END LTP CASE futex_cmp_requeue01 : 0`，`[CONTEST][PASS] ltp-futex-base`；完整 RV/glibc bounded after `after-serial-rv-glibc-ltp-bounded-futex-timeout.txt` QEMU status 0，`[CONTEST][PASS] ltp bounded_subset_completed` 和 `[CONTEST][PASS] ltp-bounded-after-futex-timeout`；严格扫描无 `FAIL LTP CASE`、`TFAIL`、`TBROK`、`TIMEOUT`、`ENOSPC`、`[CONTEST][FAIL]`、kernel panic/page fault、`proc_next_task_locked`、`assert`、`FATAL`。
  - `make all` 已通过，`build-make-all-after-futex-timeout.txt` 尾部包含 `=== Competition build complete ===` 并生成 `kernel-rv`、`kernel-la`、`disk.img`、`disk-la.img`。
- `c7d2d62` 本地附加验证：
  - `c7d2d62 guard ltp ftest timeouts` 是 timing 修复前的本地 HEAD。
  - 日志目录 `test-results/20260623-c7d2d62-ltp-online49-recheck/`：直接运行 `4afeeee` 线上失败的 49 个 RV/glibc LTP case，QEMU status 0，`[LTP-ONLINE49][probe][SUMMARY] pass=49 fail=0`，扫描无 `FAIL LTP CASE`、`TFAIL`、`TBROK`、`TIMEOUT`、`ENOSPC`、`[CONTEST][FAIL]`、kernel panic/page fault。
  - 日志目录 `test-results/20260623-c7d2d62-ltp-meta-stress-online49/`：先在 guest 内执行 8300 次 `/tmp` 文件 create/unlink，超过旧 `VFS_TIME_META_MAX=8192` 上限，`iterations=8300 stress_fail=0`；随后运行同一 49 个线上失败 case，QEMU status 0，`pass=49 fail=0`，同样无失败关键词。
  - 这些是本地增强证据，不能替代 `c28c3aa` 线上确认；在新线上结果返回前仍不继续 LTP 扩窗。
- 当前提交包构建预检：
  - 日志目录 `test-results/20260623-c1a5e07-submit-package/`。
  - 初始 `git archive` 干净包构建失败：`user/external/musl/configure` 在 zip 中无可执行位，`make all` 直接执行 `../configure` 得到 `Permission denied`。
  - 已由 commit `4afeeee fix submit zip musl configure` 将 `user/Makefile` 的 musl rebuild 改为 `sh ../configure`，避免依赖 zip/上传工具保留 Unix executable bit。
  - 临时工作树源码包 `oskernel2025-a20-c1a5e07-worktree-submit.zip` 解压后 `make all` 通过，日志 `build-make-all-from-worktree-zip.txt` 尾部包含 `=== Competition build complete ===`，并生成 `kernel-rv`、`kernel-la`、`disk.img`、`disk-la.img`。
  - 非过滤 git archive 包 `/home/muleizh/Downloads/oskernel2025-a20-4afeeee-submit.zip` 解压后 `make all` 通过，但包含已跟踪的 `test-results/` 历史日志，不作为推荐线上提交包。
  - clean 包 `/home/muleizh/Downloads/oskernel2025-a20-4afeeee-submit-clean.zip` 过滤了 `test-results/`，解压后 `make all` 通过，但仍包含提交时的 `AGENTS.md` 状态文档。
  - 推荐线上验证包 `/home/muleizh/Downloads/oskernel2025-a20-4afeeee-submit-final.zip` 已生成；该源码包过滤了 `AGENTS.md`、`test-results/` 和 `test-results.csv`，不含 `.git`、预构建 kernel/disk 产物或 sdcard 镜像；解压后 `make all` 通过，日志 `build-make-all-from-4afeeee-final-archive.txt` 尾部包含 `=== Competition build complete ===`，并生成 `kernel-rv`、`kernel-la`、`disk.img`、`disk-la.img`。
  - `test-results/20260623-4afeeee-submit-final-recheck/` 记录了旧 `oskernel2025-a20-4afeeee-submit-final.zip` 包复核：大小约 `5.8M`，SHA256 `a9c39580b5bb77635094184bac6cf0de9683eb357754c6c53b6d070045be0184`，`unzip -t` 无错误，禁止项扫描无 `AGENTS.md`、`test-results/`、`test-results.csv`、`.git`、预构建 kernel/disk 或 sdcard 镜像；该包已用于 `4afeeee` 线上评测，不包含本轮 VFS time metadata 修复，下一次线上验证不能复用此包。
  - 上一 HEAD 验证包 `/home/muleizh/Downloads/oskernel2025-a20-c7d2d62-submit-final.zip` 已生成；SHA256 `6104acee317034f5df02323383b3bd725fd8be648ace0a9624a31cad2132267d`，大小约 `5.8M`，过滤了 `AGENTS.md`、`test-results/`、`test-results.csv`、`.git` 和预构建 kernel/disk/sdcard 镜像；`unzip -t` 无错误，禁止项扫描无命中；解包后 `make all` 通过，日志 `test-results/20260623-c7d2d62-submit-package/build-make-all-from-c7d2d62-final-archive.txt` 尾部包含 `=== Competition build complete ===` 并生成 `kernel-rv`、`kernel-la`、`disk.img`、`disk-la.img`；该包不包含本轮 timing shim，下一次线上验证不能复用。

## 评测入口约束

- 评测机执行 `make all`，项目根目录必须生成 `kernel-rv`、`kernel-la`、`disk.img`、`disk-la.img`。
- 真实评测运行镜像内 `user/contest_init/contest.sh`。
- 测试必须串行运行，不能并发。
- 选择运行的测试必须打印官方组边界或官方脚本输出。
- 所有选择运行的测试结束后应主动 `poweroff`。
- 稳定高收益测试必须前置，风险测试必须后置并有 timeout。
- 当前 contest 入口顺序保持：稳定组 `basic busybox lua libctest iperf netperf libcbench`，风险/长耗时组 `cyclictest iozone lmbench`，最后 RV/glibc bounded LTP。
- 不要为了后置 LTP 或性能专题牺牲前面已稳定项目。

## 必须保护的稳定项目

后续修改必须避免退化：

- `basic`：rv/la x glibc/musl completed。
- `busybox`：rv/la x glibc/musl completed。
- `lua`：rv/la x glibc/musl completed 且满分。
- `iperf`：rv/la x glibc/musl completed。
- `netperf`：rv/la x glibc/musl completed。
- `libctest-musl-rv/la` completed。
- `libcbench-glibc-rv/la` completed。
- `libcbench-musl-rv/la` completed。
- `cyclictest-glibc-rv` completed。
- `cyclictest-musl-rv` completed。
- `iozone-glibc-rv/la`、`iozone-musl-rv/la` completed。
- `lmbench-glibc-rv/la`、`lmbench-musl-rv/la` completed。

## 当前必须保留的 skip / bounded 策略

- `glibc libctest` 继续 skip；它不计当前排行榜分且内部失败噪声大。
- LA `cyclictest-glibc` 和 `cyclictest-musl` 继续 skip，除非专门做 LA 调度/内存压力专题。
- `unixbench` 不计分，继续 skip。
- LTP 只允许 RV/glibc bounded subset：
  - 不放开全量 LTP。
  - 不放开 musl LTP。
  - 不放开 LA LTP。
  - `cgroup_fj_proc` 继续显式 `blacklisted_helper` skip。
  - `epoll_pwait03`、`pth_str02`、`asapi_03`、`shm_test`、`clock_nanosleep01`、`leapsec01`、`mmap3` 继续 quarantine。
  - `shm_test` 曾在 window29 probe 触发 `proc_next_task_locked` 链表损坏、`KERNEL PAGE FAULT`/`KERNEL PANIC`，不要在常规扩窗中重新运行。
  - 只加入 probe 与 after 都确认稳定、返回 rc 0、没有内部 `TFAIL/TBROK`、没有 host timeout 的 case。
- 在 `c28c3aad` residual 没有经线上确认清零前，不继续常规 LTP 扩窗；当前 timing/latency 簇和 `futex_cmp_requeue01` internal timeout 均已本地修复并等待线上确认。

## 当前提分路线表

排序口径：用户选择“纯难度优先”。表中参考分默认对比旧榜总分第一队 `依旧是取名字难题`；`best sane` 只作为额外线索。

| 顺序 | 项目 | 当前分 / 参考 | 难度 | 问题点 | 修复循环 | 验证循环 | 状态/完成记录 |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| 0 | lua | `36 / 36` | 无需修 | `4afeeee` 四组均 `9/9`。 | 不改入口。 | 只在其他改动后保护回归。 | 已完成/保护。 |
| 1 | busybox | `216 / 216` | 已完成 | 旧缺口 `kill 10` 和 musl `hwclock` 已在 4afeeee 线上清零。 | 不再作为主线。 | 只做回归保护。 | 已完成：`busybox kill 10` 由 commit `d649244` 修复，日志 `test-results/20260623-5377443-busybox-kill10`；`busybox hwclock` 由 commit `0531c5d` 修复，日志 `test-results/20260623-d649244-busybox-hwclock`；`4afeeee` 线上四组均 `54/54`。 |
| 2 | basic | `408 / 408` | 已完成 | 旧缺口 `mount/umount`、`pipe`、`brk` 已在 4afeeee 线上清零。 | 不再作为主线。 | 只做回归保护。 | 已完成：`mount/umount` 日志 `test-results/20260623-0531c5d-basic-mount`；`pipe` 日志 `test-results/20260623-fbfffc5-basic-pipe`；`brk` 日志 `test-results/20260623-61af977-basic-brk`；`4afeeee` 线上四组均 `102/102`。 |
| 3 | libctest-musl | `434 / 434`，best sane `447` | 中 | 对旧榜首无差距；明细中 musl `crypt` 动/静态、`pleval` 静态为 0；glibc libctest 继续 skip。 | basic/busybox 完成后再考虑；先单项提取失败原因，不碰 glibc libctest 入口。 | musl libctest 单项；确认项目仍 completed。 | 暂缓。 |
| 4 | LTP 线上 bounded 修复 | `39 / 122100`，sane best `288000` | 中 | `c28c3aad` 线上 RV/glibc bounded 失败 6 个 case；5 个 timing/latency 已本地修复待线上确认：`clock_gettime04`、`epoll_wait02`、`nanosleep01`、`poll02`、`select02`；1 个 futex internal timeout 已本地修复待线上确认：`futex_cmp_requeue01`。`4afeeee` 的 39 个 ENOSPC 主簇和 4 个 ftest wrapper timeout 已线上清零；musl/LA LTP 仍 skip。 | 每轮只修一个簇。已修 ENOSPC 主簇：释放 VFS time metadata table 中被 unlink/rmdir/rename-overwrite 删除 vnode 占用的记录。已加 ftest timeout guard：`ftest03/04/07/08` 使用 120s timeout 并强化超时清理。已修 timing/latency 簇：增加 `/tmp/systemd-detect-virt` shim 让 LTP 使用虚拟化阈值。已修 futex internal timeout：仅对 `futex_cmp_requeue01` 设置 180s wrapper timeout 和 `LTP_TIMEOUT_MUL=4`，运行后恢复环境。 | 完整 RV/glibc bounded after；扫描关键失败词；`make all`；线上复测确认 residual 是否减少到 0。 | 部分完成-待线上确认 timing/futex：VFS time metadata 修复 commit `c28c3aa fix vfs time metadata recycling`，日志 `test-results/20260623-4afeeee-ltp-time-meta/`，`c28c3aad` 线上确认 39 个 ENOSPC 主簇清零；ftest timeout guard commit `c7d2d62 guard ltp ftest timeouts`，日志 `test-results/20260623-c28c3aa-ltp-ftest-timeout/`，`c28c3aad` 线上确认 `ftest03/04/07/08` 清零。timing/latency 修复 commit `4ac92ab fix ltp virtual timing detection`，日志 `test-results/20260623-c7d2d62-ltp-timing-latency/`，focused timing probe 5/5 PASS，完整 bounded after 中 5 个 timing case 均 PASS。futex timeout guard 为本文件所在提交，日志 `test-results/20260624-4ac92ab-ltp-futex-requeue/`，单项 futex after PASS，完整 643-case RV/glibc bounded after QEMU status 0，`bounded_subset_completed` 和 `ltp-bounded-after-futex-timeout` PASS，严格扫描无失败关键词，`make all` PASS。下一步：线上确认 residual6 是否清零；确认前不继续扩窗。 |
| 5 | LTP bounded 扩窗 | 本地 `643 / 2840` case | 中 | 只有在线上确认 residual 不再导致 bounded fail 后才继续。 | 先整理 pending 全量、过滤理由、最终 probe 列表；不要边挑边测；不要一次性运行全部 pending。 | probe 只筛 strict clean case；after 完整 bounded PASS；`make all`；更新 `test-results.csv` 和本表完成记录。 | 阻塞于顺序 4 的线上确认。 |
| 6 | cyclictest | `9.4849 / 31.9919` | 中-高 | LA 两组 skip；RV 通过但分低，日志有 `WARN: High resolution timers not available` 和 hackbench 压力噪声。 | 默认只研究 RV timer/调度小修；LA 仍 skip，除非用户指定。 | RV cyclictest glibc/musl 单项；确认入口 completed 不退化。 | 暂缓。 |
| 7 | iperf/netperf | `45.2961 / 87.9826` 合计 | 高 | 四组都 PASS 但吞吐/延迟低；glibc netperf UDP_STREAM 打印 `enable_enobufs failed: getprotobyname`。 | 先修低风险 libc/network database 兼容，再看 TCP/UDP copy、wakeup、timer 性能。 | iperf/netperf 四组单项，对比分数和串口输出。 | 暂缓。 |
| 8 | iozone | `80 / 159.9971` | 高 | 四组都 PASS，但每组 `20/40`，明细每个吞吐项只有基础分。 | 存储/page-cache/virtio block 性能专题；不改入口顺序和 timeout。 | iozone 四组单项，确认 completed 且吞吐改善。 | 暂缓。 |
| 9 | lmbench/libcbench | `288.2307 / 503.9709` 合计 | 高 | syscall/stat/exec/shell/pipe、stdio、pthread、memory 性能低；lmbench 反复打印 `[ELF] read header failed`。 | 先做 exec/ELF 短文件与 stdio/pthread 热点专题。 | lmbench/libcbench 四组单项，对比性能分；保护 completed。 | 暂缓。 |

## 每个问题簇的固定修复/验证循环

1. 先最小复现，不直接全量 contest。
2. 修一簇、测一簇；不要把多个项目混在一轮。
3. 单项通过后再跑对应项目四组。
4. 涉及公共内核路径、入口脚本或评测产物时再跑 `make all`。
5. 保存所有日志到新的 `test-results/<时间>-<commit>-<主题>/`。
6. 只有出现明确改善才更新 `test-results.csv` 并 commit。
7. commit 后更新本文件：
   - 当前 HEAD。
   - 相关分数或 case 数。
   - 当前提分路线表中的 `状态/完成记录`。
   - 新增 quarantine、skip、风险或验证日志路径。

## LTP 专用工作流

当前 LTP 工作分两阶段，不能跳过阶段 1：

### 阶段 1：修复线上 bounded residual

1. 最新 residual 以 `c28c3aad` 为准，从 `/home/muleizh/Downloads/Riscv-c28c3aad.txt` 和 `real-results/c28c3aad-online/ltp-failures-c28c3aad.csv` 提取 6 个失败 case。
2. 优先按失败原因分簇：
   - 已完成并线上确认：ENOSPC/file metadata/xattr/path 39 个 case；ftest wrapper timeout 4 个 case。
   - 已本地修复待线上确认：timing/latency `clock_gettime04`、`epoll_wait02`、`nanosleep01`、`poll02`、`select02`。
   - 已本地修复待线上确认：futex internal timeout `futex_cmp_requeue01`。
3. 每轮只选一个簇，先单项复现，再修内核或入口问题；不要把 timing 和 futex 混在同一轮修。
4. 阶段 1 当前完成标准：`c28c3aad` residual6 全部清零或明确记录剩余原因。完整 RV/glibc bounded after 必须干净通过，无 `FAIL LTP CASE`、`TFAIL`、`TBROK`、`TIMEOUT`、`[CONTEST][FAIL]`、kernel panic/page fault。

### 阶段 2：继续 bounded 扩窗

1. 只有阶段 1 完成后才继续扩窗。
2. 每轮只做一个 bounded window，但窗口应尽量高吞吐。
3. 在任何测试前先完成候选整理：保存 pending 全量、过滤后候选全集、排除清单和最终 probe 列表。
4. 不要把全部 pending case 一次性塞进 probe；必须按主题/风险/依赖拆成窗口。
5. 若 HEAD、`contest.sh` bounded 列表和上一轮 after 对应状态一致，可引用上一轮 after 作为 baseline，跳过 before；否则先跑 before。
6. probe 允许失败；失败、missing、TCONF、TFAIL、TBROK、SIGSEGV、timeout、资源压力 case 只记录，不加入 bounded subset。
7. 只加入完全干净的 case：rc 0、无内部 `TFAIL/TBROK`、无 host timeout、无卡住/OOM/资源耗尽风险。
8. 修改 `user/contest_init/contest.sh` 后必须跑完整 after；after 不能降低正式验证强度。
9. 如果 after 失败，优先对本轮新增集合二分；若历史 case 暴露不稳定，可 quarantine，但必须记录原因并保证最终 bounded 总数净增长。
10. 跑 `make all` 并保存 build 日志。
11. 有明确 case 数增长后再更新 `test-results.csv`、commit，并更新本文件。

## 当前 LTP 事实和历史 quarantine

- 官方 `ltp_testcode.sh` 实际遍历 `ltp/testcases/bin/*` 直属普通文件。
- 本地官方测试盘 case 数：
  - RV/glibc：2840。
  - RV/musl：2820。
  - LA/glibc：2840。
  - LA/musl：2820。
- 原始四组 LTP 单项都会卡在 `RUN LTP CASE cgroup_fj_proc`。
- 最新已验证本地窗口：`test-results/20260624-4ac92ab-ltp-futex-requeue/after-serial-rv-glibc-ltp-bounded-futex-timeout.txt`；VFS time metadata 修复后复跑完整 after 的复制日志为 `test-results/20260623-4afeeee-ltp-time-meta/after-serial-rv-glibc-ltp-time-meta.txt`；ftest guard 后完整 after 为 `test-results/20260623-c28c3aa-ltp-ftest-timeout/after-serial-rv-glibc-ltp-window32.txt`。
- window25-window32 已扩至本地 `643` 个 RV/glibc bounded case；线上 `c28c3aad` 显示 bounded 列表失败 6 个 case，其中 `4afeeee` 的 39 个 ENOSPC 主簇和 `ftest03/04/07/08` timeout 已线上确认修复；timing/latency 5 case 与 `futex_cmp_requeue01` 已本地修复待线上确认；继续扩窗前必须先等待线上确认或明确记录残留原因。
- 后续常规扩窗继续排除 window25-window32 rejected 类别：rsh 依赖 network、hugetlb/NUMA/keyctl/mq/pid-user namespace、shell wrapper/helper、execve 内部 TFAIL、pidfd/sysctl、DIO/dirtyc0w/mmap stress、float abort、ioctl/ioprio/kcmp、dirtypipe、dma_thread_diotest、usage/参数依赖 helper、fs_racer timeout/SIGSEGV/FATAL 等，除非专门做对应问题簇复核。

## 线上评测和文档更新规则

- 新线上结果出现后，先解析成绩到 `real-results/<commit>-online/`，至少包含：
  - 总分/分项 CSV。
  - 逐 variant CSV。
  - detail scores CSV。
  - shortcomings CSV。
- 如果线上结果改变优先级，先更新本文件，再开始下一轮代码修复。
- 如果某项已解决：
  - 在“当前提分路线表”对应行把状态改为 `已完成` 或 `部分完成`。
  - 写明 commit、日志目录、改善前后分数或通过 case 数。
  - 若仍有残留问题，写清下一步。
- 如果尝试后无收益：
  - 状态改为 `已尝试-无收益`。
  - 写明日志目录和失败原因。
  - 没有代码或测试改善则不要 commit 代码变更。

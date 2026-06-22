你在 `/mnt/SN580-2T/Projects/oskernel2025-a20` 工作。

目标：基于真实评测机结果、`test-results.csv`、本地测试日志、排行榜和当前代码，以“纯难度优先”的顺序快速补分。当前不要继续盲目扩 RV/glibc LTP；先处理更容易闭环的小正确性缺口，再回到线上 LTP bounded 失败和后续性能专题。

## 每轮必须先做

- 重新读取本文件、`git status --short`、`test-results.csv`、相关 `test-results/` 原始日志、最新线上评测 HTML/CSV、旧排行榜 HTML 和当前相关代码。
- 不要凭上一轮记忆继续执行；如果用户提供了新的线上 HTML 或串口日志，以最新文件为准并更新本文件。
- 每轮只选一个修复主题或问题簇；默认不跑全量 contest，除非用户明确要求。
- 修改前确认不会覆盖用户未提交改动；如果同一文件有不相关改动，先读懂并兼容。
- 所有测试日志保存到新的 `test-results/<时间>-<commit>-<主题>/` 目录。
- 只有本轮确实带来测试改善时才更新 `test-results.csv` 并 commit。
- 解决本文件“当前提分路线表”中的任何问题后，必须在该表 `状态/完成记录` 中写明完成 commit、日志目录、验证结果、剩余问题。

## 当前基线

- 当前本地 HEAD：当前提交 `fix basic pipe output`；精确 hash 以 `git rev-parse --short HEAD` 为准。
- 最新可用线上 Accepted 结果：`5027702d`，来自 `/home/muleizh/Downloads/new.html`。
  - 提交时间：`2026-06-22 14:08:01`。
  - 评测时间：`2026-06-22 14:34:28.724232+08:00` 到 `2026-06-22 16:03:44.400848+08:00`。
  - 总分：`1461.537603398732`。
  - 旧榜总分第一队 `依旧是取名字难题`：`2877.9425`，当前差 `1416.404896601268`。
  - 旧榜中存在异常 LTP 单列 `ltp-glibc-la=2085853171`，做 sane best 比较时 LTP 单列按 `72000` 封顶。
- 线上结果解析文件：
  - `real-results/5027702d-online/scores-5027702d.csv`
  - `real-results/5027702d-online/scores-5027702d-by-variant.csv`
  - `real-results/5027702d-online/detail-scores-5027702d.csv`
  - `real-results/5027702d-online/shortcomings-5027702d.csv`
- 旧真实评测 `860e5c28f3342dab37a1335ff530565e52fdb648` 只作为历史对照：旧总分 `1461.9608684241714`，当时 LTP 为 0，且 iozone/lmbench 已证明四组入口能跑完。
- 最新本地 LTP bounded after：`test-results/20260622-3d92ae9-ltp-window32/after-serial-rv-glibc-ltp-window32.txt`，本地 RV/glibc bounded subset 为 `643 / 2840`，after 全部 rc 0。
- 但 `5027702d` 线上 RV/glibc LTP bounded subset 没有干净完成：只拿 `13` 分，串口显示 `[CONTEST][FAIL] ltp bounded_subset_failed cases=44`。

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
- 在 `5027702d` 线上 bounded LTP 失败被解释并修好前，不继续常规 LTP 扩窗。

## 当前提分路线表

排序口径：用户选择“纯难度优先”。表中参考分默认对比旧榜总分第一队 `依旧是取名字难题`；`best sane` 只作为额外线索。

| 顺序 | 项目 | 当前分 / 参考 | 难度 | 问题点 | 修复循环 | 验证循环 | 状态/完成记录 |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| 0 | lua | `36 / 36` | 无需修 | 5027702d 四组均 `9/9`。 | 不改入口。 | 只在其他改动后保护回归。 | 已完成/保护。 |
| 1 | busybox | `214 / 216`，best sane `218` | 低 | `busybox kill 10` 四组均 `0/1`；musl `hwclock` RV/LA 均失败，串口为 `RTC_RD_TIME: Not a tty`。 | 每轮只修一个小簇：先 `kill 10`，再 musl `hwclock`；分别定位 signal/kill 语义和 RTC ioctl/tty 兼容。 | 先跑对应 busybox 单项，再跑 busybox 四组；确认不影响 basic/lua；需要产物时再 `make all`。 | 本地完成：`busybox kill 10` 已由 commit `d649244` 修复，日志 `test-results/20260623-5377443-busybox-kill10`；`busybox hwclock` 已由 commit `0531c5d` 修复，日志 `test-results/20260623-d649244-busybox-hwclock`；RV/LA x glibc/musl 官方 busybox 脚本追加 hidden `kill 10` 均输出 `testcase busybox hwclock success` 和 `testcase busybox kill 10 success`，`make all` 通过并生成四个产物；等待下一次线上验证。 |
| 2 | basic | 线上 `352 / 408`；本地 `mount/umount`、`pipe` 已修，待线上验证 | 低-中 | 原线上 `mount/umount` 四组全 0；`pipe` 在 LA glibc 和 musl 两架构缺；`brk` 在 RV glibc、LA musl 部分缺。已定位并修复 `mount/umount` 的 `sys_umount2` 相对路径未规范化、VFS unmount root double-free、`/dev/vda2` 兼容映射问题；已定位并修复 `pipe` 的父子进程 tty 输出行串扰。 | 分三簇串行：`mount/umount`、`pipe`、`brk`；每轮只修一簇。`mount/umount` 和 `pipe` 已完成，下一轮优先 `brk`。 | 先跑对应 basic 子项，再跑 basic 四组；如涉及 VFS/VM/tty 公共路径，再跑 busybox smoke 和 `make all`。 | 部分完成：`mount/umount` 已由提交 `fix basic mount umount` 修复，日志 `test-results/20260623-0531c5d-basic-mount`；RV/LA x glibc/musl 最小和官方 basic `mount/umount` 均通过，`make all` 通过。`pipe` 已由本轮提交 `fix basic pipe output` 修复，日志 `test-results/20260623-fbfffc5-basic-pipe`；before RV/LA pipe 循环 `cpid:` 串扰 32/32，after 为 0/32；RV/LA 官方 basic 脚本中 glibc/musl 四个 `test_pipe` 均输出干净 `cpid: 0`、父 PID 和 `Write to pipe successfully.`；busybox echo/printf/true smoke 通过；`make all` 通过并生成四个产物。剩余：`brk` 缺口，等待线上验证本轮修复。 |
| 3 | libctest-musl | `434 / 434`，best sane `447` | 中 | 对旧榜首无差距；明细中 musl `crypt` 动/静态、`pleval` 静态为 0；glibc libctest 继续 skip。 | basic/busybox 完成后再考虑；先单项提取失败原因，不碰 glibc libctest 入口。 | musl libctest 单项；确认项目仍 completed。 | 暂缓。 |
| 4 | LTP 线上 bounded 修复 | `13 / 122100`，sane best `288000` | 中 | 线上 RV/glibc bounded 失败 44 个 case；大量 file metadata/xattr/path case 报 `ENOSPC`，另有 `clock_gettime04` timing、`select04` timeout、`futex_cmp_requeue01` ETIMEDOUT；musl/LA LTP 仍 skip。 | 先禁止扩窗；复现并定位线上 ENOSPC/磁盘污染来源，再按小簇处理 timing/select/futex。 | 本地复现失败簇；跑完整 RV/glibc bounded after，必须出现 `[CONTEST][PASS] ltp bounded_subset_completed`；再 `make all`。 | 待处理。 |
| 5 | LTP bounded 扩窗 | 本地 `643 / 2840` case | 中 | 只有在线上 bounded 修复后才继续。 | 先整理 pending 全量、过滤理由、最终 probe 列表；不要边挑边测；不要一次性运行全部 pending。 | probe 只筛 strict clean case；after 完整 bounded PASS；`make all`；更新 `test-results.csv` 和本表完成记录。 | 阻塞于顺序 4。 |
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

### 阶段 1：修复 5027702d 线上 bounded 失败

1. 从 `/home/muleizh/Downloads/Riscv输出.txt` 和 `real-results/5027702d-online/detail-scores-5027702d.csv` 提取 44 个失败 case。
2. 优先按失败原因分簇：
   - ENOSPC/file metadata/xattr/path：`access*`、`chmod*`、`chown*`、`link*`、`rename*`、`xattr*`、`lstat*` 等。
   - timing：`clock_gettime04`。
   - timeout/select：`select04`。
   - futex wake：`futex_cmp_requeue01`。
3. 每轮只选一个簇，先单项复现，再修内核或入口污染问题。
4. 阶段 1 完成标准：完整 RV/glibc bounded after 干净通过，无 `FAIL LTP CASE`、`TFAIL`、`TBROK`、`TIMEOUT`、`[CONTEST][FAIL]`、kernel panic/page fault。

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
- 最新已验证本地窗口：`test-results/20260622-3d92ae9-ltp-window32`。
- window25-window32 已扩至本地 `643` 个 RV/glibc bounded case，但线上 `5027702d` 证明当前 bounded 列表在真实评测环境仍会失败，先修失败再扩窗。
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

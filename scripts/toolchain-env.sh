#!/usr/bin/env bash
# toolchain-env.sh — 定位 MoonBit 工具链，保证 moon 可用。
# 用法：source scripts/toolchain-env.sh
#
# 解析顺序：
#   1) 已显式设置 MOON 且可执行；
#   2) moon 已在 PATH 中；
#   3) 依次探测 MOON_BIN_DIR、官方/包管理器安装目录、受管工具链目录，
#      命中后把该 bin 目录前插到 PATH。
# 成功后导出 MOON（绝对路径）与 MOON_BIN_DIR（所在目录），供
# build.sh / consistency.sh 复用。
#
# 环境变量：
#   MOON=/path/to/moon   跳过探测，直接用指定二进制
#   MOON_BIN_DIR=...     额外候选目录（放在最前面）
#   TOOLCHAIN_ENV_QUIET=1  不打印提示（脚本内部调用与 CI 用）
#
# 注意：必须在当前 shell 中 source，不能作为子进程执行。

_moon_log() {
  if [ -z "${TOOLCHAIN_ENV_QUIET:-}" ]; then
    echo "toolchain-env: $*" >&2
  fi
  return 0
}

# 若 $1 目录下存在 moon / moon.exe，打印其绝对路径，否则返回 1。
_moon_probe_dir() {
  local dir="${1:-}"
  [ -n "$dir" ] && [ -d "$dir" ] || return 1
  if [ -f "$dir/moon" ] || [ -f "$dir/moon.exe" ]; then
    ( cd "$dir" 2>/dev/null && pwd )
    return 0
  fi
  return 1
}

toolchain_env() {
  # 1) 显式指定（MOON 可以是命令名，也可以是路径）
  if [ -n "${MOON:-}" ]; then
    if [ -f "${MOON}" ] || [ -x "${MOON}" ]; then
      case "${MOON}" in
        /*|?:/*|?:\\*) MOON_BIN_DIR="$(cd "$(dirname "${MOON}")" 2>/dev/null && pwd)" ;;
      esac
      export MOON
      [ -n "${MOON_BIN_DIR:-}" ] && export MOON_BIN_DIR
      return 0
    fi
    local resolved
    resolved="$(command -v "${MOON}" 2>/dev/null || true)"
    if [ -n "$resolved" ]; then
      MOON="$resolved"
      export MOON
      return 0
    fi
  fi

  # 2) PATH 中已有
  local on_path
  on_path="$(command -v moon 2>/dev/null || true)"
  if [ -n "$on_path" ]; then
    MOON="$on_path"
    export MOON
    return 0
  fi

  # 3) 候选目录
  local candidates=()
  [ -n "${MOON_BIN_DIR:-}" ] && candidates+=("$MOON_BIN_DIR")
  candidates+=("${MOON_HOME:-$HOME/.moon}/bin" "$HOME/.moon/bin" "$HOME/.local/bin" "$HOME/bin")
  case "${OSTYPE:-}" in
    msys*|cygwin*|win*)
      candidates+=(
        "$HOME/AppData/Local/Programs/moonbit/bin"
        "$HOME/scoop/shims"
        "$HOME/.workbuddy/binaries/moonbit/bin"
      )
      ;;
    darwin*)
      candidates+=("/opt/homebrew/bin" "/usr/local/bin")
      ;;
    *)
      candidates+=("/usr/local/bin" "/usr/lib/moonbit/bin" "/snap/bin")
      ;;
  esac

  # 受管工具链：CI 沙箱 / 会话级工作区会把工具链解压在 .tools 下，
  # 这类目录不在默认 PATH 里，按修改时间从新到旧尝试。
  local managed=() d
  for d in "$HOME"/WorkBuddy/*/.tools/moonbit/bin \
           "$HOME"/.workbuddy/toolchains/*/bin \
           "$HOME"/.workbuddy/binaries/*/bin; do
    [ -d "$d" ] && managed+=("$d")
  done
  if [ ${#managed[@]} -gt 0 ]; then
    while IFS= read -r d; do
      [ -n "$d" ] && candidates+=("$d")
    done < <(ls -dt "${managed[@]}" 2>/dev/null || true)
  fi

  local found
  for d in "${candidates[@]}"; do
    if found="$(_moon_probe_dir "$d")"; then
      export PATH="$found:$PATH"
      export MOON_BIN_DIR="$found"
      hash -r 2>/dev/null || true
      MOON="$(command -v moon 2>/dev/null || printf '%s' "$found/moon")"
      export MOON
      _moon_log "moon -> $MOON (prepended $found to PATH)"
      return 0
    fi
  done

  _moon_log "moon not found. Install from https://www.moonbitlang.com/download/ or set MOON=/path/to/moon"
  return 1
}

toolchain_env

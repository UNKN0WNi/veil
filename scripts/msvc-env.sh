#!/usr/bin/env bash
# msvc-env.sh — 在 Git Bash / MSYS 中导入 MSVC 环境（Windows）。
# 用法：source scripts/msvc-env.sh
# 供 build.sh / consistency.sh 自动调用；已有 cl 时直接返回。
# 说明：本脚本不调用 cmd.exe / vcvars64.bat，而是用 vswhere 定位
#       MSVC 与 Windows SDK，直接设置 PATH / INCLUDE / LIB。
# 注意：必须在当前 shell 中 source，不能作为子进程执行。

msvc_env() {
  if command -v cl >/dev/null 2>&1; then
    return 0
  fi
  case "${OSTYPE:-}" in
    msys*|cygwin*) ;;
    *) return 1 ;;
  esac

  local vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
  if [ ! -f "$vswhere" ]; then
    [ -z "${MSVC_ENV_QUIET:-}" ] && echo "msvc-env: vswhere.exe not found" >&2
    return 1
  fi

  local vs_path vs_unix
  vs_path="$("$vswhere" -latest -products '*' \
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
    -property installationPath 2>/dev/null | tr -d '\r')"
  if [ -z "$vs_path" ]; then
    [ -z "${MSVC_ENV_QUIET:-}" ] && echo "msvc-env: MSVC C++ tools not installed" >&2
    return 1
  fi
  vs_unix="$(cygpath -u "$vs_path")"

  local msvc_root="$vs_unix/VC/Tools/MSVC"
  if [ ! -d "$msvc_root" ]; then
    [ -z "${MSVC_ENV_QUIET:-}" ] && echo "msvc-env: MSVC tools directory not found" >&2
    return 1
  fi
  local msvc_ver
  msvc_ver="$(ls -1 "$msvc_root" 2>/dev/null | sort -V | tail -n1)"
  local cl_dir="$msvc_root/$msvc_ver/bin/Hostx64/x64"
  if [ ! -x "$cl_dir/cl.exe" ]; then
    [ -z "${MSVC_ENV_QUIET:-}" ] && echo "msvc-env: cl.exe not found under $cl_dir" >&2
    return 1
  fi

  local sdk_root="/c/Program Files (x86)/Windows Kits/10"
  local sdk_ver=""
  if [ -d "$sdk_root/Include" ]; then
    sdk_ver="$(ls -1 "$sdk_root/Include" 2>/dev/null | sort -V | tail -n1)"
  fi
  if [ -z "$sdk_ver" ]; then
    [ -z "${MSVC_ENV_QUIET:-}" ] && echo "msvc-env: Windows SDK not found" >&2
    return 1
  fi

  # PATH 用 Unix 形式，Git Bash 才能找到 cl.exe / link.exe / rc.exe。
  export PATH="$cl_dir:$sdk_root/bin/$sdk_ver/x64:$PATH"

  # INCLUDE / LIB 必须用 Windows 形式，cl.exe / link.exe 不识别 /c/...。
  export INCLUDE="$(cygpath -w "$msvc_root/$msvc_ver/include");$(cygpath -w "$sdk_root/Include/$sdk_ver/ucrt");$(cygpath -w "$sdk_root/Include/$sdk_ver/um");$(cygpath -w "$sdk_root/Include/$sdk_ver/shared");$(cygpath -w "$sdk_root/Include/$sdk_ver/winrt")"
  export LIB="$(cygpath -w "$msvc_root/$msvc_ver/lib/x64");$(cygpath -w "$sdk_root/Lib/$sdk_ver/ucrt/x64");$(cygpath -w "$sdk_root/Lib/$sdk_ver/um/x64")"
  export LIBPATH="$(cygpath -w "$msvc_root/$msvc_ver/lib/x64")"
  export VCToolsInstallDir="$(cygpath -w "$msvc_root/$msvc_ver")"
  export WindowsSdkDir="$(cygpath -w "$sdk_root")"
  export WindowsSDKVersion="$sdk_ver\\"

  hash -r
  command -v cl >/dev/null 2>&1
}

msvc_env

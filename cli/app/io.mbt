// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 文件读写：统一 UTF-8 文本，失败即 fail-closed（退出码 2）。

///|
/// 读取文本文件；失败时打印错误并以退出码 2 结束。
pub fn read_text_file(path : String, label : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => {
      eprintln("error: cannot read " + label + " file: " + path)
      @env.exit(2)
    }
  }
}

///|
/// 写入文本文件；失败时打印错误并以退出码 2 结束。
pub fn write_text_file(path : String, text : String) -> Unit {
  @fs.write_string_to_file(path, text) catch {
    _ => {
      eprintln("error: cannot write output file: " + path)
      @env.exit(2)
    }
  }
}

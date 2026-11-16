// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 自建有序 JSON 解析器：
// - 保序：Object 用 Array[(String, JsonValue)]，插入顺序即输出顺序
// - 保数字原文：Number(String)，不转 Double
// - 拒重复键：key smuggling 防护（R2'''）
// 纯手写递归下降，四后端一致。

///|
/// 解析错误。
pub(all) struct JsonParseError {
  message : String
  position : Int32
}

///|
/// 解析器状态。
priv struct Parser {
  chars : Array[Char]
  mut pos : Int32
}

///|
/// 跳过空白。
fn skip_ws(p : Parser) -> Unit {
  while p.pos < p.chars.length() {
    let c = p.chars[p.pos].to_int()
    if c == 32 || c == 9 || c == 10 || c == 13 {
      p.pos += 1
    } else {
      break
    }
  }
}

///|
/// 解析 JSON 值（公开入口）。重复键 → Err（key smuggling 防护）。
pub fn parse_json(input : String) -> Result[JsonValue, JsonParseError] {
  let p = Parser::{ chars: input.to_array(), pos: 0, }
  skip_ws(p)
  match parse_value(p) {
    Err(e) => Err(e)
    Ok(v) => {
      skip_ws(p)
      if p.pos != p.chars.length() {
        Err(JsonParseError::{ message: "trailing characters", position: p.pos, })
      } else {
        Ok(v)
      }
    }
  }
}

///|
/// 解析一个值。
fn parse_value(p : Parser) -> Result[JsonValue, JsonParseError] {
  skip_ws(p)
  if p.pos >= p.chars.length() {
    return Err(JsonParseError::{
      message: "unexpected end of input",
      position: p.pos,
    })
  }
  let c = p.chars[p.pos]
  if c == 'n' {
    return parse_literal(p, "null", Null)
  } else if c == 't' {
    return parse_literal(p, "true", Bool(true))
  } else if c == 'f' {
    return parse_literal(p, "false", Bool(false))
  } else if c == '"' {
    return match parse_string(p) {
      Err(e) => Err(e)
      Ok(s) => Ok(Str(s))
    }
  } else if c == '[' {
    return parse_array(p)
  } else if c == '{' {
    return parse_object(p)
  } else if c == '-' || (c.to_int() >= 48 && c.to_int() <= 57) {
    return parse_number(p)
  }
  Err(JsonParseError::{ message: "unexpected character", position: p.pos, })
}

///|
/// 解析字面量（null/true/false）。
fn parse_literal(
  p : Parser,
  lit : String,
  value : JsonValue,
) -> Result[JsonValue, JsonParseError] {
  let lc = lit.to_array()
  for i = 0; i < lc.length(); i = i + 1 {
    if p.pos + i >= p.chars.length() || p.chars[p.pos + i] != lc[i] {
      return Err(JsonParseError::{
        message: "invalid literal",
        position: p.pos,
      })
    }
  }
  p.pos += lc.length()
  Ok(value)
}

///|
/// 解析字符串（含转义）。
fn parse_string(p : Parser) -> Result[String, JsonParseError] {
  if p.chars[p.pos] != '"' {
    return Err(JsonParseError::{ message: "expected string", position: p.pos, })
  }
  p.pos += 1
  let mut out = ""
  while p.pos < p.chars.length() {
    let c = p.chars[p.pos]
    if c == '"' {
      p.pos += 1
      return Ok(out)
    }
    if c == '\\' {
      p.pos += 1
      if p.pos >= p.chars.length() {
        return Err(JsonParseError::{
          message: "unterminated escape",
          position: p.pos,
        })
      }
      let e = p.chars[p.pos]
      if e == '"' {
        out += "\""
      } else if e == '\\' {
        out += "\\"
      } else if e == '/' {
        out += "/"
      } else if e == 'b' {
        out += "\u{0008}"
      } else if e == 'f' {
        out += "\u{000C}"
      } else if e == 'n' {
        out += "\n"
      } else if e == 'r' {
        out += "\r"
      } else if e == 't' {
        out += "\t"
      } else if e == 'u' {
        if p.pos + 4 >= p.chars.length() {
          return Err(JsonParseError::{
            message: "invalid unicode escape",
            position: p.pos,
          })
        }
        let hex = String::from_array(p.chars[p.pos + 1:p.pos + 5])
        match hex_to_int(hex) {
          None =>
            return Err(JsonParseError::{
              message: "invalid unicode escape",
              position: p.pos,
            })
          Some(code) => {
            out += String::from_array([code.unsafe_to_char()])
            p.pos += 4
          }
        }
      } else {
        return Err(JsonParseError::{
          message: "invalid escape",
          position: p.pos,
        })
      }
      p.pos += 1
    } else {
      out += "\{c}"
      p.pos += 1
    }
  }
  Err(JsonParseError::{ message: "unterminated string", position: p.pos, })
}

///|
/// hex 字符串转整数。
fn hex_to_int(s : String) -> Int32? {
  let mut val = 0
  for c in s.to_array() {
    let x = c.to_int()
    let d = if x >= 48 && x <= 57 {
      x - 48
    } else if x >= 97 && x <= 102 {
      x - 87
    } else if x >= 65 && x <= 70 {
      x - 55
    } else {
      return None
    }
    val = val * 16 + d
  }
  Some(val)
}

///|
/// 解析数组。
fn parse_array(p : Parser) -> Result[JsonValue, JsonParseError] {
  p.pos += 1 // '['
  let arr : Array[JsonValue] = []
  skip_ws(p)
  if p.pos < p.chars.length() && p.chars[p.pos] == ']' {
    p.pos += 1
    return Ok(Array(arr))
  }
  while true {
    match parse_value(p) {
      Err(e) => return Err(e)
      Ok(v) => arr.push(v)
    }
    skip_ws(p)
    if p.pos >= p.chars.length() {
      return Err(JsonParseError::{
        message: "unterminated array",
        position: p.pos,
      })
    }
    if p.chars[p.pos] == ',' {
      p.pos += 1
      continue
    }
    if p.chars[p.pos] == ']' {
      p.pos += 1
      return Ok(Array(arr))
    }
    return Err(JsonParseError::{ message: "expected , or ]", position: p.pos, })
  }
  Ok(Array(arr)) // unreachable；满足 while 作为末表达式的类型检查
}

///|
/// 解析对象（保序 + 拒重复键）。
fn parse_object(p : Parser) -> Result[JsonValue, JsonParseError] {
  p.pos += 1 // '{'
  let obj : Array[(String, JsonValue)] = []
  let keys : Array[String] = []
  skip_ws(p)
  if p.pos < p.chars.length() && p.chars[p.pos] == '}' {
    p.pos += 1
    return Ok(Object(obj))
  }
  while true {
    skip_ws(p)
    if p.pos >= p.chars.length() || p.chars[p.pos] != '"' {
      return Err(JsonParseError::{
        message: "expected object key",
        position: p.pos,
      })
    }
    let key = match parse_string(p) {
      Err(e) => return Err(e)
      Ok(s) => s
    }
    if keys.contains(key) {
      return Err(JsonParseError::{
        message: "duplicate key: " + key,
        position: p.pos,
      })
    }
    keys.push(key)
    skip_ws(p)
    if p.pos >= p.chars.length() || p.chars[p.pos] != ':' {
      return Err(JsonParseError::{ message: "expected :", position: p.pos, })
    }
    p.pos += 1
    let value = match parse_value(p) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    obj.push((key, value))
    skip_ws(p)
    if p.pos >= p.chars.length() {
      return Err(JsonParseError::{
        message: "unterminated object",
        position: p.pos,
      })
    }
    if p.chars[p.pos] == ',' {
      p.pos += 1
      continue
    }
    if p.chars[p.pos] == '}' {
      p.pos += 1
      return Ok(Object(obj))
    }
    return Err(JsonParseError::{ message: "expected , or }", position: p.pos, })
  }
  Ok(Object(obj)) // unreachable
}

///|
/// 解析数字（保留原始文本）。
fn parse_number(p : Parser) -> Result[JsonValue, JsonParseError] {
  let start = p.pos
  if p.chars[p.pos] == '-' {
    p.pos += 1
  }
  while p.pos < p.chars.length() {
    let x = p.chars[p.pos].to_int()
    if (x >= 48 && x <= 57) ||
      p.chars[p.pos] == '.' ||
      p.chars[p.pos] == 'e' ||
      p.chars[p.pos] == 'E' ||
      p.chars[p.pos] == '+' ||
      p.chars[p.pos] == '-' {
      p.pos += 1
    } else {
      break
    }
  }
  let raw = String::from_array(p.chars[start:p.pos])
  Ok(Number(raw))
}

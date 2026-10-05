//! 两种清单语法共享有界反序列化；在递归进入前拒绝深度/重复键，不先构建无限Value。
use super::{CoreError, Manifest, error};
use serde::{
    Deserialize, Deserializer,
    de::{self, DeserializeSeed, MapAccess, SeqAccess, Visitor},
};
use serde_json::{Map, Number, Value};
use std::fmt;

const MAX_DEPTH: usize = 32;
const MAX_ITEMS: usize = 1024;
#[path = "hjson_strings.rs"]
mod hjson_strings;
struct Root(Value);
impl<'de> Deserialize<'de> for Root {
    fn deserialize<D: Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        d.deserialize_map(Bounded(0)).map(Self)
    }
}
struct Bounded(usize);
impl<'de> DeserializeSeed<'de> for Bounded {
    type Value = Value;
    fn deserialize<D: Deserializer<'de>>(self, d: D) -> Result<Value, D::Error> {
        if self.0 >= MAX_DEPTH {
            return Err(de::Error::custom("manifest depth limit"));
        }
        d.deserialize_any(self)
    }
}
impl<'de> Visitor<'de> for Bounded {
    type Value = Value;
    fn expecting(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("bounded manifest value")
    }
    fn visit_bool<E: de::Error>(self, value: bool) -> Result<Value, E> {
        Ok(Value::Bool(value))
    }
    fn visit_i64<E: de::Error>(self, value: i64) -> Result<Value, E> {
        Ok(value.into())
    }
    fn visit_u64<E: de::Error>(self, value: u64) -> Result<Value, E> {
        Ok(value.into())
    }
    fn visit_f64<E: de::Error>(self, value: f64) -> Result<Value, E> {
        Number::from_f64(value)
            .map(Value::Number)
            .ok_or_else(|| E::custom("non-finite manifest value"))
    }
    fn visit_str<E: de::Error>(self, value: &str) -> Result<Value, E> {
        self.visit_string(value.to_owned())
    }
    fn visit_string<E: de::Error>(self, value: String) -> Result<Value, E> {
        Ok(Value::String(value))
    }
    fn visit_none<E: de::Error>(self) -> Result<Value, E> {
        Ok(Value::Null)
    }
    fn visit_unit<E: de::Error>(self) -> Result<Value, E> {
        Ok(Value::Null)
    }
    fn visit_seq<A: SeqAccess<'de>>(self, mut sequence: A) -> Result<Value, A::Error> {
        let mut values = Vec::new();
        while let Some(value) = sequence.next_element_seed(Bounded(self.0 + 1))? {
            if values.len() >= MAX_ITEMS {
                return Err(de::Error::custom("manifest item limit"));
            }
            values.push(value);
        }
        Ok(Value::Array(values))
    }
    fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<Value, A::Error> {
        let mut values = Map::new();
        while let Some(key) = map.next_key::<String>()? {
            if values.len() >= MAX_ITEMS || key.len() > 4096 || values.contains_key(&key) {
                return Err(de::Error::custom("manifest item or duplicate key limit"));
            }
            values.insert(key, map.next_value_seed(Bounded(self.0 + 1))?);
        }
        Ok(Value::Object(values))
    }
}
pub(super) fn parse(bytes: &[u8], hjson: bool) -> Result<Manifest, CoreError> {
    let root: Root = if hjson {
        let text = std::str::from_utf8(bytes).map_err(|_| error("扩展清单必须为UTF-8"))?;
        let text = hjson_strings::normalize(text)?;
        serde_hjson::from_str(&text).map_err(|_| error("扩展HJSON清单无效或超过限制"))?
    } else {
        serde_json::from_slice(bytes).map_err(|_| error("扩展JSON清单无效或超过限制"))?
    };
    serde_json::from_value(root.0).map_err(|_| error("扩展清单字段无效"))
}

//! 与旧 ProviderUsageSnapshot 一致：细分异常不丢弃有效输入/输出总量。
use super::{ChatEvent, ChatFailure};
use serde_json::Value;

fn present<'a>(value: &'a Value, key: &str) -> Option<&'a Value> {
    value.get(key).filter(|value| !value.is_null())
}

fn count(value: &Value) -> Option<u64> {
    value.as_u64().filter(|value| *value <= i64::MAX as u64)
}

pub(super) fn parse(value: &Value) -> Result<ChatEvent, ChatFailure> {
    let hit = present(value, "prompt_cache_hit_tokens");
    let miss = present(value, "prompt_cache_miss_tokens");
    let input = present(value, "prompt_tokens").or_else(|| present(value, "input_tokens"));
    let input = match input {
        Some(input) => count(input),
        None => hit
            .and_then(count)
            .zip(miss.and_then(count))
            .and_then(|(hit, miss)| hit.checked_add(miss))
            .filter(|value| *value <= i64::MAX as u64),
    }
    .ok_or_else(ChatFailure::protocol)?;
    let output = present(value, "completion_tokens")
        .or_else(|| present(value, "output_tokens"))
        .and_then(count)
        .ok_or_else(ChatFailure::protocol)?;
    let details = value
        .get("prompt_tokens_details")
        .filter(|value| value.is_object())
        .or_else(|| value.get("input_tokens_details"))
        .unwrap_or(&Value::Null);
    let read = hit
        .or_else(|| present(details, "cached_tokens"))
        .or_else(|| present(value, "cached_tokens"));
    let write = present(details, "cache_write_tokens");
    let read_count = read.map(count).unwrap_or(Some(0));
    let write_count = write.map(count).unwrap_or(Some(0));
    let valid = (read.is_some() || write.is_some())
        && read_count
            .zip(write_count)
            .is_some_and(|(r, w)| r <= input && w <= input - r)
        && miss.is_none_or(|miss| {
            hit.and_then(count)
                .zip(count(miss))
                .is_some_and(|(h, m)| h.checked_add(m) == Some(input))
        });
    let reasoning = value
        .pointer("/completion_tokens_details/reasoning_tokens")
        .and_then(count)
        .or_else(|| {
            value
                .pointer("/output_tokens_details/reasoning_tokens")
                .and_then(count)
        })
        .filter(|reasoning| *reasoning <= output);
    Ok(ChatEvent::Usage {
        input,
        output,
        // 旧统计总量是输入+输出；不能把推理细分再相加。
        total: input.saturating_add(output),
        cache_read: valid.then_some(read_count.unwrap_or(0)),
        cache_write: if valid && write.is_some() {
            write_count
        } else {
            None
        },
        reasoning,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn chat_responses_aliases_zero_and_unknown() {
        for value in [
            json!({"prompt_tokens":100,"completion_tokens":30,"prompt_tokens_details":{"cached_tokens":60,"cache_write_tokens":10},"completion_tokens_details":{"reasoning_tokens":20}}),
            json!({"input_tokens":100,"output_tokens":30,"input_tokens_details":{"cached_tokens":60,"cache_write_tokens":10},"output_tokens_details":{"reasoning_tokens":20}}),
            json!({"prompt_cache_hit_tokens":60,"prompt_cache_miss_tokens":40,"output_tokens":30,"input_tokens_details":{"cache_write_tokens":10},"output_tokens_details":{"reasoning_tokens":20}}),
        ] {
            assert_eq!(
                parse(&value).unwrap(),
                ChatEvent::Usage {
                    input: 100,
                    output: 30,
                    total: 130,
                    cache_read: Some(60),
                    cache_write: Some(10),
                    reasoning: Some(20)
                }
            );
        }
        assert!(matches!(
            parse(&json!({"input_tokens":0,"output_tokens":0,"cached_tokens":0})).unwrap(),
            ChatEvent::Usage {
                cache_read: Some(0),
                cache_write: None,
                reasoning: None,
                ..
            }
        ));
        assert!(matches!(
            parse(&json!({"input_tokens":0,"output_tokens":0})).unwrap(),
            ChatEvent::Usage {
                cache_read: None,
                ..
            }
        ));
    }

    #[test]
    fn bad_cache_buckets_preserve_totals_without_fabricating_hits() {
        for details in [
            json!({"cached_tokens":101}),
            json!({"cached_tokens":-1}),
            json!({"cached_tokens":"60"}),
            json!({"cached_tokens":60,"cache_write_tokens":41}),
            json!({"cached_tokens":60,"cache_write_tokens":false}),
            json!({"cached_tokens":18446744073709551615u64}),
        ] {
            assert!(matches!(parse(&json!({"input_tokens":100,"output_tokens":30,"input_tokens_details":details,"output_tokens_details":{"reasoning_tokens":31}})).unwrap(),ChatEvent::Usage {input:100,output:30,cache_read:None,cache_write:None,reasoning:None,..}));
        }
        assert!(matches!(parse(&json!({"input_tokens":100,"output_tokens":30,"prompt_cache_hit_tokens":60,"prompt_cache_miss_tokens":41})).unwrap(),ChatEvent::Usage {cache_read:None,..}));
        for value in [
            json!({"input_tokens":-1,"output_tokens":1}),
            json!({"input_tokens":18446744073709551615u64,"output_tokens":1}),
        ] {
            assert!(parse(&value).is_err());
        }
    }
}

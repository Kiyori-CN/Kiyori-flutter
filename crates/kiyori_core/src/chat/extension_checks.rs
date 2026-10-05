//! 旧密钥池调用testConnection，发送前窗口调用calculateInputTokens；均沿同取消与包租约。
use super::*;

pub(super) async fn count(
    binding: &Binding,
    call: extensions::Invocation,
    host: Arc<ModelHttpHost>,
    token: &CancellationToken,
    sender: &EventSender,
    permit: Option<Arc<limits::Permit>>,
) -> Result<i64, ChatFailure> {
    let value = single(binding, call, host, token, sender, permit).await?;
    token_count(&value).ok_or_else(protocol)
}

pub(super) async fn connection(
    client: Arc<Client>,
    input: &mut ChatRequest,
    binding: &Binding,
    sender: &EventSender,
) -> Result<String, ChatFailure> {
    let draft = &input.extension.as_ref().ok_or_else(protocol)?.draft;
    let host = Arc::new(
        ModelHttpHost::with_client(client, draft, input.api_key.clone(), input.headers.clone())
            .map_err(failure)?,
    );
    let payload = json!({"config":host.config(draft,&input.model),"providerId":extensions::provider_parts(&input.provider).map_err(core_failure)?.1});
    let token = sender.cancellation.child_token();
    let _guard = token.clone().drop_guard();
    let call = invocation(
        binding,
        &input.provider,
        ProviderHandler::TestConnection,
        payload,
        input.timeout_ms,
        &token,
    )?;
    let work = async {
        let permit = match &input.admission {
            Some(gate) => Some(Arc::new(
                tokio::select! {biased; _=token.cancelled()=>return Err(interrupted()), permit=gate.acquire()=>permit},
            )),
            None => None,
        };
        let _ = sender.send(ChatEvent::Started).await;
        let value = single(binding, call, host, &token, sender, permit).await?;
        connection_result(&value)?;
        Ok("stop".into())
    };
    tokio::time::timeout(Duration::from_millis(input.timeout_ms.into()), work)
        .await
        .map_err(|_| {
            ChatFailure::new(ChatFailureKind::Timeout, "扩展连接测试超时；已等待资源释放")
        })?
}

async fn single(
    binding: &Binding,
    call: extensions::Invocation,
    host: Arc<ModelHttpHost>,
    token: &CancellationToken,
    sender: &EventSender,
    permit: Option<Arc<limits::Permit>>,
) -> Result<Value, ChatFailure> {
    let run = binding
        .scripts
        .clone()
        .start_owned(
            call.request,
            token.child_token(),
            Some(call.lease),
            Some(host),
        )
        .await
        .map_err(failure)?;
    let run = track(run, permit, sender);
    match run.next_event().await.map_err(failure)? {
        Some(ScriptEvent::Completed(value)) => Ok(value),
        Some(ScriptEvent::Failed(error)) => Err(failure(error)),
        // 计数/连接不能把中间输出伪装成最终成功，也不能发布聊天正文。
        _ => Err(protocol()),
    }
}

fn connection_result(value: &Value) -> Result<(), ChatFailure> {
    let accepted = match value {
        Value::Bool(success) => *success,
        Value::String(text) => !text.contains('\0'),
        Value::Object(object) => {
            !object.contains_key("error")
                && match object.get("success") {
                    None => true,
                    Some(Value::Bool(success)) => *success,
                    _ => false,
                }
        }
        _ => false,
    };
    if accepted { Ok(()) } else { Err(protocol()) }
}

fn token_count(value: &Value) -> Option<i64> {
    if value.get("error").is_some() || value.get("success") == Some(&Value::Bool(false)) {
        return None;
    }
    if let Some(object) = value.as_object() {
        return ["tokens", "inputTokens", "count"]
            .iter()
            .find_map(|key| object.get(*key).and_then(decimal_count));
    }
    decimal_count(value)
}

fn decimal_count(value: &Value) -> Option<i64> {
    let text = match value {
        Value::Number(number) => number.to_string(),
        Value::String(text) => text.trim().to_owned(),
        _ => return None,
    };
    if text.is_empty() || text.len() > 4096 {
        return None;
    }
    let (negative, text) = match text.as_bytes()[0] {
        b'-' => (true, &text[1..]),
        b'+' => (false, &text[1..]),
        _ => (false, text.as_str()),
    };
    let (mantissa, exponent) = if let Some((mantissa, raw)) = text.split_once(['e', 'E']) {
        let (sign, digits) = match raw.as_bytes().first()? {
            b'-' => (-1, &raw[1..]),
            b'+' => (1, &raw[1..]),
            _ => (1, raw),
        };
        if digits.is_empty() || !digits.bytes().all(|c| c.is_ascii_digit()) {
            return None;
        }
        let power = digits.bytes().fold(0i64, |v, c| {
            v.saturating_mul(10).saturating_add((c - b'0') as i64)
        });
        (mantissa, power.saturating_mul(sign))
    } else {
        (text, 0)
    };
    let (integer, fraction) = mantissa.split_once('.').unwrap_or((mantissa, ""));
    if integer.is_empty() && fraction.is_empty()
        || !integer
            .bytes()
            .chain(fraction.bytes())
            .all(|c| c.is_ascii_digit())
    {
        return None;
    }
    // 与旧BigDecimal一致，截断小数、负值置零、上限Int.MAX_VALUE；不经过f64舍入边界。
    if negative {
        return Some(0);
    }
    let places = (integer.len() as i64).saturating_add(exponent);
    if places <= 0 {
        return Some(0);
    }
    let mut result = 0i64;
    let mut consumed = 0i64;
    for digit in integer.bytes().chain(fraction.bytes()) {
        if consumed >= places {
            break;
        }
        result = result
            .saturating_mul(10)
            .saturating_add((digit - b'0') as i64)
            .min(i32::MAX as i64);
        consumed += 1;
    }
    if result > 0 {
        for _ in 0..places.saturating_sub(consumed).min(10) {
            result = result.saturating_mul(10).min(i32::MAX as i64);
        }
    }
    Some(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn legacy_decimal_counts_truncate_clamp_and_accept_aliases_without_float_rounding() {
        for (value, expected) in [
            (json!(7), 7),
            (json!(1.9), 1),
            (json!(-2), 0),
            (json!("1.25e3"), 1250),
            (json!("2147483646.9999999999"), 2147483646),
            (json!("1e9999"), i32::MAX as i64),
            (json!("0e999999"), 0),
            (json!("+000.75e1"), 7),
            (json!({"inputTokens":"12"}), 12),
            (json!({"tokens":null,"count":0}), 0),
        ] {
            assert_eq!(token_count(&value), Some(expected), "{value}");
        }
        for value in [
            json!("NaN"),
            json!("inf"),
            json!("1e"),
            json!("1.2.3"),
            json!(true),
            json!([]),
            json!({}),
            json!({"success":false,"tokens":7}),
            json!({"error":"failed","tokens":7}),
        ] {
            assert_eq!(token_count(&value), None, "{value}");
        }
    }
    #[test]
    fn connection_accepts_legacy_shapes_and_rejects_false_or_malformed_results() {
        for value in [
            json!(true),
            json!(""),
            json!({"success":true}),
            json!({"message":"ready"}),
        ] {
            assert!(connection_result(&value).is_ok());
        }
        for value in [
            json!(false),
            json!(null),
            json!([]),
            json!({"success":"true"}),
            json!({"success":false}),
            json!({"success":true,"error":"failed"}),
        ] {
            assert!(connection_result(&value).is_err());
        }
    }
}

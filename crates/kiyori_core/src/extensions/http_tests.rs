use super::*;
use std::{
    io::{Read, Write},
    net::TcpListener,
    sync::atomic::AtomicBool,
};
fn draft(endpoint: String) -> ModelConfigDraft {
    ModelConfigDraft {
        name: "fixture".into(),
        provider: "TOOLPKG:fixture:provider".into(),
        protocol: "chat".into(),
        endpoint,
        models: vec!["fixture".into()],
        options: Default::default(),
    }
}
fn request(url: &str, method: &str, stream: bool) -> Value {
    json!({"url":url,"method":method,"headers":{"Authorization":format!("Bearer {KEY_REFERENCE}"),"Content-Type":"application/json"},"body":if method=="GET"{Value::Null}else{json!("{\"messages\":[]}")},"stream":stream,"timeoutMs":3000})
}
#[tokio::test]
async fn constrained_urls_headers_body_and_missing_authority_fail_before_network() {
    let runtime = Runtime::new();
    let host = ModelHttpHost::new(
        &runtime,
        &draft("https://example.test/v1/chat/completions".into()),
        "fixture-secret".into(),
        vec![("x-api-key".into(), "header-secret".into())],
    )
    .unwrap();
    let configuration = host.config(&draft(host.generation.to_string()), "fixture");
    assert!(!configuration.to_string().contains("fixture-secret"));
    assert!(!configuration.to_string().contains("header-secret"));
    for (url, method, stream) in [
        ("https://other.test/v1/models", "GET", false),
        ("https://example.test/other", "GET", false),
        ("https://example.test/v1/models?key=x", "GET", false),
        ("https://example.test/v1/models", "DELETE", false),
        ("https://example.test/v1/models", "GET", true),
    ] {
        assert!(host.checked(request(url, method, stream)).is_err());
    }
    let good = request(host.directory.as_str(), "GET", false);
    let (_, _, headers) = host.checked(good.clone()).unwrap();
    assert_eq!(headers["authorization"], "Bearer fixture-secret");
    assert_eq!(headers["x-api-key"], "header-secret");
    for (name, value) in [
        ("Authorization", "Bearer forged"),
        ("Host", "other.test"),
        ("X-Api-Key", "forged"),
        ("Content-Type", "application/octet-stream"),
    ] {
        let mut forged = good.clone();
        forged["headers"][name] = json!(value);
        assert!(host.checked(forged).is_err());
    }
    let mut body = request(host.generation.as_str(), "POST", true);
    body["body"] = json!(KEY_REFERENCE);
    assert!(host.checked(body).is_err());
    assert!(
        ModelHttpHost::new(
            &runtime,
            &draft("http://remote.test/v1".into()),
            String::new(),
            vec![]
        )
        .is_err()
    );
    runtime.close();
}
#[test]
fn utf8_and_secret_echoes_are_checked_across_every_fragment() {
    let secrets = vec![b"fixture-secret".to_vec()];
    for split in 0..=14 {
        let text = b"fixture-secret";
        let mut guard = TextGuard::new(&secrets);
        assert_eq!(guard.push(&text[..split], false).is_err(), split == 14);
        if split < 14 {
            assert!(guard.push(&text[split..], true).is_err());
        }
    }
    let mut guard = TextGuard::new(&secrets);
    let text = "完整中文流片段，保留全部内容";
    let mut result = String::new();
    for byte in text.as_bytes() {
        result.push_str(&guard.push(&[*byte], false).unwrap());
    }
    result.push_str(&guard.push(&[], true).unwrap());
    assert_eq!(result, text);
    assert!(TextGuard::new(&[]).push(&[0xff], true).is_err());
    let text = "中".repeat(30000);
    let mut result = String::new();
    deliver(&text, &mut |part| {
        assert!(part.len() <= 64 * 1024);
        result.push_str(part);
        true
    })
    .unwrap();
    assert_eq!(result, text);
}
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn real_http_uses_shared_client_and_cancels_stalled_body() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = format!(
        "http://{}/v1/chat/completions",
        listener.local_addr().unwrap()
    );
    let server = std::thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
        socket
            .set_read_timeout(Some(Duration::from_secs(5)))
            .unwrap();
        let mut bytes = Vec::new();
        let mut part = [0; 1024];
        while !bytes.windows(4).any(|w| w == b"\r\n\r\n") {
            let n = socket.read(&mut part).unwrap();
            assert!(n > 0);
            bytes.extend_from_slice(&part[..n]);
        }
        let headers = String::from_utf8(bytes).unwrap();
        assert!(
            headers
                .to_lowercase()
                .contains("authorization: bearer fixture-secret")
        );
        assert!(!headers.contains(KEY_REFERENCE));
        socket
            .write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 10000\r\n\r\nfirst-chunk-more-than-key")
            .unwrap();
        socket.flush().unwrap();
        // 客户端取消必须关闭连接，服务器无需人为结束body。
        let mut byte = [0];
        assert_eq!(socket.read(&mut byte).unwrap(), 0);
    });
    let runtime = Runtime::new();
    let host =
        ModelHttpHost::new(&runtime, &draft(endpoint), "fixture-secret".into(), vec![]).unwrap();
    assert!(Arc::ptr_eq(
        &host.client,
        runtime.chat_client.get().unwrap().as_ref().unwrap()
    ));
    let input = request(host.generation.as_str(), "POST", true);
    let stopped = Arc::new(AtomicBool::new(false));
    let cancel = stopped.clone();
    let result = tokio::task::spawn_blocking(move || {
        host.request(input, &|| cancel.load(Ordering::Acquire), &mut |text| {
            assert!(!text.contains("fixture-secret"));
            cancel.store(true, Ordering::Release);
            true
        })
    })
    .await
    .unwrap();
    assert_eq!(result.unwrap_err().kind, ScriptFailureKind::Cancelled);
    server.join().unwrap();
    runtime.close();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn redirects_oversized_bodies_and_reflected_credentials_never_reach_script() {
    for (response, expected) in [
        (
            "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:1/private\r\nContent-Length: 0\r\n\r\n",
            ScriptFailureKind::Execution,
        ),
        (
            "HTTP/1.1 200 OK\r\nContent-Length: 99999999\r\n\r\n",
            ScriptFailureKind::OutputLimit,
        ),
        (
            "HTTP/1.1 200 OK\r\nContent-Length: 14\r\n\r\nfixture-secret",
            ScriptFailureKind::Protocol,
        ),
    ] {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let endpoint = format!("http://{}/v1", listener.local_addr().unwrap());
        let server = std::thread::spawn(move || {
            let (mut socket, _) = listener.accept().unwrap();
            let mut bytes = vec![];
            let mut part = [0; 1024];
            while !bytes.windows(4).any(|w| w == b"\r\n\r\n") {
                let n = socket.read(&mut part).unwrap();
                assert!(n > 0);
                bytes.extend_from_slice(&part[..n]);
            }
            socket.write_all(response.as_bytes()).unwrap();
        });
        let runtime = Runtime::new();
        let host = ModelHttpHost::new(&runtime, &draft(endpoint), "fixture-secret".into(), vec![])
            .unwrap();
        let input = request(host.directory.as_str(), "GET", false);
        let result = tokio::task::spawn_blocking(move || {
            host.request(input, &|| false, &mut |_| {
                panic!("unexpected script content")
            })
        })
        .await
        .unwrap();
        assert_eq!(result.unwrap_err().kind, expected);
        server.join().unwrap();
        runtime.close();
    }
}

use super::*;

fn archive(entries: Vec<(&str, Vec<u8>)>) -> Vec<u8> {
    let mut zip = ZipWriter::new(Cursor::new(Vec::new()));
    for (name, value) in entries {
        zip.start_file(name, SimpleFileOptions::default()).unwrap();
        zip.write_all(&value).unwrap();
    }
    zip.finish().unwrap().into_inner()
}
fn streamed_package(zip64: bool) -> Vec<u8> {
    let mut writer = ZipWriter::new_stream(Vec::new());
    let options = SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .large_file(zip64);
    writer.start_file("manifest.json", options).unwrap();
    writer
        .write_all(&json_manifest("streamed", "main.js"))
        .unwrap();
    writer.start_file("main.js", options).unwrap();
    writer
        .write_all(b"exports.registerToolPkg=function(){};")
        .unwrap();
    writer.finish().unwrap().into_inner()
}

#[tokio::test]
async fn streamed_descriptor_packages_validate_sizes_crc_and_reject_hidden_entries() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    for zip64 in [false, true] {
        let bytes = streamed_package(zip64);
        let p = install(&r, bytes.clone()).await.unwrap();
        assert_eq!(p.id, "streamed");
        let (header, data, end) = {
            let mut zip = zip::ZipArchive::new(Cursor::new(&bytes)).unwrap();
            let f = zip.by_index(0).unwrap();
            (
                f.header_start() as usize,
                f.data_start().unwrap() as usize,
                (f.data_start().unwrap() + f.compressed_size()) as usize,
            )
        };
        for offset in [header + 6, header + 14, header + 30, data, end + 4] {
            let mut damaged = bytes.clone();
            damaged[offset] ^= 1;
            assert!(
                install(&r, damaged).await.is_err(),
                "zip64={zip64} offset={offset}"
            );
            assert_eq!(r.extension_packages().unwrap()[0].revision, p.revision);
        }
    }
    let mut bytes = package("hidden", "1.0.0", vec![]);
    let zip = zip::ZipArchive::new(Cursor::new(&bytes)).unwrap();
    let central = zip.central_directory_start() as usize;
    let local = bytes[..central].to_vec();
    bytes.splice(central..central, local.clone());
    let eocd = bytes.len() - 22;
    bytes[eocd + 16..eocd + 20].copy_from_slice(&((central + local.len()) as u32).to_le_bytes());
    assert!(install(&r, bytes).await.is_err());
    r.close();
}
fn json_manifest(id: &str, main: &str) -> Vec<u8> {
    json!({"toolpkg_id":id,"main":main})
        .to_string()
        .into_bytes()
}
fn hjson_manifest(id: &str, main: &str) -> Vec<u8> {
    format!("# legacy braceless manifest\ntoolpkg_id: '{id}'\nmain: '{main}'\napi_version: 1.0.0\nauthor: [ '甲', '乙' ]\ndisplay_name: {{ zh: '测试包😀' }}\ndescription: '''\n  第一行😀\n  第二行\n'''\n").into_bytes()
}

#[tokio::test]
async fn single_quoted_strings_comments_and_unquoted_apostrophes_preserve_text() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    let text = r#"
// unmatched quote ' in a comment must remain inert
'toolpkg_id': 'quotes'
main: 'main.js'
author: [
  '甲😀'
  'it\'s "quoted"'
]
/* comment with ''' and an unmatched ' */
display_name: "double ' remains"
enabled_by_default: true # comment with '
description: it's: still 'raw', # belongs to unquoted text
category: '''
  多行😀 with ' and "
  第二行
'''
"#;
    let bytes = archive(vec![
        ("manifest.hjson", text.as_bytes().to_vec()),
        ("main.js", b"exports.registerToolPkg=function(){};".to_vec()),
    ]);
    let p = install(&r, bytes).await.unwrap();
    assert_eq!(p.name, "double ' remains");
    assert_eq!(
        p.description,
        "it's: still 'raw', # belongs to unquoted text"
    );
    let details = r.extension_details(p.id, p.revision).await.unwrap();
    assert_eq!(details.authors, ["甲😀", "it's \"quoted\""]);
    assert_eq!(details.category, "多行😀 with ' and \"\n第二行");
    for text in [
        "toolpkg_id: 'unfinished\n",
        "toolpkg_id: 'bad\\q'\n",
        "toolpkg_id: 'x'\nmain: 'a\\😀'\n",
        "toolpkg_id: 'x'\nmain: 'main.js'\ncategory: '''unterminated",
    ] {
        assert!(
            install(
                &r,
                archive(vec![
                    ("manifest.hjson", text.as_bytes().to_vec()),
                    ("main.js", b"x".to_vec())
                ])
            )
            .await
            .is_err()
        );
    }
    r.close();
}

#[tokio::test]
async fn legacy_manifest_selection_defaults_hjson_and_relative_entry_survive_reopen() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    let candidates = [
        (
            "manifest.hjson",
            hjson_manifest("root_hjson", "dist/main.js"),
        ),
        ("manifest.json", json_manifest("root_json", "dist/main.js")),
        (
            "a/manifest.hjson",
            hjson_manifest("a_hjson", "dist/main.js"),
        ),
        (
            "b/manifest.hjson",
            hjson_manifest("b_hjson", "dist/main.js"),
        ),
        (
            "a/deep/manifest.hjson",
            hjson_manifest("deep", "dist/main.js"),
        ),
        ("a/manifest.json", json_manifest("a_json", "dist/main.js")),
    ];
    for (skip, expected) in [
        (0, "root_hjson"),
        (1, "root_json"),
        (2, "a_hjson"),
        (3, "b_hjson"),
        (5, "a_json"),
    ] {
        let mut entries = candidates[skip..].to_vec();
        for name in [
            "dist/main.js",
            "a/dist/main.js",
            "b/dist/main.js",
            "a/deep/dist/main.js",
        ] {
            entries.push((name, b"exports.registerToolPkg=function(){};".to_vec()));
        }
        // 比所有嵌套候选更浅的依赖清单不得抢占产品清单。
        entries.push((
            "node_modules/manifest.hjson",
            hjson_manifest("dependency", "dist/main.js"),
        ));
        let p = install(&r, archive(entries)).await.unwrap();
        assert_eq!(p.id, expected);
        assert_eq!(p.version, "");
        let detail = r.extension_details(p.id.clone(), p.revision).await.unwrap();
        assert_eq!(detail.api_version, "1.0.0");
        if expected.ends_with("hjson") {
            assert_eq!(detail.authors, ["甲", "乙"]);
            assert_eq!(p.description, "第一行😀\n第二行");
        }
    }
    let bytes = archive(vec![
        (
            "Wrapped/MANIFEST.JSON",
            json!({"toolpkg_id":"case","version":"1.0.0-beta.1","main":"dist/MAIN.JS"})
                .to_string()
                .into_bytes(),
        ),
        (
            "Wrapped/dist/main.js",
            b"exports.registerToolPkg=function(){};".to_vec(),
        ),
    ]);
    let p = install(&r, bytes).await.unwrap();
    assert_eq!(p.version, "1.0.0-beta.1");
    let v2 = archive(vec![
        ("manifest.json",json!({"schema_version":2,"toolpkg_id":"distribution","main":"main.js","api_version":"1.0.1","distribution":{"include":["manifest.json","*.js"]}}).to_string().into_bytes()),
        ("main.js",b"exports.registerToolPkg=function(){};".to_vec()),
    ]);
    let v2 = install(&r, v2).await.unwrap();
    assert_eq!(
        r.extension_details(v2.id, v2.revision)
            .await
            .unwrap()
            .api_version,
        "1.0.1"
    );
    r.close();
    let reopened = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    assert_eq!(reopened.extension_packages().unwrap().len(), 7);
    assert_eq!(
        reopened
            .extension_details(p.id, p.revision)
            .await
            .unwrap()
            .api_version,
        "1.0.0"
    );
    reopened.close();
}

#[tokio::test]
async fn invalid_selected_manifest_never_falls_back_or_replaces_installed_package() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    let p = install(&r, package("fixture", "1.0.0", vec![]))
        .await
        .unwrap();
    for text in [
        "toolpkg_id: fixture\nmain: ../escape.js\n",
        "toolpkg_id: fixture\nmain: missing.js\n",
        "toolpkg_id: fixture\nmain: dist/main.js\napi_version: \"\"\n",
        "toolpkg_id: fixture\nmain: dist/main.js\napi_version: 9.0.0\n",
        "toolpkg_id: fixture\nmain: dist/main.js\nschema_version: 2\n",
        "toolpkg_id: fixture\nmain: dist/main.js\nenvironment: [ { name: \"A\", default: \"B\" } ]\n",
        "{ toolpkg_id: fixture\n main: dist/main.js\n",
    ] {
        let bytes = package(
            "fixture",
            "2.0.0",
            vec![("manifest.hjson", text.as_bytes().to_vec())],
        );
        assert!(install(&r, bytes).await.is_err(), "{text}");
        assert_eq!(r.extension_packages().unwrap()[0].revision, p.revision);
    }
    r.close();
}

#[tokio::test]
async fn manifest_duplicate_keys_deep_values_and_trailing_data_are_rejected_in_both_syntaxes() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    for filename in ["manifest.json", "manifest.hjson"] {
        let deep = format!(
            "{{\"toolpkg_id\":\"fixture\",\"main\":\"main.js\",\"logo\":{}0{}}}",
            "[".repeat(500),
            "]".repeat(500)
        );
        let wide = format!(
            "{{\"toolpkg_id\":\"fixture\",\"main\":\"main.js\",\"logo\":[{}]}}",
            vec!["0"; 1025].join(",")
        );
        for text in [
            r#"{"toolpkg_id":"fixture","toolpkg_id":"other","main":"main.js"}"#.to_owned(),
            r#"{"toolpkg_id":"fixture","main":"main.js","display_name":{"zh":"a","zh":"b"}}"#
                .to_owned(),
            r#"{"toolpkg_id":"fixture","main":"main.js"} unexpected"#.to_owned(),
            deep,
            wide,
        ] {
            let bytes = archive(vec![
                (filename, text.into_bytes()),
                ("main.js", b"exports.registerToolPkg=function(){};".to_vec()),
            ]);
            assert!(install(&r, bytes).await.is_err(), "{filename}");
            assert!(r.extension_packages().unwrap().is_empty());
        }
    }
    r.close();
}

#[tokio::test]
async fn deflate_and_directory_entries_work_but_symlinks_and_bombs_do_not_publish() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    let stored = package("fixture", "1.0.0", vec![]);
    let mut original = zip::ZipArchive::new(Cursor::new(&stored)).unwrap();
    let mut writer = ZipWriter::new(Cursor::new(Vec::new()));
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);
    writer.add_directory("dist/", options).unwrap();
    for index in 0..original.len() {
        let mut file = original.by_index(index).unwrap();
        writer.start_file(file.name(), options).unwrap();
        std::io::copy(&mut file, &mut writer).unwrap();
    }
    let p = install(&r, writer.finish().unwrap().into_inner())
        .await
        .unwrap();
    assert_eq!(p.id, "fixture");
    let mut writer = ZipWriter::new(Cursor::new(Vec::new()));
    writer
        .add_symlink("link", "dist/main.js", SimpleFileOptions::default())
        .unwrap();
    let bytes = writer.finish().unwrap().into_inner();
    assert!(install(&r, bytes).await.is_err());
    let mut writer = ZipWriter::new(Cursor::new(Vec::new()));
    writer.start_file("bomb.txt", options).unwrap();
    writer.write_all(&vec![b' '; 1024 * 1024]).unwrap();
    assert!(
        install(&r, writer.finish().unwrap().into_inner())
            .await
            .is_err()
    );
    assert_eq!(r.extension_packages().unwrap()[0].revision, 1);
    r.close();
}

#[tokio::test]
async fn cleanup_failure_is_observable_and_only_owned_files_are_recovered() {
    let dir = Directory::new();
    let r = runtime(&dir, Arc::new(AtomicUsize::new(0)));
    let p = install(&r, package("fixture", "1.0.0", vec![]))
        .await
        .unwrap();
    let root = r
        .persistent_store()
        .unwrap()
        .managed_path(&p.resource.id, "")
        .unwrap();
    std::fs::write(root.join("unknown.txt"), "preserve").unwrap();
    assert_eq!(
        r.change_extension(p.id.clone(), p.revision, None)
            .await
            .unwrap(),
        1
    );
    assert!(r.extension_packages().unwrap().is_empty());
    assert_eq!(
        std::fs::read_to_string(root.join("unknown.txt")).unwrap(),
        "preserve"
    );
    assert!(
        install(&r, package("fixture", "1.0.0", vec![]))
            .await
            .is_err()
    );
    assert!(root.join("source.js").exists());
    std::fs::remove_file(root.join("unknown.txt")).unwrap();
    let next = install(&r, package("fixture", "1.0.0", vec![]))
        .await
        .unwrap();
    assert_eq!(next.cleanup_pending, 0);
    assert_eq!(next.revision, 3);
    r.close();
}

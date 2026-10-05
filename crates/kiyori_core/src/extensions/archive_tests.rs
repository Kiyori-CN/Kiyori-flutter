use super::*;

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

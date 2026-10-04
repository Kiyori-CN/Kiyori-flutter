//! 开发验收入口：公开目录/模型，不使用API凭据；显式指定隔离数据目录与模型。
use kiyori_core::runtime::Runtime;
use std::{error::Error, path::PathBuf};
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 3 {
        return Err("usage: verify_local_model_download <absolute-test-data-dir> <model-name-or-catalog-only>".into());
    }
    let runtime = Runtime::with_data_dir(PathBuf::from(&args[1]))?;
    let models = runtime.refresh_local_models().await?;
    println!("catalog_entries={}", models.len());
    if args[2] == "catalog-only" {
        runtime.close();
        return Ok(());
    }
    if !models.iter().any(|m| m.name == args[2]) {
        return Err("selected model absent from real catalog".into());
    }
    let mut paused = false;
    loop {
        let run = runtime.download_local_model(args[2].clone()).await?;
        let mut terminal = None;
        while let Some(event) = run.next_event().await? {
            println!(
                "phase={} bytes={}/{} file={}/{}",
                event.phase, event.transferred, event.total, event.file_index, event.total_files
            );
            if !paused
                && event.phase == "running"
                && event.transferred >= 16 * 1024 * 1024
                && event.transferred < event.total
            {
                run.stop(false).await;
                paused = true;
            }
            if matches!(
                event.phase.as_str(),
                "completed" | "paused" | "failed" | "cancelled"
            ) {
                terminal = Some(event);
            }
        }
        if let Some(event) = terminal {
            if event.phase == "completed" {
                let path =
                    runtime.resource_file_path(event.resource.id.clone(), "config.json".into())?;
                println!(
                    "verified=true resumed={} config_readable={}",
                    paused,
                    std::path::Path::new(&path).is_file()
                );
                runtime.close();
                let reopened = Runtime::with_data_dir(PathBuf::from(&args[1]))?;
                assert!(
                    reopened
                        .transfers()?
                        .iter()
                        .any(|t| t.resource.id == event.resource.id && t.phase == "completed")
                );
                println!("reopen_restored=true");
                reopened.close();
                return Ok(());
            }
            if event.phase == "paused" && paused {
                continue;
            }
            return Err(
                format!("download did not complete: {} {}", event.phase, event.error).into(),
            );
        }
        return Err("transfer ended without terminal state".into());
    }
}

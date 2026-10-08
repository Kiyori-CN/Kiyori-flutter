use std::{
    env,
    path::{Path, PathBuf},
    process::Command,
};

fn run(command: &mut Command) {
    let status = command
        .status()
        .expect("Unable to start native model build tool");
    assert!(status.success(), "Native model build failed: {status}");
}
#[path = "../build_support/cmake.rs"]
mod cmake;

fn main() {
    println!("cargo:rustc-check-cfg=cfg(kiyori_native_models)");
    for name in [
        "CMAKE",
        "KIYORI_NATIVE_ARCHIVES",
        "KIYORI_NATIVE_JOBS",
        "KIYORI_NATIVE_BUILD_DIR",
        "ANDROID_NDK_HOME",
        "ANDROID_NDK_ROOT",
    ] {
        println!("cargo:rerun-if-env-changed={name}");
    }
    for name in ["cpp/CMakeLists.txt", "cpp/inference.cpp", "cpp/inference.h"] {
        println!("cargo:rerun-if-changed={name}");
    }
    let target = env::var("TARGET").unwrap();
    cmake::track_inputs(&target);
    if !(target.contains("windows-msvc") || target.contains("android")) {
        return;
    }
    // C++配置固定Release；Cargo check/test/Flutter的不同fingerprint共享原生缓存。
    let output = env::var_os("KIYORI_NATIVE_BUILD_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            let workspace =
                PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap()).join("../../..");
            let target_root = env::var_os("CARGO_TARGET_DIR")
                .map(PathBuf::from)
                .unwrap_or_else(|| workspace.join("target"));
            target_root.join("inference").join(&target)
        });
    std::fs::create_dir_all(&output).expect("Unable to create native model cache");
    let lock = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(output.join("build.lock"))
        .expect("Unable to open native build lock");
    lock.lock()
        .expect("Unable to lock native model build cache");
    let build = output.join("native-build");
    let install = output.join("native-install");
    let cmake = cmake::executable();
    let mut configure = Command::new(&cmake);
    configure
        .args(["-S", "cpp", "-B"])
        .arg(&build)
        .arg(format!("-DCMAKE_INSTALL_PREFIX={}", install.display()))
        .args([
            "-DCMAKE_BUILD_TYPE=Release",
            "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        ]);
    if let Some(archives) = env::var_os("KIYORI_NATIVE_ARCHIVES") {
        configure.arg(format!(
            "-DKIYORI_NATIVE_ARCHIVES={}",
            Path::new(&archives).display()
        ));
    }
    cmake::configure_target(&mut configure, &target);
    run(&mut configure);
    let jobs = env::var("KIYORI_NATIVE_JOBS").unwrap_or_else(|_| "4".into());
    run(Command::new(&cmake)
        .arg("--build")
        .arg(&build)
        .args([
            "--config",
            "Release",
            "--target",
            "kiyori_inference",
            "--parallel",
        ])
        .arg(jobs));
    run(Command::new(&cmake).arg("--install").arg(&build).args([
        "--config",
        "Release",
        "--component",
        "kiyori",
    ]));
    println!(
        "cargo:rustc-link-search=native={}",
        install.join("lib").display()
    );
    for library in [
        "kiyori_inference",
        "MNN",
        "llama",
        "ggml",
        "ggml-cpu",
        "ggml-base",
    ] {
        println!("cargo:rustc-link-lib=static={library}");
    }
    if target.contains("android") {
        println!("cargo:rustc-link-lib=c++_static");
        println!("cargo:rustc-link-lib=c++abi");
        println!("cargo:rustc-link-lib=log");
        println!("cargo:rustc-link-lib=android");
    }
    println!("cargo:rustc-cfg=kiyori_native_models");
}

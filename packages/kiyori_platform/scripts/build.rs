use std::{env, path::PathBuf, process::Command};

fn run(command: &mut Command) {
    let status = command
        .status()
        .expect("Unable to start native script build tool");
    assert!(status.success(), "Native script build failed: {status}");
}
#[path = "../build_support/cmake.rs"]
mod cmake;

fn main() {
    println!("cargo:rustc-check-cfg=cfg(kiyori_native_scripts)");
    for name in [
        "CMAKE",
        "KIYORI_SCRIPT_ARCHIVE",
        "KIYORI_SCRIPT_JOBS",
        "KIYORI_SCRIPT_BUILD_DIR",
        "ANDROID_NDK_HOME",
        "ANDROID_NDK_ROOT",
    ] {
        println!("cargo:rerun-if-env-changed={name}");
    }
    for name in ["cpp/CMakeLists.txt", "cpp/scripts.cpp", "cpp/scripts.h"] {
        println!("cargo:rerun-if-changed={name}");
    }
    let target = env::var("TARGET").unwrap();
    cmake::track_inputs(&target);
    if !(target.contains("windows-msvc") || target.contains("android")) {
        return;
    }
    let output = env::var_os("KIYORI_SCRIPT_BUILD_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            let workspace =
                PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap()).join("../../..");
            let target_root = env::var_os("CARGO_TARGET_DIR")
                .map(PathBuf::from)
                .unwrap_or_else(|| workspace.join("target"));
            target_root.join("native-scripts").join(&target)
        });
    std::fs::create_dir_all(&output).expect("Unable to create native script cache");
    let lock = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(output.join("build.lock"))
        .expect("Unable to open native script build lock");
    lock.lock().expect("Unable to lock native script cache");
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
    if let Some(archive) = env::var_os("KIYORI_SCRIPT_ARCHIVE") {
        configure.arg(format!(
            "-DKIYORI_SCRIPT_ARCHIVE={}",
            PathBuf::from(archive).display()
        ));
    }
    cmake::configure_target(&mut configure, &target);
    run(&mut configure);
    run(Command::new(&cmake)
        .arg("--build")
        .arg(&build)
        .args([
            "--config",
            "Release",
            "--target",
            "kiyori_scripts",
            "--parallel",
        ])
        .arg(env::var("KIYORI_SCRIPT_JOBS").unwrap_or_else(|_| "4".into())));
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
    println!("cargo:rustc-link-lib=static=kiyori_scripts");
    println!("cargo:rustc-link-lib=static=qjs");
    if target.contains("android") {
        for library in ["c++_static", "c++abi", "m", "dl"] {
            println!("cargo:rustc-link-lib={library}");
        }
    }
    println!("cargo:rustc-cfg=kiyori_native_scripts");
}

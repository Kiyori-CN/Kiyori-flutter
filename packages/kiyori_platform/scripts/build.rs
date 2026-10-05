use std::{env, path::PathBuf, process::Command};

fn run(command: &mut Command) {
    let status = command
        .status()
        .expect("Unable to start native script build tool");
    assert!(status.success(), "Native script build failed: {status}");
}
fn cmake() -> PathBuf {
    if let Some(path) = env::var_os("CMAKE") {
        return path.into();
    }
    if let Some(path) = env::var_os("PATH") {
        for directory in env::split_paths(&path) {
            let path = directory.join(if cfg!(windows) { "cmake.exe" } else { "cmake" });
            if path.is_file() {
                return path;
            }
        }
    }
    if cfg!(windows) {
        let programs = env::var_os("ProgramFiles(x86)")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                PathBuf::from(env::var_os("SYSTEMDRIVE").expect("Windows system drive missing"))
                    .join("Program Files (x86)")
            });
        let output = Command::new(programs.join("Microsoft Visual Studio/Installer/vswhere.exe"))
            .args(["-latest", "-products", "*", "-property", "installationPath"])
            .output()
            .expect("CMake missing and vswhere unavailable");
        let path = PathBuf::from(String::from_utf8_lossy(&output.stdout).trim())
            .join("Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe");
        if path.is_file() {
            return path;
        }
    }
    panic!("CMake is required; set CMAKE to its executable path");
}
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
    let cmake = cmake();
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
    if target.contains("android") {
        let triple = target.replace('-', "_");
        let compiler = PathBuf::from(
            env::var_os(format!("CXX_{triple}"))
                .or_else(|| env::var_os("CXX"))
                .expect("Android CXX compiler must be provided by Flutter/NDK"),
        );
        let ndk = env::var_os("ANDROID_NDK_HOME")
            .or_else(|| env::var_os("ANDROID_NDK_ROOT"))
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                compiler
                    .ancestors()
                    .find(|p| p.join("build/cmake/android.toolchain.cmake").is_file())
                    .expect("Android compiler path does not identify NDK")
                    .to_path_buf()
            });
        let abi = if target.starts_with("aarch64") {
            "arm64-v8a"
        } else if target.starts_with("x86_64") {
            "x86_64"
        } else {
            panic!("Unsupported Android script ABI")
        };
        configure
            .args(["-G", "Ninja"])
            .arg(format!(
                "-DCMAKE_TOOLCHAIN_FILE={}",
                ndk.join("build/cmake/android.toolchain.cmake").display()
            ))
            .arg(format!("-DANDROID_ABI={abi}"))
            .args(["-DANDROID_PLATFORM=android-24", "-DANDROID_STL=c++_static"]);
        if let Some(sdk) = env::var_os("ANDROID_HOME") {
            let ninja = PathBuf::from(sdk).join("cmake/3.22.1/bin/ninja.exe");
            if ninja.is_file() {
                configure.arg(format!("-DCMAKE_MAKE_PROGRAM={}", ninja.display()));
            }
        }
    } else {
        configure.args(["-A", "x64", "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL"]);
    }
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

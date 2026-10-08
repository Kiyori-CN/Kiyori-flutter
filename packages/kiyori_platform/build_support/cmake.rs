//! 两个原生 adapter 共用的工具发现和目标配置；不启用尚未接入的平台后端。
use std::{env, path::PathBuf, process::Command};

pub fn executable() -> PathBuf {
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
    // 官方 VS 工具发现，不写本机盘符到项目构建契约。
    if cfg!(windows) {
        // Dart hooks仅保留少量宿主环境变量；SystemDrive仍可定位Windows标准安装器。
        let programs = env::var_os("ProgramFiles(x86)")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                PathBuf::from(env::var_os("SYSTEMDRIVE").expect("Windows system drive missing"))
                    .join("Program Files (x86)")
            });
        let vswhere = programs.join("Microsoft Visual Studio/Installer/vswhere.exe");
        let output = Command::new(vswhere)
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
pub fn configure_target(command: &mut Command, target: &str) {
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
        command
            .args(["-G", "Ninja"])
            .arg(format!(
                "-DCMAKE_TOOLCHAIN_FILE={}",
                ndk.join("build/cmake/android.toolchain.cmake").display()
            ))
            .arg(format!("-DANDROID_ABI={}", android_abi(target)))
            .args(["-DANDROID_PLATFORM=android-24", "-DANDROID_STL=c++_static"]);
        // Ninja 使用宿主可执行文件名；未安装此 SDK 版本时交由 PATH 解析。
        if let Some(sdk) = env::var_os("ANDROID_HOME").or_else(|| env::var_os("ANDROID_SDK_ROOT")) {
            let ninja = PathBuf::from(sdk)
                .join("cmake/3.22.1/bin")
                .join(if cfg!(windows) { "ninja.exe" } else { "ninja" });
            if ninja.is_file() {
                command.arg(format!("-DCMAKE_MAKE_PROGRAM={}", ninja.display()));
            }
        }
    } else {
        command.args([
            "-A",
            windows_arch(target),
            "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL",
        ]);
    }
}

fn android_abi(target: &str) -> &'static str {
    match target {
        "aarch64-linux-android" => "arm64-v8a",
        "x86_64-linux-android" => "x86_64",
        _ => panic!("Unsupported Android native ABI: {target}"),
    }
}

fn windows_arch(target: &str) -> &'static str {
    match target {
        "x86_64-pc-windows-msvc" => "x64",
        // 未验收目标明确失败，不能误链接 x64 库。
        _ => panic!("Unsupported Windows native target: {target}"),
    }
}

pub fn track_inputs(target: &str) {
    println!("cargo:rerun-if-changed=../build_support/cmake.rs");
    for name in [
        "PATH",
        "CMAKE",
        "ANDROID_HOME",
        "ANDROID_SDK_ROOT",
        "ANDROID_NDK_HOME",
        "ANDROID_NDK_ROOT",
        "CXX",
        "CARGO_TARGET_DIR",
    ] {
        println!("cargo:rerun-if-env-changed={name}");
    }
    println!(
        "cargo:rerun-if-env-changed=CXX_{}",
        target.replace('-', "_")
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn android_targets_preserve_abi() {
        assert_eq!(android_abi("aarch64-linux-android"), "arm64-v8a");
        assert_eq!(android_abi("x86_64-linux-android"), "x86_64");
    }
    #[test]
    fn windows_configuration_uses_msvc_x64() {
        let mut command = Command::new("cmake");
        configure_target(&mut command, "x86_64-pc-windows-msvc");
        let args: Vec<_> = command.get_args().map(|s| s.to_str().unwrap()).collect();
        assert_eq!(
            args,
            ["-A", "x64", "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL"]
        );
    }
    #[test]
    #[should_panic(expected = "Unsupported Windows native target")]
    fn windows_arm64_never_links_x64() {
        windows_arch("aarch64-pc-windows-msvc");
    }
    #[test]
    #[should_panic(expected = "Unsupported Android native ABI")]
    fn android_arm32_is_not_assumed_arm64() {
        android_abi("armv7-linux-androideabi");
    }
}

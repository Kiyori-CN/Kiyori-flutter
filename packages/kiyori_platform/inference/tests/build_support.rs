// 构建脚本本身不被 cargo test 执行，复用同一模块验证目标选择。
#[allow(dead_code)]
#[path = "../../build_support/cmake.rs"]
mod cmake;

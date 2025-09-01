fn main() {
    let crate_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    let out = format!("{}/bindings/include/rust_core.h", crate_dir);
    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_config(cbindgen::Config::from_file("bindings/cbindgen.toml").unwrap())
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file(out);
    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=bindings/cbindgen.toml");
}

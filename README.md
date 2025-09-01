# AI Video Editor

This project demonstrates a simple integration between Swift and Rust. The Swift app provides a user interface that calls Rust functions for basic operations.

## Project Structure

-   **Swift App**: Contains the iOS/macOS application with UI
-   **rust-core**: Contains the Rust library with core functionality

## Setup Instructions

### Prerequisites

-   Xcode (latest version recommended)
-   Rust toolchain (install with [rustup](https://rustup.rs/))
-   cbindgen (`cargo install cbindgen`)

### Building the Project

1. Clone the repository
2. Run the build script to compile the Rust library:
    ```bash
    cd "Swift App"
    ./build-rust.sh
    ```
3. Open the Xcode project `Swift App/AI Video Editor.xcodeproj`
4. Configure the Xcode project to link with the Rust library:
    - Set "Swift Compiler - General" > "Objective-C Bridging Header" to:
        ```
        $(PROJECT_DIR)/AI Video Editor/AI-Video-Editor-Bridging-Header.h
        ```
    - Add to "Search Paths" > "Header Search Paths":
        ```
        $(PROJECT_DIR)/AI Video Editor/Libs
        ```
    - Add to "Linking" > "Other Linker Flags":
        ```
        -lrust_core
        ```
    - Add to "Search Paths" > "Library Search Paths":
        ```
        $(PROJECT_DIR)/AI Video Editor/Libs
        ```
5. Add a Run Script build phase (before "Compile Sources") with:
    ```bash
    "${PROJECT_DIR}/build-rust.sh"
    ```
6. Build and run the project in Xcode

## How It Works

The Swift app communicates with Rust through a C-compatible Foreign Function Interface (FFI). The process is:

1. Rust functions are marked with `#[no_mangle]` and `extern "C"` to make them callable from C
2. The C header file (`rust_core.h`) defines the interface for these functions
3. Swift uses a bridging header to import the C functions
4. The `RustCore.swift` file wraps these C functions in a more Swift-friendly API

## Current Features

-   Adding two numbers using Rust
-   Greeting a user with a message from Rust
-   Dividing two numbers with error handling

## Extending the Project

To add more functionality:

1. Add new functions to the Rust library in `rust-core/src/lib.rs`
2. Update the C header file in `rust-core/include/rust_core.h`
3. Add Swift wrapper methods in `Swift App/AI Video Editor/RustCore.swift`
4. Update the UI in `Swift App/AI Video Editor/ContentView.swift`

## Troubleshooting

-   If you encounter "Library not found" errors, make sure the Rust library has been built and copied to the correct location
-   If Swift can't find the Rust functions, check that the bridging header is correctly configured
-   For linking errors, verify that the library search paths and linker flags are set correctly

#[no_mangle]
pub extern "C" fn add_one(x: i32) -> i32 {
    x + 5
}

#[no_mangle]
pub extern "C" fn multiply_by_two(x: i32) -> i32 {
    x * 3
}

#[no_mangle]
pub extern "C" fn divide_by_two(x: i32) -> i32 {
    x / 3
}
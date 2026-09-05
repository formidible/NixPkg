pub const RESET: &str = "\x1b[0m";
pub const CYAN: &str = "\x1b[36m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const RED: &str = "\x1b[31m";
pub const DIM: &str = "\x1b[2m";
pub const BOLD: &str = "\x1b[1m";

pub fn header() {
    println!();
    println!("{CYAN}╭──────────────────────────────────────────╮{RESET}");
    println!("{CYAN}│  ❄ nixadd                                │{RESET}");
    println!("{CYAN}╰──────────────────────────────────────────╯{RESET}");
    println!();
}

pub fn success(message: &str) {
    println!("  {GREEN}✓{RESET} {message}");
}

pub fn warning(message: &str) {
    println!("  {YELLOW}!{RESET} {message}");
}

pub fn error(message: &str) {
    eprintln!("  {RED}✗{RESET} {message}");
}

pub fn info(message: &str) {
    println!("  {CYAN}•{RESET} {message}");
}

pub fn package(message: &str) {
    println!("  {CYAN}Package:{RESET} {message}");
}

pub fn config(message: &str) {
    println!("  {CYAN}Configuration:{RESET} {message}");
}

pub fn section(title: &str) {
    println!();
    println!("  {BOLD}{title}{RESET}");
    println!("  {DIM}────────────────────────────────────────{RESET}");
    println!();
}

pub fn diff_add(message: &str) {
    println!("    {GREEN}+ {message}{RESET}");
}

pub fn diff_remove(message: &str) {
    println!("    {RED}- {message}{RESET}");
}

pub fn package_item(message: &str) {
    println!("    {CYAN}•{RESET} {message}");
}

pub fn tip(message: &str) {
    println!();
    println!("  {DIM}Tip: {message}{RESET}");
}

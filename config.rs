use std::fs;
use std::path::PathBuf;

pub fn find_config() -> Result<PathBuf, String> {
    let path = PathBuf::from("/etc/nixos/configuration.nix");

    if path.exists() {
        Ok(path)
    } else {
        Err("Could not find /etc/nixos/configuration.nix".to_string())
    }
}

pub fn read_config(path: &PathBuf) -> Result<String, String> {
    fs::read_to_string(path)
        .map_err(|error| format!("Failed to read configuration: {error}"))
}

pub fn write_config(path: &PathBuf, contents: &str) -> Result<(), String> {
    fs::write(path, contents)
        .map_err(|error| format!("Failed to write configuration: {error}"))
}

pub fn backup_config(path: &PathBuf) -> Result<PathBuf, String> {
    let backup_path =
        PathBuf::from(format!("{}.nixadd-backup", path.display()));

    fs::copy(path, &backup_path)
        .map_err(|error| format!("Failed to create backup: {error}"))?;

    Ok(backup_path)
}

pub fn find_system_packages(contents: &str) -> Result<(usize, usize), String> {
    let property = "environment.systemPackages";

    let mut line_start = 0;

    for line in contents.lines() {
        let trimmed = line.trim();

        if !trimmed.starts_with('#') {
            if let Some(relative_pos) = line.find(property) {
                let property_pos = line_start + relative_pos;

                let after_property =
                    &contents[property_pos + property.len()..];

                let start_offset = after_property
                    .find('[')
                    .ok_or_else(|| {
                        "Could not find package list '['".to_string()
                    })?;

                let start =
                    property_pos + property.len() + start_offset;

                let after_start = &contents[start + 1..];

                let end_offset = after_start
                    .find(']')
                    .ok_or_else(|| {
                        "Could not find package list ']'".to_string()
                    })?;

                let end = start + 1 + end_offset;

                return Ok((start, end));
            }
        }

        line_start += line.len() + 1;
    }

    Err("Could not find environment.systemPackages".to_string())
}

pub fn package_exists(contents: &str, package: &str) -> bool {
    let (start, end) = match find_system_packages(contents) {
        Ok(positions) => positions,
        Err(_) => return false,
    };

    let package_list = &contents[start + 1..end];

    package_list
        .split_whitespace()
        .any(|item| item == package)
}

pub fn add_package(
    contents: &str,
    package: &str,
) -> Result<String, String> {
    let (start, end) = find_system_packages(contents)?;

    let package_list = &contents[start + 1..end];

    let indentation = package_list
        .lines()
        .rev()
        .find(|line| !line.trim().is_empty())
        .map(|line| {
            line.chars()
                .take_while(|c| c.is_whitespace())
                .collect::<String>()
        })
        .unwrap_or_else(|| "  ".to_string());

    let mut result =
        String::with_capacity(contents.len() + package.len() + 8);

    result.push_str(&contents[..end]);

    if !package_list.ends_with('\n') {
        result.push('\n');
    }

    result.push_str(&indentation);
    result.push_str(package);

    result.push_str(&contents[end..]);

    Ok(result)
}

pub fn remove_package(
    contents: &str,
    package: &str,
) -> Result<String, String> {
    let (start, end) = find_system_packages(contents)?;

    let package_list = &contents[start + 1..end];

    let mut found = false;
    let mut new_package_list = String::new();

    for line in package_list.lines() {
        let trimmed = line.trim();

        if trimmed == package {
            found = true;
            continue;
        }

        new_package_list.push_str(line);
        new_package_list.push('\n');
    }

    if !found {
        return Err(format!(
            "Package '{package}' is not configured."
        ));
    }

    while new_package_list.ends_with("\n\n") {
        new_package_list.pop();
    }

    let mut result = String::with_capacity(contents.len());

    result.push_str(&contents[..start + 1]);
    result.push_str(&new_package_list);

    if !new_package_list.is_empty()
        && !new_package_list.ends_with('\n')
    {
        result.push('\n');
    }

    result.push_str(&contents[end..]);

    Ok(result)
}

pub fn create_system_packages(
    contents: &str,
    package: &str,
) -> String {
    let insert_position = contents.rfind('}').unwrap_or(contents.len());

    let mut result =
        String::with_capacity(contents.len() + package.len() + 70);

    result.push_str(&contents[..insert_position]);

    result.push_str(
        "\n  environment.systemPackages = with pkgs; [\n    ",
    );

    result.push_str(package);

    result.push_str("\n  ];\n");

    result.push_str(&contents[insert_position..]);

    result
}

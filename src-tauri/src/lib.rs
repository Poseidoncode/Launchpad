use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use icns::IconFamily;
use image::codecs::png::PngEncoder;
use image::ExtendedColorType;
use image::ImageEncoder;
use plist::Value;
use serde::Serialize;
use std::collections::HashSet;
use std::fs::File;
use std::io::BufReader;
use std::path::{Path, PathBuf};
use std::process::Command;
use tauri::async_runtime::spawn_blocking;
use walkdir::WalkDir;
use dirs;

#[derive(Serialize, serde::Deserialize, Clone)]
struct AppInfo {
    name: String,
    path: String,
    icon: String,
}

#[tauri::command]
async fn get_installed_apps() -> Result<Vec<AppInfo>, String> {
    spawn_blocking(|| {
        let cache_path = get_cache_path();
        if let Some(cached) = load_cache(&cache_path) {
            Ok(cached)
        } else {
            let apps = scan_apps()?;
            save_cache(&cache_path, &apps);
            Ok(apps)
        }
    })
    .await
    .map_err(|_| String::from("failed to collect applications"))?
}

#[tauri::command]
async fn launch_app(path: String) -> Result<(), String> {
    spawn_blocking(move || start_app(&path))
        .await
        .map_err(|_| String::from("failed to start application"))??;
    Ok(())
}

fn scan_apps() -> Result<Vec<AppInfo>, String> {
    let mut seen = HashSet::new();
    let mut apps = Vec::new();
    for root in app_directories() {
        if !root.exists() {
            continue;
        }
        let mut walker = WalkDir::new(&root)
            .max_depth(4)
            .follow_links(false)
            .into_iter();
        while let Some(entry) = walker.next() {
            let entry = match entry {
                Ok(item) => item,
                Err(_) => continue,
            };
            if !entry.file_type().is_dir() {
                continue;
            }
            if !is_app_bundle(entry.path()) {
                continue;
            }
            let canonical = match entry.path().canonicalize() {
                Ok(path) => path,
                Err(_) => {
                    walker.skip_current_dir();
                    continue;
                }
            };
            if !seen.insert(canonical.clone()) {
                walker.skip_current_dir();
                continue;
            }
            if let Some(info) = build_app_info(&canonical) {
                apps.push(info);
            }
            walker.skip_current_dir();
        }
    }
    apps.sort_by_key(|app| app.name.to_lowercase());
    Ok(apps)
}

fn app_directories() -> Vec<PathBuf> {
    let mut dirs = vec![
        PathBuf::from("/Applications"),
        PathBuf::from("/System/Applications"),
    ];
    if let Ok(home) = std::env::var("HOME") {
        dirs.push(Path::new(&home).join("Applications"));
    }
    dirs
}

fn is_app_bundle(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| ext.eq_ignore_ascii_case("app"))
        .unwrap_or(false)
}

fn build_app_info(path: &Path) -> Option<AppInfo> {
    let info = load_plist(path)?;
    let name = info
        .get("CFBundleDisplayName")
        .and_then(Value::as_string)
        .or_else(|| info.get("CFBundleName").and_then(Value::as_string))
        .or_else(|| info.get("CFBundleExecutable").and_then(Value::as_string))
        .map(str::to_owned)
        .unwrap_or_else(|| {
            path.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or_default()
                .to_owned()
        });
    let icon_path = resolve_icon_path(path, &info);
    let icon = icon_path
        .as_ref()
        .and_then(|path| read_icon_png(path.as_path()))
        .unwrap_or_else(placeholder_icon);
    Some(AppInfo {
        name,
        path: path.to_string_lossy().into_owned(),
        icon,
    })
}

fn load_plist(path: &Path) -> Option<plist::Dictionary> {
    let plist_path = path.join("Contents").join("Info.plist");
    let file = File::open(plist_path).ok()?;
    let reader = BufReader::new(file);
    match Value::from_reader(reader).ok()? {
        Value::Dictionary(dict) => Some(dict),
        _ => None,
    }
}

fn resolve_icon_path(path: &Path, info: &plist::Dictionary) -> Option<PathBuf> {
    let resources = path.join("Contents").join("Resources");
    if let Some(Value::Dictionary(icons)) = info.get("CFBundleIcons") {
        if let Some(found) = extract_icon_from_dictionary(&resources, icons) {
            return Some(found);
        }
    }
    icon_candidates(info)
        .into_iter()
        .filter_map(|name| locate_icon(&resources, &name))
        .next()
}

fn extract_icon_from_dictionary(resources: &Path, dict: &plist::Dictionary) -> Option<PathBuf> {
    if let Some(primary) = dict.get("CFBundlePrimaryIcon") {
        if let Value::Dictionary(primary_dict) = primary {
            let options = icon_name_array(primary_dict.get("CFBundleIconFiles"));
            for name in options {
                if let Some(found) = locate_icon(resources, &name) {
                    return Some(found);
                }
            }
        }
    }
    None
}

fn icon_candidates(info: &plist::Dictionary) -> Vec<String> {
    let mut names = Vec::new();
    if let Some(Value::String(name)) = info.get("CFBundleIconFile") {
        names.push(name.to_owned());
    }
    names.extend(icon_name_array(info.get("CFBundleIconFiles")));
    names
}

fn icon_name_array(value: Option<&Value>) -> Vec<String> {
    match value {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(Value::as_string)
            .map(str::to_owned)
            .collect(),
        _ => Vec::new(),
    }
}

fn locate_icon(resources: &Path, name: &str) -> Option<PathBuf> {
    let mut candidates = Vec::new();
    if name.ends_with(".icns") {
        candidates.push(resources.join(name));
    } else {
        candidates.push(resources.join(format!("{}.icns", name)));
        candidates.push(resources.join(name));
    }
    for candidate in candidates {
        if candidate.exists() {
            return Some(candidate);
        }
    }
    None
}

fn read_icon_png(path: &Path) -> Option<String> {
    let file = File::open(path).ok()?;
    let reader = BufReader::new(file);
    let family = IconFamily::read(reader).ok()?;
    let icon_type = family
        .available_icons()
        .into_iter()
        .filter(|ty| {
            let size = ty.pixel_width();
            size >= 64 && size <= 256 // Prefer medium sizes
        })
        .max_by_key(|ty| ty.pixel_width() * ty.pixel_height())
        .or_else(|| {
            // Fallback to largest if no medium size
            family
                .available_icons()
                .into_iter()
                .max_by_key(|ty| ty.pixel_width() * ty.pixel_height())
        })?;
    let image = family.get_icon_with_type(icon_type).ok()?;
    let mut data = Vec::new();
    image.write_png(&mut data).ok()?;
    Some(format!("data:image/png;base64,{}", BASE64.encode(data)))
}

fn placeholder_icon() -> String {
    use image::{ImageBuffer, Rgba};
    let buffer = ImageBuffer::<Rgba<u8>, Vec<u8>>::from_pixel(1, 1, Rgba([0, 0, 0, 0]));
    let mut data = Vec::new();
    if PngEncoder::new(&mut data)
        .write_image(buffer.as_raw(), 1, 1, ExtendedColorType::Rgba8)
        .is_ok()
    {
        return format!("data:image/png;base64,{}", BASE64.encode(data));
    }
    String::new()
}

fn start_app(path: &str) -> Result<(), String> {
    let bundle = Path::new(path);
    if !is_app_bundle(bundle) {
        return Err(String::from("invalid application bundle"));
    }
    let resolved = bundle
        .canonicalize()
        .map_err(|_| String::from("failed to resolve application path"))?;
    if !resolved.exists() {
        return Err(String::from("application not found"));
    }
    let status = Command::new("open")
        .arg(&resolved)
        .status()
        .map_err(|_| String::from("failed to execute open command"))?;
    if status.success() {
        Ok(())
    } else {
        Err(String::from("open command returned error"))
    }
}

fn get_cache_path() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("tauri-app-cache.json")
}

fn load_cache(path: &Path) -> Option<Vec<AppInfo>> {
    let file = File::open(path).ok()?;
    let reader = BufReader::new(file);
    serde_json::from_reader(reader).ok()
}

fn save_cache(path: &Path, apps: &[AppInfo]) {
    if let Ok(json) = serde_json::to_string_pretty(apps) {
        let _ = std::fs::write(path, json);
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![get_installed_apps, launch_app])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

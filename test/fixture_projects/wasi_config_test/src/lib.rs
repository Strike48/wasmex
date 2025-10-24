#[allow(warnings)]
mod bindings;

use bindings::{config_get, config_get_all, Guest};

struct Component;

impl Guest for Component {
    fn test_get_config(key: String) -> Result<String, String> {
        match config_get(&key) {
            Some(value) => Ok(value),
            None => Err(format!("Config key '{}' not found", key)),
        }
    }

    fn test_get_all_config() -> Result<String, String> {
        let pairs = config_get_all();
        let formatted: Vec<String> = pairs
            .iter()
            .map(|(k, v)| format!("{}={}", k, v))
            .collect();
        Ok(formatted.join(","))
    }
}

bindings::export!(Component with_types_in bindings);

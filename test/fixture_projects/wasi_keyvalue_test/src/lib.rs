#[allow(warnings)]
mod bindings;

use bindings::{kv_delete, kv_exists, kv_get, kv_set, Guest};

struct Component;

impl Guest for Component {
    fn test_set_get(key: String, value: String) -> Result<String, String> {
        // Convert string to bytes
        let bytes = value.as_bytes().to_vec();

        // Set the value
        kv_set(&key, &bytes);

        // Get it back
        match kv_get(&key) {
            Some(retrieved_bytes) => {
                // Convert bytes back to string
                match String::from_utf8(retrieved_bytes) {
                    Ok(retrieved_value) => Ok(retrieved_value),
                    Err(e) => Err(format!("Failed to convert bytes to string: {}", e)),
                }
            }
            None => Err(format!("Key '{}' not found after setting", key)),
        }
    }

    fn test_delete(key: String) -> Result<String, String> {
        // First check if key exists
        let existed_before = kv_exists(&key);

        // Delete the key
        kv_delete(&key);

        // Check if it still exists
        let exists_after = kv_exists(&key);

        if existed_before && !exists_after {
            Ok("Successfully deleted".to_string())
        } else if !existed_before {
            Ok("Key did not exist".to_string())
        } else {
            Err("Failed to delete key".to_string())
        }
    }

    fn test_exists(key: String) -> Result<bool, String> {
        Ok(kv_exists(&key))
    }
}

bindings::export!(Component with_types_in bindings);

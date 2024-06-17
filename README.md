# lnd-cache
script on "cache" uses a database script needs further work but is ready for expansion


### Setting Cache Information

**1. Command: /setcache**
- **Description:**
  - Sets a value in the cache with an optional Time-To-Live (TTL) and a global flag.
- **Syntax:**
  - `/setcache [key] [value] [ttl] [global]`
- **Parameters:**
  - **key:** The name of the key to be set.
  - **value:** The value to be assigned to the key.
  - **ttl:** (Optional) Time-To-Live in seconds. If 0, the key will be persistent.
  - **global:** (Optional) 0 or 1, whether the cache should be global (stored in the database).
- **Example:**
  - `/setcache exampleKey exampleValue 60 1`
    - Sets cache for `exampleKey` with `exampleValue`, TTL of 60 seconds, marked as global.
- **Global usage:**
  - `/setcache globalKey globalValue 60 1`
    - Sets cache for `globalKey` with `globalValue`, TTL of 60 seconds, marked as global.
- **Local usage:**
  - `/setcache localKey localValue 120 0`
    - Sets a local cache for `localKey` with `localValue`, TTL of 120 seconds, marked as local.

### Getting Cache Information

**2. Command: /getcache**
- **Description:**
  - Retrieves the value from the cache for a given key and displays information about it.
- **Syntax:**
  - `/getcache [key]`
- **Parameters:**
  - **key:** The cache key to be retrieved.
- **Example:**
  - `/getcache exampleKey`
    - Retrieves and displays the value and information for `exampleKey`.

### Removing Cache Information

**3. Command: /removecache**
- **Description:**
  - Removes a key from the cache.
- **Syntax:**
  - `/removecache [key]`
- **Parameters:**
  - **key:** The key to be removed.
- **Example:**
  - `/removecache exampleKey`
    - Removes the key `exampleKey` from the cache.

### Wiping Cache Information

**4. Command: /wipecache**
- **Description:**
  - Clears the entire cache.
- **Syntax:**
  - `/wipecache`
- **Example:**
  - `/wipecache`
    - Clears the entire cache.

### Updating Cache Information

**5. Command: /updatecache**
- **Description:**
  - Updates the key name and/or its value in the cache.
- **Syntax:**
  - `/updatecache [old_key] [new_key] [new_value] [global (0 or 1)]`
- **Parameters:**
  - **old_key:** The current name of the key in the cache.
  - **new_key:** The new name of the key in the cache.
  - **new_value:** (Optional) The new value for the key. If "none", the value remains unchanged.
  - **global:** (Optional) 0 or 1, whether the cache should be global.
- **Examples:**
  - `/updatecache oldKey newKey newValue 0/1`
    - Updates `oldKey` to `newKey` and sets the new value `newValue` as global.
  - `/updatecache oldKey newKey none 0/1`
    - Updates only the key name without changing the value.
  - `/updatecache oldKey none newValue 0/1`
    - Updates the value of the given key without changing its name.

### Showing Cache Keys Information

**6. Command: /showkeys**
- **Description:**
  - Displays all keys in the cache.
- **Syntax:**
  - `/showkeys`
- **Example:**
  - `/showkeys`
    - Displays all keys in the cache.

### Manual Update Information

**7. Command: /manualrefresh**
- **Description:**
  - Refreshes the entire database.
- **Syntax:**
  - `/manualrefresh`
- **Example:**
  - `/manualrefresh`

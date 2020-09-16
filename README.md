Generic Genesis Kit
==============================

The main manifest file is `ops/base.yml`. This file is shared across the deployments. Edits to this file will apply to all deployments. Use overrides in deployment env files for deployment specific changes (ex. `env.yml`).

The top section of the `ops/base.yml` file, `meta`, hold the parameters that are loaded into properties in the `instance_groups` section below using spruce `(( grab ... ))` functions. Entries labelled with `(( param ... ))` are expected as parameters within the env files.
